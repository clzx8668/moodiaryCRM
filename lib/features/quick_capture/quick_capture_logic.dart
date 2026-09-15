import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/features/quick_capture/quick_capture_template_action.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/features/voice/voice_input_controller.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart' as p;

/// 长按说话走向（与详情页输入条共用同一实现）。
typedef QuickCaptureVoiceRoute = VoiceInputRoute;

/// 快速收集面板逻辑（ima 式输入框）
class QuickCaptureLogic extends GetxController {
  final state = QuickCaptureState();

  /// 长按说话控制器（录音落盘 + 云端转写 / 系统听写，与详情页同一套逻辑）
  late final VoiceInputController _voiceInput;

  /// 视图侧回填回调（把识别结果写进输入框）
  void Function(String text)? _voiceTextCallback;

  /// 重置输入面板状态（每次打开面板时调用，确保不残留上次内容）
  void reset() {
    state.text.value = '';
    state.attachments.clear();
    state.selectedTemplate.value = '';
    state.voiceMode.value = false;
    state.recording.value = false;
    state.saving.value = false;
  }

  @override
  void onInit() {
    super.onInit();
    _voiceInput = VoiceInputController(
      onText: (text) {
        state.text.value = appendTranscript(state.text.value, text);
        _voiceTextCallback?.call(text);
      },
      onAudioSaved: (name) {
        // 录音先作为附件保留：转写失败也不丢内容
        state.addAttachment(
          QuickAttachment(
            path: FileUtil.getRealPath('audio', name),
            type: QuickAttachmentType.audio,
            name: name,
          ),
        );
      },
    )..busy.addListener(_syncRecordingState);
    reset();
  }

  void _syncRecordingState() {
    state.recording.value = _voiceInput.busy.value;
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
    // 面板内的回填走 state.text（由 onText 写入），这里额外回调给视图刷新输入框
    _voiceTextCallback = onText;
    await _voiceInput.start();
  }

  /// 结束长按说话：停止录音并（云端路径）转写回填。
  Future<void> stopRecording() async {
    await _voiceInput.stop();
  }

  /// 追加文本（纯函数，供面板回填与单测）。
  static String appendTranscript(String base, String addition) {
    return appendVoiceText(base, addition);
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
    _voiceInput.busy.removeListener(_syncRecordingState);
    _voiceInput.dispose();
    state.dispose();
    super.onClose();
  }
}
