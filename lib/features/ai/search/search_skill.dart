import 'package:moodiary/persistence/pref.dart';

/// 联网搜索结果
class SearchResult {
  final String title;
  final String url;
  final String snippet;

  const SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });
}

/// 搜索技能抽象（可插拔：DuckDuckGo / SearXNG / Tavily / Bing / Custom）
abstract class SearchSkill {
  String get id;
  String get displayName;

  /// 是否需要 URL / API Key 配置（DuckDuckGo 零配置）
  bool get requiresConfig;

  Future<List<SearchResult>> search(
    String query, {
    int maxResults = 5,
  });

  /// 验证配置是否有效（设置页「测试连接」）
  Future<bool> validateConfig();

  /// 把结果格式化为可注入上下文的文本
  static String formatResults(List<SearchResult> results) {
    if (results.isEmpty) return '（无搜索结果）';
    final buffer = StringBuffer();
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('${i + 1}. ${r.title}');
      buffer.writeln('   ${r.snippet}');
      buffer.writeln('   来源：${r.url}');
    }
    return buffer.toString();
  }
}

/// 搜索引擎配置读取（pref 持久化）
class SearchConfig {
  static const kEnabled = 'aiSearchEnabled';
  static const kEngine = 'aiSearchEngine';
  static const kUrl = 'aiSearchUrl';
  static const kKey = 'aiSearchKey';

  static const defaultEngine = 'duckduckgo';

  static bool get enabled => PrefUtil.getValue<bool>(kEnabled) ?? false;

  static String get engine => PrefUtil.getValue<String>(kEngine) ?? defaultEngine;

  static String get url => PrefUtil.getValue<String>(kUrl) ?? '';

  static String get key => PrefUtil.getValue<String>(kKey) ?? '';
}
