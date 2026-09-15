import 'package:get/get.dart';

/// 附件类型
enum QuickAttachmentType { image, audio, document, other }

/// 附件提示短句（缩略图下方）
extension QuickAttachmentTypeHint on QuickAttachmentType {
  String get hint {
    switch (this) {
      case QuickAttachmentType.image:
        return '解读图片';
      case QuickAttachmentType.audio:
        return '转录音频';
      case QuickAttachmentType.document:
        return '提取文字';
      case QuickAttachmentType.other:
        return '解析文档';
    }
  }
}

/// 快速收集面板的附件条目
class QuickAttachment {
  /// 源文件路径
  final String path;

  /// 附件类型
  final QuickAttachmentType type;

  /// 展示文件名
  final String name;

  const QuickAttachment({
    required this.path,
    required this.type,
    required this.name,
  });

  bool get isImage => type == QuickAttachmentType.image;
}

/// 功能模板（保存后按模板执行 AI 处理，占位）
const List<String> quickCaptureTemplates = [
  '待办',
  '打卡',
  '扩写',
  '润色',
  '会议记录',
  '翻译',
];

/// 快速收集面板状态（GetX）
class QuickCaptureState extends GetxController {
  /// 速记文本
  final RxString text = ''.obs;

  /// 附件列表
  final RxList<QuickAttachment> attachments = <QuickAttachment>[].obs;

  /// 保存中
  final RxBool saving = false.obs;

  /// 语音输入模式（占位）
  final RxBool voiceMode = false.obs;

  /// 正在录音（占位视觉）
  final RxBool recording = false.obs;

  /// 已选功能模板
  final RxString selectedTemplate = ''.obs;

  void addAttachment(QuickAttachment attachment) {
    attachments.add(attachment);
  }

  void removeAttachment(int index) {
    attachments.removeAt(index);
  }
}
