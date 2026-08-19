import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart' as p;

/// 快速收集面板逻辑
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
            isImage: true,
            name: p.basename(file.path),
          ),
        );
      }
    } catch (e) {
      toast.error(message: '选择图片失败：$e');
    }
  }

  /// 选择文档/PDF 附件
  Future<void> pickDocument() async {
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
            isImage: false,
            name: file.name,
          ),
        );
      }
    } catch (e) {
      toast.error(message: '选择文件失败：$e');
    }
  }

  void removeAttachment(int index) {
    state.removeAttachment(index);
  }

  /// 保存速记
  Future<bool> save() async {
    if (state.saving.value) return false;
    final text = state.text.value.trim();
    if (text.isEmpty && state.attachments.isEmpty) {
      toast.info(message: '内容为空，无法保存');
      return false;
    }
    state.saving.value = true;
    try {
      await QuickCaptureSaver.save(
        text: text,
        attachments: state.attachments.toList(),
      );
      toast.success(message: '已保存速记');
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
