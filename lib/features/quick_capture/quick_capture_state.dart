import 'package:get/get.dart';

/// 快速收集面板的附件条目
class QuickAttachment {
  /// 源文件路径
  final String path;

  /// 是否为图片（决定缩略图渲染方式）
  final bool isImage;

  /// 展示文件名
  final String name;

  const QuickAttachment({
    required this.path,
    required this.isImage,
    required this.name,
  });
}

/// 快速收集面板状态（GetX）
class QuickCaptureState extends GetxController {
  /// 速记文本
  final RxString text = ''.obs;

  /// 附件列表
  final RxList<QuickAttachment> attachments = <QuickAttachment>[].obs;

  /// 保存中
  final RxBool saving = false.obs;

  void addAttachment(QuickAttachment attachment) {
    attachments.add(attachment);
  }

  void removeAttachment(int index) {
    attachments.removeAt(index);
  }
}
