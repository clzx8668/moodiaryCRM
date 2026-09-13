import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:moodiary/features/link_capture/link_html.dart';
import 'package:moodiary/features/link_capture/link_capture_service.dart';
import 'package:moodiary/persistence/pref.dart';

import 'feed_models.dart';
import 'feed_parser.dart';

/// 订阅服务：拉取 → 解析 → 增量过滤 →（可选）正文补齐。
///
/// - 订阅源以 JSON 存 PrefUtil（key `feedSources`），不建 Drift 表；
/// - 低频单源拉取，失败返回 error 不抛出（调用方记日志/展示状态）。
class FeedService {
  FeedService._();

  static const String prefKey = 'feedSources';
  static const int maxKeysPerSource = 200;
  static const int bodyThreshold = 200;

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (s) => s != null && s >= 200 && s < 400,
    ),
  );

  static List<FeedSource> loadSources() {
    try {
      final raw = PrefUtil.getValue<String>(prefKey) ?? '';
      if (raw.trim().isEmpty) return <FeedSource>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => FeedSource.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.url.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {
      // 坏数据回退空列表
    }
    return <FeedSource>[];
  }

  static Future<void> saveSources(List<FeedSource> sources) {
    return PrefUtil.setValue(
      prefKey,
      jsonEncode(sources.map((s) => s.toJson()).toList()),
    );
  }

  /// 摘要过短且有条目链接 → 需要抓正文（复用链接采集 + SPA 兜底）。
  static bool needsBody(FeedItem item) =>
      item.link.trim().isNotEmpty &&
      item.summary.trim().length < bodyThreshold;

  /// 合并去重键：新键在前，保留最近 [cap] 个。
  static List<String> updatedKeys(
    List<String> existing,
    Iterable<String> added, {
    int cap = maxKeysPerSource,
  }) {
    final seen = <String>{};
    final out = <String>[];
    for (final key in [...added, ...existing]) {
      final t = key.trim();
      if (t.isEmpty) continue;
      if (!seen.add(t)) continue;
      out.add(t);
      if (out.length >= cap) break;
    }
    return out;
  }

  static Future<FeedFetchResult> fetch(
    FeedSource source, {
    int maxItems = 10,
    bool enrichBody = true,
  }) async {
    try {
      final resp = await _dio.get<String>(
        source.url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': _ua},
        ),
      );
      final xml = resp.data ?? '';
      final parsed = FeedParser.parse(xml, maxItems: maxItems * 3);
      final seen = source.lastItemKeys.toSet();
      var fresh = FeedParser.newItems(items: parsed, seenKeys: seen)
          .take(maxItems)
          .toList();
      if (enrichBody) {
        final enriched = <FeedItem>[];
        for (final item in fresh) {
          enriched.add(await _enrich(item));
        }
        fresh = enriched;
      }
      return FeedFetchResult(source: source, items: fresh);
    } catch (e) {
      return FeedFetchResult(source: source, error: '$e');
    }
  }

  static Future<FeedItem> _enrich(FeedItem item) async {
    if (!needsBody(item)) return item;
    // feed 自带正文（Atom content）足够长时优先使用，避免抓到网页页脚噪音
    final feedBody = LinkHtml.collapse(LinkHtml.stripTags(item.contentHtml));
    if (feedBody.length >= bodyThreshold) {
      return item.copyWith(body: feedBody);
    }
    try {
      final captured = await LinkCaptureService.instance.capture(item.link);
      var body = captured.textContent.trim();
      if (body.isEmpty && captured.htmlContent != null) {
        body = item.summary;
      }
      if (body.isEmpty) return item;
      return item.copyWith(body: body);
    } catch (_) {
      return item;
    }
  }
}
