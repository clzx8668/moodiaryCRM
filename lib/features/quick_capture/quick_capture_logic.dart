import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/voice/audio_transcribe_service.dart';
import 'package:moodiary/features/ai/voice/long_audio_transcribe_service.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/features/quick_capture/quick_capture_template_action.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/features/voice/speech_service.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// 长按说话的走向（纯函数，便于单测）。
enum QuickCaptureVoiceRoute {
  /// 录音落盘 + 云端转写（配置了语音识别模型时首选）
  cloud,

  /// 设备本机实时听写（系统语音服务，原行为）
  system,

  /// 两者都不可用
  none,

  ;

  static QuickCaptureVoiceRoute decide({
    required bool cloudReady,
    required bool systemReady,
  }) {
    if (cloudReady) return cloud;
    if (systemReady) return system;
    return none;
  }
}

/// 快速收集面板逻辑（ima 式输入框）
class QuickCaptureLogic extends GetxController {
  final state = QuickCaptureState();

  /// 长按录音的文件名（audio 目录下）；系统听写路径下为 null。
  String? _voiceFileName;
  final AudioRecorder _recorder = AudioRecorder();
  void Function(String text)? _onVoiceText;

  /// 重置输入面板状态（每次打开面板时调用，确保不残留上次内容）
  void reset() {
    state.text.value = '';
    state.attachments.clear();
    state.selectedTemplate.value = '';
    state.voiceMode.value = false;
    state.recording.value = false;
    state.transcribing.value = false;
    state.saving.value = false;
  }

  @override
  void onInit() {
    super.onInit();
    reset();
  }

  /// 从相册选择多张图片
  Future<void> pickImages() async {
    try {
      final files = await MediaUtil.pickMultiPhoto(null);
      for (final file in files) {
        state.addAttachment(
          QuickAttachment(
            path: file.path,
            type: QuickAttachmentType.image,
            name: p.basename(file.path),
          ),
        );
      }
    } catch (e) {
      toast.error(message: '选择图片失败：$e');
    }
  }

  /// 选择文档
  Future<void> pickDocument({bool other = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null) return;
      for (final file in result.files) {
        state.addAttachment(
          QuickAttachment(
            path: file.path ?? '',
            type: other
                ? QuickAttachmentType.other
                : QuickAttachmentType.document,
            name: file.name,
          ),
        );
      }
    } catch (e) {
      toast.error(message: '选择文件失败：$e');
    }
  }

  /// 选择声音文件
  Future<void> pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result == null) return;
      for (final file in result.files) {
        state.addAttachment(
          QuickAttachment(
            path: file.path ?? '',
            type: QuickAttachmentType.audio,
            name: file.name,
          ),
        );
      }
    } catch (e) {
      toast.error(message: '选择音频失败：$e');
    }
  }

  void removeAttachment(int index) {
    state.removeAttachment(index);
  }

  /// 选择功能模板
  void selectTemplate(String? template) {
    state.selectedTemplate.value = template ?? '';
    if (template != null && template.isNotEmpty) {
      toast.info(message: '已选择模板：$template');
    }
  }

  /// 切换 语音/键盘 输入模式
  void toggleVoiceMode() {
    state.voiceMode.value = !state.voiceMode.value;
    state.recording.value = false;
  }

  /// 开始长按说话。
  ///
  /// 走向规则（[QuickCaptureVoiceRoute.decide]）：
  /// - 配置了语音识别模型 → **录音落盘**（音频保留为附件）+ 松手后云端转写；
  /// - 否则退回设备本机实时听写（原交互，Windows SAPI / 手机系统语音）；
  /// - 两者都没有 → 明确提示去哪里配置（不再静默失效）。
  ///
  /// 输入框已有内容时同样可用，识别结果**追加**到末尾。
  Future<void> startRecording({void Function(String text)? onText}) async {
    if (state.recording.value || state.transcribing.value) return;
    _onVoiceText = onText;

    final cloudReady = await _cloudTranscribeReady();
    final systemReady = await _systemSpeechReady();
    final route = QuickCaptureVoiceRoute.decide(
      cloudReady: cloudReady,
      systemReady: systemReady,
    );

    switch (route) {
      case QuickCaptureVoiceRoute.cloud:
        await _startFileRecording();
      case QuickCaptureVoiceRoute.system:
        await _startSystemDictation();
      case QuickCaptureVoiceRoute.none:
        toast.info(
          message: '暂不可用：可在「设置 → AI 设置 → 语音识别」配置模型，'
              '或开启系统语音服务',
        );
    }
  }

  /// 结束长按说话：停止录音并（云端路径）转写回填。
  Future<void> stopRecording() async {
    if (!state.recording.value) return;
    state.recording.value = false;

    if (_voiceFileName != null) {
      await _stopFileRecordingAndTranscribe();
      return;
    }
    await SpeechService.instance.stopListening();
  }

  Future<bool> _cloudTranscribeReady() async {
    try {
      return await AudioTranscribeService.isConfigured();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _systemSpeechReady() async {
    try {
      return await SpeechService.instance.ensureAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> _startSystemDictation() async {
    state.recording.value = true;
    final ok = await SpeechService.instance.startListening((text) {
      if (text.trim().isEmpty) return;
      _emitVoiceText(text);
      state.recording.value = false;
    });
    if (!ok) {
      state.recording.value = false;
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
      state.recording.value = true;
    } catch (e) {
      _voiceFileName = null;
      state.recording.value = false;
      toast.error(message: '录音失败：$e');
    }
  }

  Future<void> _stopFileRecordingAndTranscribe() async {
    final name = _voiceFileName;
    _voiceFileName = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // 停止失败也继续走后续处理（文件可能已落盘）
    }
    if (name == null) return;

    // 录音先作为附件保留：转写失败也不会丢内容
    state.addAttachment(
      QuickAttachment(
        path: FileUtil.getRealPath('audio', name),
        type: QuickAttachmentType.audio,
        name: name,
      ),
    );

    state.transcribing.value = true;
    try {
      final result = await LongAudioTranscribeService.transcribe(
        FileUtil.getRealPath('audio', name),
      );
      _emitVoiceText(result.text);
      toast.success(
        message: result.chunked
            ? '已转写并入输入框（${result.chunkCount} 段合并）'
            : '已转写并入输入框',
      );
    } on TranscribeException catch (e) {
      toast.error(message: '转写失败（录音已保留为附件）：${e.message}');
    } catch (e) {
      toast.error(message: '转写失败（录音已保留为附件）：$e');
    } finally {
      state.transcribing.value = false;
    }
  }

  void _emitVoiceText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _onVoiceText?.call(trimmed);
  }

  /// 追加文本（纯函数，供面板回填与单测）。
  static String appendTranscript(String base, String addition) {
    final b = base.trim();
    final a = addition.trim();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$b\n$a';
  }

  /// 保存速记（发送）
  Future<bool> save() async {
    if (state.saving.value) return false;
    final text = state.text.value.trim();
    if (text.isEmpty && state.attachments.isEmpty) {
      toast.info(message: '内容为空，无法保存');
      return false;
    }
    state.saving.value = true;
    try {
      final diary = await QuickCaptureSaver.save(
        text: text,
        attachments: state.attachments.toList(),
        template: state.selectedTemplate.value,
      );
      if (state.selectedTemplate.value.isNotEmpty) {
        final template = state.selectedTemplate.value;
        final action = quickCaptureActionFor(template);
        await SyncLogService.instance.write(
          level: SyncLogLevel.info,
          operation: 'ai',
          target: 'template',
          detail: action == null
              ? '模板【$template】已保存（无后台处理）'
              : '模板【$template】已提交 AI 处理（diary ${diary.id}）',
        );
        if (action != null) {
          unawaited(
            AiTaskQueueWorker.instance.submitTask(
              type: action.type,
              refId: diary.id,
              payload: action.payload,
            ),
          );
          toast.success(message: '已按【$template】保存，AI 正在处理…');
        } else {
          toast.success(message: '已按【$template】模板保存');
        }
      } else {
        toast.success(message: '已保存速记');
      }
      return true;
    } catch (e) {
      toast.error(message: '保存失败：$e');
      return false;
    } finally {
      state.saving.value = false;
    }
  }

  @override
  void onClose() {
    _recorder.dispose();
    state.dispose();
    super.onClose();
  }
}
