import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart' as p;

/// 快速收集面板逻辑（ima 式输入框）
class QuickCaptureLogic extends GetxController {
  final state = QuickCaptureState();

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

  /// 开始录音（占位）
  void startRecording() {
    if (state.text.value.trim().isNotEmpty) return; // 有内容时按住说话失效
    state.recording.value = true;
  }

  /// 结束录音（占位）
  Future<void> stopRecording() async {
    if (!state.recording.value) return;
    state.recording.value = false;
    toast.info(message: '语音识别接入中，已为你预留录音入口');
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
        await SyncLogService.instance.write(
          level: SyncLogLevel.info,
          operation: 'ai',
          target: 'template',
          detail:
              '模板【${state.selectedTemplate.value}】AI 处理占位（diary ${diary.id}）',
        );
        toast.success(message: '已按【${state.selectedTemplate.value}】模板保存，AI 处理接入中');
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
    state.dispose();
    super.onClose();
  }
}
