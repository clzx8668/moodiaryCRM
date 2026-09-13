import 'dart:io';

import 'package:moodiary/features/link_capture/link_html.dart';

import 'feed_models.dart';

/// RSS 2.0 / Atom 解析（纯函数，零新增依赖）。
class FeedParser {
  FeedParser._();

  static const Map<String, int> _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// 解析 XML 为条目列表（自动识别 RSS/Atom）。
  static List<FeedItem> parse(String xml, {int maxItems = 50}) {
    if (xml.trim().isEmpty) return const [];
    final isAtom = RegExp(r'<feed[\s>]', caseSensitive: false).hasMatch(xml);
    final blockTag = isAtom ? 'entry' : 'item';
    final blocks = _blocks(xml, blockTag);
    final items = <FeedItem>[];
    for (final block in blocks) {
      if (items.length >= maxItems) break;
      final item = isAtom ? _parseAtomEntry(block) : _parseRssItem(block);
      if (item == null) continue;
      if (item.title.trim().isEmpty && item.link.trim().isEmpty) continue;
      items.add(item);
    }
    return items;
  }

  static FeedItem? _parseRssItem(String block) {
    final title = _text(block, 'title');
    final link = _text(block, 'link') ?? _href(block) ?? '';
    final contentHtml =
        _text(block, 'content:encoded') ?? _text(block, 'description') ?? '';
    final summaryRaw = _text(block, 'description') ?? contentHtml;
    final author = _text(block, 'dc:creator') ?? _text(block, 'author') ?? '';
    final guid = _text(block, 'guid') ?? link;
    final dateRaw =
        _text(block, 'pubDate') ??
        _text(block, 'dc:date') ??
        _text(block, 'published') ??
        '';
    return FeedItem(
      title: title ?? '',
      link: link,
      summary: _plain(summaryRaw),
      contentHtml: contentHtml,
      author: author,
      guid: guid,
      publishedAt: parseDate(dateRaw),
    );
  }

  static FeedItem? _parseAtomEntry(String block) {
    final title = _text(block, 'title');
    final link = _href(block) ?? _text(block, 'link') ?? '';
    final contentHtml = _text(block, 'content') ?? _text(block, 'summary') ?? '';
    final summaryRaw = _text(block, 'summary') ?? contentHtml;
    final author = _text(block, 'name') ?? _text(block, 'author') ?? '';
    final guid = _text(block, 'id') ?? link;
    final dateRaw = _text(block, 'published') ?? _text(block, 'updated') ?? '';
    return FeedItem(
      title: title ?? '',
      link: link,
      summary: _plain(summaryRaw),
      contentHtml: contentHtml,
      author: author,
      guid: guid,
      publishedAt: parseDate(dateRaw),
    );
  }

  /// 条目去重键：优先 link + 标题（归一化），避免同一文章因 guid 变化重复入库；
  /// 无 link 时退回 guid。
  static String itemKey(FeedItem item) {
    final link = item.link.trim();
    final title = item.title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final raw = link.isNotEmpty
        ? '$link|$title'
        : (item.guid.trim().isNotEmpty ? item.guid.trim() : title);
    return stableHash(raw);
  }

  /// 稳定短哈希（FNV-1a 32bit，足够本地去重）。
  static String stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// 增量过滤：排除已入库 key。
  static List<FeedItem> newItems({
    required List<FeedItem> items,
    required Set<String> seenKeys,
  }) {
    return items.where((i) => !seenKeys.contains(itemKey(i))).toList();
  }

  /// 解析日期：支持 RFC822/HTTP 日期与 ISO8601。
  static DateTime? parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      return HttpDate.parse(s);
    } catch (_) {
      // 落到下面的兜底
    }
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    final m = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\s+(\d{2,4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4})?',
    ).firstMatch(s);
    if (m == null) return null;
    final month = _months[m.group(2)!.toLowerCase()];
    if (month == null) return null;
    var year = int.tryParse(m.group(3)!) ?? 0;
    if (year < 100) year += 2000;
    var dt = DateTime.utc(
      year,
      month,
      int.tryParse(m.group(1)!) ?? 1,
      int.tryParse(m.group(4)!) ?? 0,
      int.tryParse(m.group(5)!) ?? 0,
      int.tryParse(m.group(6) ?? '0') ?? 0,
    );
    final offset = m.group(7);
    if (offset != null && offset.length == 5) {
      final sign = offset.startsWith('-') ? -1 : 1;
      final hh = int.tryParse(offset.substring(1, 3)) ?? 0;
      final mm = int.tryParse(offset.substring(3, 5)) ?? 0;
      dt = dt.subtract(Duration(minutes: sign * (hh * 60 + mm)));
    }
    return dt;
  }

  // ===== XML 辅助（私有） =====

  static List<String> _blocks(String xml, String tag) {
    final re = RegExp(
      '<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    );
    return re.allMatches(xml).map((m) => m.group(1) ?? '').toList();
  }

  /// 取指定标签的文本（去 CDATA、解码实体、去首尾空白）。
  static String? _text(String block, String tag) {
    final re = RegExp(
      '<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    );
    final m = re.firstMatch(block);
    if (m == null) return null;
    return _decode(_stripCdata(m.group(1) ?? '')).trim();
  }

  /// 取第一个 `<link href="...">`（Atom）或 `<enclosure url="...">`。
  static String? _href(String block) {
    final linkTag = RegExp(
      '<link[^>]*\\bhref=[\'"]([^\'"]+)[\'"]',
      caseSensitive: false,
    ).firstMatch(block);
    if (linkTag != null) return _decode(linkTag.group(1) ?? '').trim();
    final enc = RegExp(
      '<enclosure[^>]*\\burl=[\'"]([^\'"]+)[\'"]',
      caseSensitive: false,
    ).firstMatch(block);
    return enc == null ? null : _decode(enc.group(1) ?? '').trim();
  }

  static String _stripCdata(String s) {
    final m = RegExp(r'^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$').firstMatch(s);
    return m == null ? s : (m.group(1) ?? '');
  }

  /// 实体解码（复用 LinkHtml 并补十六进制实体）。
  static String _decode(String s) {
    var r = LinkHtml.unescape(s);
    r = r.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.tryParse(m.group(1)!, radix: 16) ?? 0),
    );
    return r;
  }

  static String _plain(String html) =>
      LinkHtml.collapse(LinkHtml.stripTags(_decode(html)));
}
