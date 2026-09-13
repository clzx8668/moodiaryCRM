/// 订阅源配置（存 PrefUtil `feedSources`，不建 Drift 表）。
class FeedSource {
  String id;
  String url;
  String title;
  bool enabled;
  int lastFetchedAt; // 毫秒时间戳，0 表示从未
  List<String> lastItemKeys; // 已入库条目 key（用于增量去重，保留最近 N 条）

  /// 最近一次错误信息（不持久化语义，仅当前会话展示）
  String lastError;

  FeedSource({
    required this.id,
    required this.url,
    this.title = '',
    this.enabled = true,
    this.lastFetchedAt = 0,
    List<String>? lastItemKeys,
    this.lastError = '',
  }) : lastItemKeys = lastItemKeys ?? <String>[];

  String get displayTitle => title.trim().isEmpty ? url : title.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'enabled': enabled,
    'lastFetchedAt': lastFetchedAt,
    'lastItemKeys': lastItemKeys,
  };

  factory FeedSource.fromJson(Map<String, dynamic> json) {
    return FeedSource(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      enabled: json['enabled'] as bool? ?? true,
      lastFetchedAt: (json['lastFetchedAt'] as num?)?.toInt() ?? 0,
      lastItemKeys:
          (json['lastItemKeys'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
    );
  }

  FeedSource clone() => FeedSource(
    id: id,
    url: url,
    title: title,
    enabled: enabled,
    lastFetchedAt: lastFetchedAt,
    lastItemKeys: List<String>.from(lastItemKeys),
    lastError: lastError,
  );
}

/// 订阅条目（不持久化：解析后即落库为 Diary + Block）。
class FeedItem {
  final String title;
  final String link;

  /// 纯文本摘要（已去 HTML 标签/折叠空白）
  final String summary;

  /// 原始 HTML（description/content:encoded 等），用于正文兜底
  final String contentHtml;
  final String author;
  final String guid;
  final DateTime? publishedAt;

  const FeedItem({
    required this.title,
    required this.link,
    this.summary = '',
    this.contentHtml = '',
    this.author = '',
    this.guid = '',
    this.publishedAt,
  });
}

/// 单次拉取结果。
class FeedFetchResult {
  final FeedSource source;
  final List<FeedItem> items;
  final String? error;

  const FeedFetchResult({
    required this.source,
    this.items = const [],
    this.error,
  });

  bool get ok => error == null;
}
