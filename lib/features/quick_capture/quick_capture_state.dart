import 'package:get/get.dart';

/// 附件类型
enum QuickAttachmentType { image, audio, document, other }

/// 附件提示短句（缩略图下方）
extension QuickAttachmentTypeHint on QuickAttachmentType {
  String get hint {
    switch (this) {
      case QuickAttachmentType.image:
        // 图片附件随速记原样保存；要 AI 整理请走「图片速记/拍照速记」
        return '图片附件';
      case QuickAttachmentType.audio:
        // 保存后会入队后台转写（结果落 AI 生成区）
        return '转录音频';
      case QuickAttachmentType.document:
        // 目前只归档保存，不解析内容（文案不再承诺"提取文字"）
        return '文档附件';
      case QuickAttachmentType.other:
        return '其他附件';
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

  /// 是否处于「语音输入页」（快速收集面板内的文字 ↔ 语音切换）
  final RxBool voiceMode = false.obs;

  /// 已选功能模板
  final RxString selectedTemplate = ''.obs;

  void addAttachment(QuickAttachment attachment) {
    attachments.add(attachment);
  }

  void removeAttachment(int index) {
    attachments.removeAt(index);
  }
}
