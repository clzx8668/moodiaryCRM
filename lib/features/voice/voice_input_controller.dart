import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/features/ai/voice/audio_transcribe_service.dart';
import 'package:moodiary/features/ai/voice/long_audio_transcribe_service.dart';
import 'package:moodiary/features/voice/speech_service.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// 长按说话的走向（纯函数，便于单测）。
enum VoiceInputRoute {
  /// 录音落盘 + 云端转写（配置了语音识别模型时首选）
  cloud,

  /// 设备本机实时听写（系统语音服务）
  system,

  /// 两者都不可用
  none,

  ;

  static VoiceInputRoute decide({
    required bool cloudReady,
    required bool systemReady,
  }) {
    if (cloudReady) return cloud;
    if (systemReady) return system;
    return none;
  }
}

/// 长按说话控制器（快捷收集面板 / 详情页输入条共用）。
///
/// 走向规则见 [VoiceInputRoute.decide]：配了语音识别模型就**录音落盘 + 云端转写**
/// （音频同时通过 [onAudioSaved] 回调保留，便于作为附件入库）；否则退回系统实时听写；
/// 都没有则给出可执行提示，不再静默失效。
class VoiceInputController {
  VoiceInputController({required this.onText, this.onAudioSaved});

  /// 识别/转写结果回填
  final void Function(String text) onText;

  /// 录音文件落盘回调（可选；用于把音频保留为附件）
  final void Function(String fileName)? onAudioSaved;

  /// 录音或转写中（UI 显示「正在聆听…」）
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  final AudioRecorder _recorder = AudioRecorder();
  String? _voiceFileName;
  bool _disposed = false;

  Future<void> start() async {
    if (busy.value) return;
    final route = VoiceInputRoute.decide(
      cloudReady: await _cloudReady(),
      systemReady: await _systemReady(),
    );
    switch (route) {
      case VoiceInputRoute.cloud:
        await _startFileRecording();
      case VoiceInputRoute.system:
        await _startSystemDictation();
      case VoiceInputRoute.none:
        toast.info(
          message: '暂不可用：可在「设置 → AI 设置 → 语音识别」配置模型，'
              '或开启系统语音服务',
        );
    }
  }

  Future<void> stop() async {
    if (!busy.value) return;
    busy.value = false;
    if (_voiceFileName != null) {
      await _stopAndTranscribe();
      return;
    }
    await SpeechService.instance.stopListening();
  }

  void dispose() {
    _disposed = true;
    _recorder.dispose();
    busy.dispose();
  }

  Future<bool> _cloudReady() async {
    try {
      return await AudioTranscribeService.isConfigured();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _systemReady() async {
    try {
      return await SpeechService.instance.ensureAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> _startSystemDictation() async {
    busy.value = true;
    final ok = await SpeechService.instance.startListening((text) {
      if (text.trim().isEmpty) return;
      onText(text.trim());
      busy.value = false;
    });
    if (!ok) {
      busy.value = false;
      toast.error(message: '当前设备不支持语音识别，请检查系统语音设置');
    }
  }

  Future<void> _startFileRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      toast.error(message: '未获得麦克风权限');
      return;
    }
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final name = 'voice-${const Uuid().v7()}${isDesktop ? '.wav' : '.m4a'}';
    try {
      await _recorder.start(
        RecordConfig(
          encoder: isDesktop ? AudioEncoder.wav : AudioEncoder.aacLc,
        ),
        path: FileUtil.getRealPath('audio', name),
      );
      _voiceFileName = name;
      busy.value = true;
    } catch (e) {
      _voiceFileName = null;
      busy.value = false;
      toast.error(message: '录音失败：$e');
    }
  }

  Future<void> _stopAndTranscribe() async {
    final name = _voiceFileName;
    _voiceFileName = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // 停止失败也继续（文件可能已落盘）
    }
    if (name == null) return;
    onAudioSaved?.call(name);

    busy.value = true;
    try {
      final result = await LongAudioTranscribeService.transcribe(
        FileUtil.getRealPath('audio', name),
      );
      if (_disposed) return;
      onText(result.text);
      toast.success(
        message: result.chunked
            ? '已转写（${result.chunkCount} 段合并）'
            : '已转写',
      );
    } on TranscribeException catch (e) {
      toast.error(message: '转写失败（录音已保留）：${e.message}');
    } catch (e) {
      toast.error(message: '转写失败（录音已保留）：$e');
    } finally {
      if (!_disposed) busy.value = false;
    }
  }
}

/// 供 UI 直接使用的便捷扩展：追加文本（与快捷收集保持同一行为）。
String appendVoiceText(String base, String addition) {
  final b = base.trim();
  final a = addition.trim();
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  return '$b\n$a';
}
