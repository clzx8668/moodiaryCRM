import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary/features/asr/asr_model_store.dart';
import 'package:moodiary/features/asr/asr_types.dart';
import 'package:moodiary/features/asr/ffi_asr_engine.dart';
import 'package:moodiary/features/asr/method_channel_asr_engine.dart';
import 'package:moodiary/features/asr/pcm_gate.dart';
import 'package:moodiary/features/asr/wav_writer.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/features/voice/voice_level_envelope.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// 语音输入页的录音阶段。
enum VoiceCapturePhase {
  /// 未开始
  idle,

  /// 正在录音
  recording,

  /// 已暂停（录音文件保留，可继续）
  paused,

  /// 已停止（等待用户「保存」或「取消」）
  stopped,
}

/// 录音底层能力抽象：真实实现走 `record` 插件，单测注入 fake。
abstract class VoiceCaptureRecorder {
  Future<bool> hasPermission();

  /// 开始录音到 [path]；[wav] = true 用 wav（桌面），否则 aac/m4a（移动端）
  Future<void> start(String path, {required bool wav});

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  /// 音量（dB，通常 -60…0），用于电平动画
  Stream<double> amplitudeDb();

  /// 端侧实时转写：以 PCM 流方式录音（16k/mono/int16），边录边喂引擎。
  ///
  /// 流模式不落文件（由调用方用 [WavWriter] 自己写），因此两者互斥：
  /// 走流模式时不要再调 [start]。
  Future<Stream<Uint8List>> startPcmStream({int sampleRate = 16000});

  Future<void> dispose();
}

/// `record` 插件的正式实现。
class RecordVoiceCaptureRecorder implements VoiceCaptureRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  final StreamController<double> _amp = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path, {required bool wav}) {
    _ampSub?.cancel();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((a) => _amp.add(a.current), onError: (_) {});
    return _recorder.start(
      RecordConfig(encoder: wav ? AudioEncoder.wav : AudioEncoder.aacLc),
      path: path,
    );
  }

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<void> stop() => _recorder.stop();

  @override
  Future<Stream<Uint8List>> startPcmStream({int sampleRate = 16000}) {
    _ampSub?.cancel();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((a) => _amp.add(a.current), onError: (_) {});
    return _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
  }

  @override
  Stream<double> amplitudeDb() => _amp.stream;

  @override
  Future<void> dispose() async {
    await _ampSub?.cancel();
    _ampSub = null;
    await _amp.close();
    await _recorder.dispose();
  }
}

/// 语音输入页录音控制器（快速收集面板内的「语音输入」页）。
///
/// 与旧的「按住说话」不同，这里是**先录音、后决定**：
/// - 录音写本地文件（天然先落地，进程被杀也有音频）；
/// - 支持暂停 / 继续 / 停止；
/// - 停止后由用户选择「保存」（立刻入库 + 后台转写）或「取消」（删掉音频，
///   不产生任何记录，也不消耗转写资源）。
class VoiceCaptureController {
  VoiceCaptureController({
    VoiceCaptureRecorder? recorder,
    DateTime Function()? clock,
    bool? isDesktop,
    String Function()? idGenerator,
    String Function(String fileName)? audioPathResolver,
    OnDeviceAsrEngine Function()? asrEngineFactory,
  }) : _recorder = recorder ?? RecordVoiceCaptureRecorder(),
       _clock = clock ?? DateTime.now,
       _isDesktop = isDesktop ?? _defaultIsDesktop(),
       _idGenerator = idGenerator ?? (() => const Uuid().v7()),
       _audioPathResolver =
           audioPathResolver ??
           ((fileName) => FileUtil.getRealPath('audio', fileName)),
       _asrEngineFactory = asrEngineFactory;

  final VoiceCaptureRecorder _recorder;
  final DateTime Function() _clock;
  final bool _isDesktop;
  final String Function() _idGenerator;
  final String Function(String fileName) _audioPathResolver;

  /// 端侧转写引擎工厂（单测注入 fake；默认走 MethodChannel）。
  final OnDeviceAsrEngine Function()? _asrEngineFactory;

  /// 平台默认引擎：Android 走 Kotlin/JNI，Windows 走 Rust/FFI。
  static OnDeviceAsrEngine defaultAsrEngine() =>
      Platform.isWindows ? FfiAsrEngine() : MethodChannelAsrEngine();

  /// 当前阶段
  final ValueNotifier<VoiceCapturePhase> phase = ValueNotifier(
    VoiceCapturePhase.idle,
  );

  /// 已录时长（暂停期间不增长）
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  /// 电平 0…1（驱动电平条动画）
  final ValueNotifier<double> level = ValueNotifier(0);

  /// 整段录音的响度包络：保存后详情页播放时按**真实响度**显示波形
  final VoiceLevelEnvelope envelope = VoiceLevelEnvelope();

  /// 实时转写的当前文本（录音过程中逐句追加；停止后即为端侧草稿）
  final ValueNotifier<String> liveTranscript = ValueNotifier('');

  /// 当前是否「正在说话」（端侧 VAD 判定；驱动绿点/字幕态）
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  /// 本次录音是否走了端侧实时转写
  bool get onDeviceActive => _asrEngine != null;

  OnDeviceAsrEngine? _asrEngine;
  StreamSubscription<Uint8List>? _pcmSub;
  WavWriter? _wavWriter;
  PcmGate? _gate;

  Timer? _ticker;
  StreamSubscription<double>? _ampSub;
  DateTime? _startedAt;
  Duration _accumulated = Duration.zero;
  bool _disposed = false;

  /// 当前录音文件名（相对 audio 目录）；idle 时为 null
  String? audioFileName;

  bool get hasAudio => (audioFileName ?? '').isNotEmpty;

  /// 录音文件绝对路径（有音频时才有意义）
  String? get audioPath => hasAudio ? _audioPathResolver(audioFileName!) : null;

  /// 保存用的波形（降采样成 64 条；没录到数据时为空列表）
  List<double> get waveformForSave => envelope.downsample(64);

  static bool _defaultIsDesktop() =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// 文件名（纯函数，便于单测）：`voice-<id>.wav|.m4a`
  static String fileNameFor(String id, {required bool desktop}) =>
      'voice-$id${desktop ? '.wav' : '.m4a'}';

  /// 时长文案 `mm:ss`（纯函数）
  static String formatDuration(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// dB → 0…1 电平（纯函数）：-60dB 记 0，0dB 记 1
  static double normalizeDb(double db) {
    if (db.isNaN || db.isInfinite) return 0;
    return ((db + 60) / 60).clamp(0.0, 1.0);
  }

  /// 开始录音；返回 null 表示成功，否则返回给用户看的错误文案。
  Future<String?> start() async {
    if (phase.value == VoiceCapturePhase.recording) return null;
    await _disposeAudioFile(); // 重录场景：先清掉上一段

    final granted = await _recorder.hasPermission();
    if (!granted) return '未获得麦克风权限，请在系统设置里允许录音';

    final name = fileNameFor(_idGenerator(), desktop: _isDesktop);
    try {
      await _recorder.start(_audioPathResolver(name), wav: _isDesktop);
    } catch (e) {
      phase.value = VoiceCapturePhase.idle;
      return '录音失败：$e';
    }

    audioFileName = name;
    _accumulated = Duration.zero;
    envelope.clear();
    _startedAt = _clock();
    elapsed.value = Duration.zero;
    level.value = 0;
    phase.value = VoiceCapturePhase.recording;
    _listenAmplitude();
    _startTicker();
    return null;
  }

  /// 用**端侧实时转写**方式开始录音：PCM 流 → 门卫 → WAV 落盘 + 端侧识别。
  ///
  /// 与 [start] 的区别：
  /// - 音频以 16k/mono/int16 的 PCM 流进来，由本类用 [WavWriter] 边录边写
  ///   （照样先落地，网络/进程异常都不丢）；
  /// - 同时把 PCM 喂给端侧引擎，句子识别完立刻写进 [liveTranscript]。
  ///
  /// 返回 null = 端侧链路已启动；返回文案 = 端侧不可用/启动失败，
  /// 调用方应退回 [start]（云端兜底路径）。
  Future<String?> startStreaming() async {
    if (phase.value == VoiceCapturePhase.recording) return null;
    if (!AsrModelStore.isReady) return '端侧模型未就绪';
    await _disposeAudioFile();

    final granted = await _recorder.hasPermission();
    if (!granted) return '未获得麦克风权限，请在系统设置里允许录音';

    final engine = (_asrEngineFactory ?? defaultAsrEngine)();
    try {
      if (!await engine.isReady()) {
        await engine.dispose();
        return '端侧引擎不可用';
      }
      await engine.init();
      await engine.start();
    } catch (e) {
      try {
        await engine.dispose();
      } catch (_) {}
      return '端侧引擎启动失败：$e';
    }

    final name = 'voice-${_idGenerator()}.wav';
    final path = _audioPathResolver(name);
    final writer = WavWriter(path: path);
    try {
      await writer.open();
    } catch (e) {
      await engine.dispose();
      return '音频文件创建失败：$e';
    }

    Stream<Uint8List> pcm;
    try {
      pcm = await _recorder.startPcmStream();
    } catch (e) {
      await writer.close();
      await engine.dispose();
      return '录音失败：$e';
    }

    _asrEngine = engine;
    _wavWriter = writer;
    _gate = PcmGate();
    liveTranscript.value = '';
    speaking.value = false;
    audioFileName = name;
    _accumulated = Duration.zero;
    envelope.clear();
    _startedAt = _clock();
    elapsed.value = Duration.zero;
    level.value = 0;
    phase.value = VoiceCapturePhase.recording;
    _listenAmplitude();
    _startTicker();

    engine.results.listen(
      (r) {
        if (!onDeviceActive) return;
        liveTranscript.value = AsrPartialText.merge(
          liveTranscript.value,
          r.text,
        );
      },
      onError: (_) {},
    );

    _pcmSub = pcm.listen(_onPcm, onError: (_) {}, cancelOnError: false);
    return null;
  }

  void _onPcm(Uint8List chunk) {
    if (chunk.isEmpty || _disposed) return;
    final writer = _wavWriter;
    if (writer == null) return;
    // 暂停期间不写入（流一般也停了，这里兜一层防止把暂停段录进去）
    if (phase.value != VoiceCapturePhase.recording) return;
    unawaited(writer.add(chunk));

    // 用 PCM 真实响度驱动电平与包络（比插件的 amplitude 更贴端侧链路）
    final rms = PcmGate.rms(chunk);
    envelope.add(rms);
    level.value = rms.clamp(0.0, 1.0);

    final gate = _gate;
    final engine = _asrEngine;
    if (gate == null || engine == null) return;
    final pass = gate.accept(chunk);
    speaking.value = gate.isSpeaking;
    // 门卫不过（纯静音/底噪）时不喂模型：省电、也减少无效句
    if (pass) unawaited(engine.acceptPcm(chunk));
  }

  Future<void> pause() async {
    if (phase.value != VoiceCapturePhase.recording) return;
    _accumulated = _elapsedNow();
    _startedAt = null;
    _stopTicker();
    await _recorder.pause();
    level.value = 0;
    elapsed.value = _accumulated;
    phase.value = VoiceCapturePhase.paused;
  }

  Future<void> resume() async {
    if (phase.value != VoiceCapturePhase.paused) return;
    _startedAt = _clock();
    await _recorder.resume();
    phase.value = VoiceCapturePhase.recording;
    _startTicker();
  }

  /// 停止录音：**保留**音频文件，等用户决定保存或取消。
  Future<void> stop() async {
    if (phase.value != VoiceCapturePhase.recording &&
        phase.value != VoiceCapturePhase.paused) {
      return;
    }
    if (phase.value == VoiceCapturePhase.recording) {
      _accumulated = _elapsedNow();
    }
    _startedAt = null;
    _stopTicker();
    await _ampSub?.cancel();
    _ampSub = null;
    level.value = 0;
    try {
      if (onDeviceActive) {
        await _teardownStream();
      } else {
        await _recorder.stop();
      }
    } catch (_) {
      // 停止失败也继续（文件一般已落盘）
    }
    speaking.value = false;
    elapsed.value = _accumulated;
    phase.value = VoiceCapturePhase.stopped;
  }

  /// 丢弃当前录音（取消 / 重录前）：删除本地文件，回到 idle。
  Future<void> discard() async {
    _stopTicker();
    if (onDeviceActive) {
      try {
        await _teardownStream();
      } catch (_) {}
    } else if (phase.value == VoiceCapturePhase.recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    await _ampSub?.cancel();
    _ampSub = null;
    await _disposeAudioFile();
    _accumulated = Duration.zero;
    _startedAt = null;
    envelope.clear();
    liveTranscript.value = '';
    speaking.value = false;
    elapsed.value = Duration.zero;
    level.value = 0;
    phase.value = VoiceCapturePhase.idle;
  }

  /// 已入库：只清状态，**不删文件**（音频已作为附件归属于那条笔记）。
  void reset() {
    _stopTicker();
    _accumulated = Duration.zero;
    _startedAt = null;
    envelope.clear();
    liveTranscript.value = '';
    speaking.value = false;
    elapsed.value = Duration.zero;
    level.value = 0;
    audioFileName = null;
    phase.value = VoiceCapturePhase.idle;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopTicker();
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      if (onDeviceActive) {
        await _teardownStream();
      } else if (phase.value == VoiceCapturePhase.recording) {
        await _recorder.stop();
      }
    } catch (_) {}
    await _recorder.dispose();
    phase.dispose();
    elapsed.dispose();
    level.dispose();
    liveTranscript.dispose();
    speaking.dispose();
  }

  /// 面板被关掉等场景：停止录音并删掉未保存的音频。
  Future<void> discardAndDispose() async {
    await discard();
    await dispose();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      elapsed.value = _elapsedNow();
      // 每 200ms 记一条响度：整段录音的包络（保存后播放时按真实响度显示波形）
      // 端侧流模式下由 PCM 块直接喂包络（更准），这里不重复记
      if (phase.value == VoiceCapturePhase.recording && !onDeviceActive) {
        envelope.add(level.value);
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Duration _elapsedNow() {
    final started = _startedAt;
    if (started == null) return _accumulated;
    return _accumulated + _clock().difference(started);
  }

  void _listenAmplitude() {
    _ampSub?.cancel();
    _ampSub = _recorder.amplitudeDb().listen(
      (db) => level.value = normalizeDb(db),
      onError: (_) {},
    );
  }

  /// 收尾端侧流式链路：停流 → 引擎吐尾句 → 回填 WAV 头 → 释放引擎。
  Future<void> _teardownStream() async {
    final sub = _pcmSub;
    _pcmSub = null;
    await sub?.cancel();

    final engine = _asrEngine;
    _asrEngine = null;
    if (engine != null) {
      try {
        await engine.stop(); // VAD 未闭合的尾段也会被识别并推入 liveTranscript
      } catch (_) {}
      try {
        await engine.dispose();
      } catch (_) {}
    }

    final writer = _wavWriter;
    _wavWriter = null;
    if (writer != null) {
      try {
        await writer.close(); // 回填真实的 data 长度
      } catch (_) {}
    }

    _gate?.reset();
    _gate = null;
    try {
      await _recorder.stop(); // 兜底停流（部分平台上 startStream 需显式 stop）
    } catch (_) {}
  }

  Future<void> _disposeAudioFile() async {
    final name = audioFileName;
    audioFileName = null;
    if (name == null) return;
    try {
      final file = File(_audioPathResolver(name));
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // 删除失败不影响流程（孤立文件由数据健康度工具清理）
    }
  }
}
