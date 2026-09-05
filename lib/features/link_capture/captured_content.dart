import 'link_platform.dart';

/// 链接采集结果（保真结构：原文 + sourceUrl 溯源，供 AI 区派生）。
class CapturedContent {
  final String url;
  final String title;
  final String? author;
  final String textContent;
  final String? htmlContent;
  final List<String> images;
  final LinkPlatform platform;
  final DateTime capturedAt;

  const CapturedContent({
    required this.url,
    required this.title,
    this.author,
    required this.textContent,
    this.htmlContent,
    this.images = const [],
    required this.platform,
    required this.capturedAt,
  });

  /// 降级产物：至少保留链接与标题，供手动粘贴兜底。
  factory CapturedContent.fallback(String url, String title) {
    return CapturedContent(
      url: url,
      title: title.isEmpty ? url : title,
      textContent: '',
      platform: LinkRecognizer.recognize(url),
      capturedAt: DateTime.now(),
    );
  }

  bool get isUsable => textContent.trim().isNotEmpty;
}
