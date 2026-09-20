import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary/features/asr/asr_model_store.dart';
import 'package:moodiary/features/asr/method_channel_asr_engine.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/src/rust/api/asr_bridge.dart' as rust_asr;

/// 端侧语音识别（本地实时转写）设置页。
///
/// 模型不进安装包（227MB），这里负责：状态展示 / 逐个导入 / 复制下载指引。
/// 下载命令由 `tool/fetch_asr_model.ps1` 提供，保持"应用侧对齐脚本"的单一来源。
class OnDeviceAsrSettingsPage extends StatefulWidget {
  const OnDeviceAsrSettingsPage({super.key});

  @override
  State<OnDeviceAsrSettingsPage> createState() =>
      _OnDeviceAsrSettingsPageState();
}

class _OnDeviceAsrSettingsPageState extends State<OnDeviceAsrSettingsPage> {
  static const String _downloadCmd =
      r'pwsh -ExecutionPolicy Bypass -File tool\fetch_asr_model.ps1 -PushToDevice';

  /// 自检状态：null = 未跑过；否则是给用户看的一行结论
  String? _selftestResult;
  bool _selftestRunning = false;

  /// 触发重建（导入后刷新状态）
  void _refresh() => setState(() {});

  /// 当前平台需要哪些文件（Windows 额外需要运行库）
  List<String> _modelFileNames() => [
    AsrModelFiles.vad,
    AsrModelFiles.asr,
    AsrModelFiles.tokens,
    if (Platform.isWindows) ...AsrModelFiles.windowsLibs,
  ];

  /// 端侧引擎自检：建引擎 → 喂一段 PCM → 看是否回吐文本。
  /// 用 220Hz 合成音能验证"链路通不通"，识别出空串也算通过（说明模型在算）。
  Future<void> _runSelftest() async {
    setState(() {
      _selftestRunning = true;
      _selftestResult = null;
    });
    final engine = MethodChannelAsrEngine();
    final sw = Stopwatch()..start();
    try {
      // Windows 走 Rust 引擎：直接读样例 wav 跑一遍完整链路（更贴近真实使用）
      if (Platform.isWindows) {
        final wav = await _loadSampleWav();
        if (wav == null) {
          _finishSelftest('未找到自检样例音频（assets/asr/asr_selftest.wav）');
          return;
        }
        final text = await rust_asr.asrTranscribePcm16Wav(
          modelDir: AsrModelStore.baseDir(),
          libDir: AsrModelStore.windowsLibDir(),
          wavBytes: wav,
          numThreads: 2,
        );
        final ms = sw.elapsedMilliseconds;
        _finishSelftest(
          text.trim().isEmpty
              ? '通过：引擎已加载并推理完成（${ms}ms，样例无可识别语音）'
              : '通过：识别到「$text」（${ms}ms）',
        );
        return;
      }
      final ready = await engine.isReady();
      if (!ready) {
        _finishSelftest('平台侧找不到模型（检查目录：${AsrModelStore.baseDir()}）');
        return;
      }
      await engine.init();
      await engine.start();
      final results = <String>[];
      final sub = engine.results.listen((r) => results.add(r.text));
      // 1.6 秒 220Hz 正弦 + 淡入淡出，避免爆音
      await engine.acceptPcm(_probePcm(seconds: 1.6));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await engine.stop();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await sub.cancel();
      final ms = sw.elapsedMilliseconds;
      _finishSelftest(
        results.isEmpty
            ? '通过：引擎已加载并推理完成（${ms}ms，测试音无可识别语音）'
            : '通过：识别到「${results.join('')}」（${ms}ms）',
      );
    } catch (e) {
      _finishSelftest('失败：$e');
    } finally {
      try {
        await engine.dispose();
      } catch (_) {}
    }
  }

  void _finishSelftest(String message) {
    if (!mounted) return;
    setState(() {
      _selftestRunning = false;
      _selftestResult = message;
    });
  }

  /// 自检样例音频（打包在 assets 里的 16k/mono/16bit 人声）
  Future<Uint8List?> _loadSampleWav() async {
    try {
      final data = await rootBundle.load('assets/asr/asr_selftest.wav');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 16k/mono/int16 小端的测试音（正弦扫频，能被 VAD 当作人声段触发一次推理）
  Uint8List _probePcm({double seconds = 1.6}) {
    const sampleRate = 16000;
    final total = (sampleRate * seconds).round();
    final bytes = Uint8List(total * 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < total; i++) {
      final t = i / sampleRate;
      final freq = 180 + 120 * (i / total); // 180→300Hz 扫频
      final fade = (i < total * 0.1)
          ? i / (total * 0.1)
          : (i > total * 0.9)
          ? (total - i) / (total * 0.1)
          : 1.0;
      final v = (0.35 * fade * 32767 * math.sin(2 * math.pi * freq * t));
      view.setInt16(i * 2, v.round(), Endian.little);
    }
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ready = AsrModelStore.isReady;
    return Scaffold(
      appBar: AppBar(title: const Text('端侧语音识别')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                ready
                    ? Icons.check_circle_rounded
                    : Icons.download_for_offline_outlined,
                color: ready ? colorScheme.primary : colorScheme.outline,
              ),
              title: Text(ready ? '本地实时转写已就绪' : '本地实时转写未启用'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  ready
                      ? AsrModelStore.statusLabel()
                      : '缺模型时语音笔记仍可用：录完自动走云端转写（需联网）。',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SectionTitle(
            title: '模型文件',
            subtitle: '目录：${AsrModelStore.baseDir()}',
          ),
          for (final name in _modelFileNames())
            _fileTile(context, name),
          const SizedBox(height: 8),
          const _SectionTitle(
            title: '自检',
            subtitle: '生成一段测试音，验证"引擎能否加载 + 是否回吐结果"。',
          ),
          Card(
            child: ListTile(
              leading: Icon(
                _selftestRunning
                    ? Icons.hourglass_top_rounded
                    : Icons.play_circle_outline_rounded,
              ),
              title: const Text('运行端侧引擎自检'),
              subtitle: Text(_selftestResult ?? '点一下即可（首次加载模型约 1–3 秒）'),
              trailing: _selftestRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: '开始自检',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: ready ? _runSelftest : null,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const _SectionTitle(
            title: '怎么装',
            subtitle: '推荐用开发脚本一键拉齐并推送到设备；也可在手机上手动选文件导入。',
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.terminal_rounded),
              title: const Text('从电脑推送（推荐）'),
              subtitle: const Text(_downloadCmd, maxLines: 2),
              trailing: IconButton(
                tooltip: '复制命令',
                icon: const Icon(Icons.copy_all_rounded),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _downloadCmd),
                  );
                  toast.success(message: '命令已复制');
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '三个文件都到位后，语音输入会自动切到「端侧实时转写」：'
                    '说话时本地出字、自动断句补标点，保存后不再上传云端转写'
                    '（省流量也没有失败记录）；需要更精细的措辞时，'
                    '可在笔记详情页手动点「云端精修」。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileTile(BuildContext context, String name) {
    final colorScheme = Theme.of(context).colorScheme;
    final exists = AsrModelStore.sizeMb(name) > 0;
    final mb = AsrModelStore.sizeMb(name);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          exists ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
          color: exists ? colorScheme.primary : colorScheme.outline,
          size: 20,
        ),
        title: Text(name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(exists ? '${mb.toStringAsFixed(1)} MB' : '未安装'),
        trailing: IconButton(
          tooltip: '选择文件导入',
          icon: const Icon(Icons.folder_open_rounded, size: 20),
          onPressed: () => _import(name),
        ),
      ),
    );
  }

  Future<void> _import(String fileName) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (!mounted) return;
      final path = result?.files.single.path;
      if (path == null || path.isEmpty) return;
      final base = path.split(RegExp(r'[\\/]')).last;
      if (base != fileName) {
        toast.error(message: '文件名需为 $fileName（当前：$base）');
        return;
      }
      final ok = await AsrModelStore.importFile(path);
      if (!mounted) return;
      if (ok) {
        toast.success(message: '已导入 $fileName');
        _refresh();
      } else {
        toast.error(message: '导入失败：文件名不被识别');
      }
    } catch (e) {
      toast.error(message: '导入失败：$e');
    }
  }
}

/// 小节标题（与 AI 设置页风格保持一致）
class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
