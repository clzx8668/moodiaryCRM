import 'package:image_picker/image_picker.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/tasks/pending_content_service.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/utils/media_util.dart';

/// 图片速记的公共入口（快速收集面板、系统分享、桌面快捷方式共用）。
///
/// 统一策略：优先走视觉模型整理成笔记；**未配置视觉模型时不丢内容**——
/// 退化为「图片附件速记」（图片照样入库，正文留一句说明）。
class QuickVisionActions {
  QuickVisionActions._();

  /// 未配置视觉模型时的退化正文。
  static const String fallbackText = '（分享的图片，未配置视觉模型，已保存原图）';

  /// 相机直拍 → 视觉整理。
  static Future<Diary?> captureFromCamera() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera);
    if (shot == null) return null;
    return saveFromImagePath(shot.path);
  }

  /// 相册选图（单张）→ 视觉整理。
  static Future<Diary?> captureFromGallery() async {
    final files = await MediaUtil.pickMultiPhoto(null);
    if (files.isEmpty) return null;
    return saveFromImagePath(files.first.path);
  }

  /// 指定图片路径 → 笔记（视觉整理优先，失败退化为附件速记）。
  ///
  /// 「先落地」原则：**立即**保存一条图片笔记（原图 + 处理中占位卡），
  /// 视觉整理交给后台队列，用户不用等模型返回。
  static Future<Diary?> saveFromImagePath(String path) async {
    // 原图先落本地媒体目录
    final nameMap = await MediaUtil.saveImages(imageFileList: [XFile(path)]);
    final name = nameMap[path];
    if (name == null || name.isEmpty) {
      // 媒体管线失败：退化为附件速记，保证不丢
      return QuickCaptureSaver.save(
        text: fallbackText,
        attachments: [
          QuickAttachment(
            path: path,
            type: QuickAttachmentType.image,
            name: path.split(RegExp(r'[/\\]')).last,
          ),
        ],
      );
    }
    return PendingContentService.savePhotoFast(imageName: name);
  }
}
