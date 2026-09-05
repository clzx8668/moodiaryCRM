/// 轻量 HTML 提取（纯函数，不引入第三方解析库，避免新增原生依赖）。
///
/// 覆盖通用网页 + 微信公众号单篇；B站/抖音走 JSON/元数据，不走 HTML 正文。
class LinkHtml {
  LinkHtml._();

  static const _entityMap = <String, String>{
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };

  static String unescape(String s) {
    var r = s;
    for (final e in _entityMap.entries) {
      r = r.replaceAll(e.key, e.value);
    }
    r = r.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.tryParse(m.group(1)!) ?? 0),
    );
    return r;
  }

  static String stripTags(String html) {
    var s = html;
    s = s.replaceAll(
      RegExp(
        r'<(script|style|noscript|svg|iframe)[^>]*>[\s\S]*?</\1>',
        caseSensitive: false,
      ),
      ' ',
    );
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return unescape(s);
  }

  /// 折叠空白并去掉首尾。
  static String collapse(String s) {
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 提取 <title>（用于 B站/通用标题兜底）。
  static String extractTitle(String html) {
    final m = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (m != null) return collapse(unescape(m.group(1)!));

    final og = RegExp(
      '<meta[^>]*property=[\'"]og:title[\'"][^>]*content=[\'"]([^\'"]*)[\'"]',
      caseSensitive: false,
    ).firstMatch(html);
    if (og != null) return collapse(unescape(og.group(1)!));
    return '';
  }

  /// 提取正文纯文本：去脚本/样式 → 去标签 → 折叠空白。可截断到 [maxLen]。
  static String extractReadableText(String html, {int maxLen = 20000}) {
    var text = collapse(stripTags(html));
    if (text.length > maxLen) {
      text = '${text.substring(0, maxLen)}…';
    }
    return text;
  }

  /// 提取正文图片 URL（data-src/src），去重并跳过 data URI。
  static List<String> extractImages(String html) {
    final result = <String>[];
    final seen = <String>{};
    final patterns = [
      RegExp(r'<img[^>]*?\b(?:data-src|src)="([^"]*)"', caseSensitive: false),
      RegExp(r"<img[^>]*?\b(?:data-src|src)='([^']*)'", caseSensitive: false),
    ];
    for (final re in patterns) {
      for (final m in re.allMatches(html)) {
        final src = m.group(1) ?? '';
        if (src.isEmpty || src.startsWith('data:')) continue;
        if (seen.add(src)) result.add(src);
      }
    }
    return result;
  }

  /// 提取指定 id 元素的 innerText（公众号 #js_content / #activity-name）。
  static String innerTextById(String html, String id) {
    final open = RegExp(
      '<[^>]+id=[\'"]${RegExp.escape(id)}[\'"][^>]*>',
      caseSensitive: false,
    ).firstMatch(html);
    if (open == null) return '';
    final start = open.end;
    final close = RegExp(
      r'</(?:div|section|article)>',
      caseSensitive: false,
    ).firstMatch(html.substring(start));
    if (close == null) return '';
    return extractReadableText(html.substring(start, start + close.start));
  }
}
