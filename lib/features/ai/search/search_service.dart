import 'package:dio/dio.dart';
import 'package:moodiary/features/ai/search/search_skill.dart';

/// 联网搜索服务：按配置的引擎创建技能并执行搜索。
class SearchService {
  SearchService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// 按 pref 配置创建当前搜索引擎技能。
  static SearchSkill fromPrefs() {
    return create(
      SearchConfig.engine,
      url: SearchConfig.url,
      key: SearchConfig.key,
    );
  }

  static SearchSkill create(String engineId, {String url = '', String key = ''}) {
    return switch (engineId) {
      'searxng' => SearxngSearchSkill(dio: _dio, baseUrl: url),
      'tavily' => TavilySearchSkill(dio: _dio, apiKey: key),
      'bing' => BingSearchSkill(dio: _dio, apiKey: key),
      'custom' => CustomSearchSkill(dio: _dio, endpoint: url, apiKey: key),
      _ => DuckDuckGoSearchSkill(dio: _dio),
    };
  }
}

/// DuckDuckGo（HTML 端点，零配置默认）
class DuckDuckGoSearchSkill implements SearchSkill {
  final Dio dio;

  const DuckDuckGoSearchSkill({required this.dio});

  @override
  String get id => 'duckduckgo';

  @override
  String get displayName => 'DuckDuckGo (Free)';

  @override
  bool get requiresConfig => false;

  @override
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = 5,
  }) async {
    final resp = await dio.get<String>(
      'https://html.duckduckgo.com/html/',
      queryParameters: {'q': query},
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': 'Mozilla/5.0 Moodiary/2.10'},
      ),
    );
    final html = resp.data ?? '';
    return _parseHtml(html, maxResults);
  }

  List<SearchResult> _parseHtml(String html, int max) {
    final results = <SearchResult>[];
    // 每个结果块：<a class="result__a" href="...">title</a> ... <a class="result__snippet">...
    final blockRe = RegExp(
      r'<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>.*?'
      r'<a[^>]*class="result__snippet"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    for (final m in blockRe.allMatches(html)) {
      if (results.length >= max) break;
      final href = m.group(1) ?? '';
      final title = _strip(m.group(2) ?? '');
      final snippet = _strip(m.group(3) ?? '');
      if (href.isEmpty || title.isEmpty) continue;
      results.add(SearchResult(
        title: title,
        url: _decodeDdg(href),
        snippet: snippet,
      ));
    }
    return results;
  }

  String _decodeDdg(String href) {
    // DDG 跳转链接：//duckduckgo.com/l/?uddg=<encoded>
    final m = RegExp(r'uddg=([^&]+)').firstMatch(href);
    if (m != null) {
      try {
        return Uri.decodeComponent(m.group(1)!);
      } catch (_) {}
    }
    return href;
  }

  String _strip(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .trim();

  @override
  Future<bool> validateConfig() async => true;
}

/// SearXNG（自托管，JSON API）
class SearxngSearchSkill implements SearchSkill {
  final Dio dio;
  final String baseUrl;

  const SearxngSearchSkill({required this.dio, required this.baseUrl});

  @override
  String get id => 'searxng';

  @override
  String get displayName => 'SearXNG (Self-hosted)';

  @override
  bool get requiresConfig => true;

  @override
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = 5,
  }) async {
    final resp = await dio.get<Map<String, dynamic>>(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/search',
      queryParameters: {'q': query, 'format': 'json'},
    );
    final results = resp.data?['results'] as List? ?? const [];
    return results
        .whereType<Map>()
        .take(maxResults)
        .map(
          (m) => SearchResult(
            title: m['title']?.toString() ?? '',
            url: m['url']?.toString() ?? '',
            snippet: m['content']?.toString() ?? '',
          ),
        )
        .where((r) => r.title.isNotEmpty || r.snippet.isNotEmpty)
        .toList();
  }

  @override
  Future<bool> validateConfig() async {
    if (baseUrl.trim().isEmpty) return false;
    try {
      await search('test', maxResults: 1);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Tavily（API Key）
class TavilySearchSkill implements SearchSkill {
  final Dio dio;
  final String apiKey;

  const TavilySearchSkill({required this.dio, required this.apiKey});

  @override
  String get id => 'tavily';

  @override
  String get displayName => 'Tavily';

  @override
  bool get requiresConfig => true;

  @override
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = 5,
  }) async {
    final resp = await dio.post<Map<String, dynamic>>(
      'https://api.tavily.com/search',
      data: {
        'api_key': apiKey,
        'query': query,
        'max_results': maxResults,
      },
    );
    final results = resp.data?['results'] as List? ?? const [];
    return results
        .whereType<Map>()
        .map(
          (m) => SearchResult(
            title: m['title']?.toString() ?? '',
            url: m['url']?.toString() ?? '',
            snippet: m['content']?.toString() ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<bool> validateConfig() async {
    if (apiKey.trim().isEmpty) return false;
    try {
      await search('test', maxResults: 1);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Bing（API Key）
class BingSearchSkill implements SearchSkill {
  final Dio dio;
  final String apiKey;

  const BingSearchSkill({required this.dio, required this.apiKey});

  @override
  String get id => 'bing';

  @override
  String get displayName => 'Bing';

  @override
  bool get requiresConfig => true;

  @override
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = 5,
  }) async {
    final resp = await dio.get<Map<String, dynamic>>(
      'https://api.bing.microsoft.com/v7.0/search',
      queryParameters: {'q': query, 'count': maxResults, 'mkt': 'zh-CN'},
      options: Options(headers: {'Ocp-Apim-Subscription-Key': apiKey}),
    );
    final results = resp.data?['webPages']?['value'] as List? ?? const [];
    return results
        .whereType<Map>()
        .map(
          (m) => SearchResult(
            title: m['name']?.toString() ?? '',
            url: m['url']?.toString() ?? '',
            snippet: m['snippet']?.toString() ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<bool> validateConfig() async {
    if (apiKey.trim().isEmpty) return false;
    try {
      await search('test', maxResults: 1);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Custom（Endpoint + Key，POST JSON）
class CustomSearchSkill implements SearchSkill {
  final Dio dio;
  final String endpoint;
  final String apiKey;

  const CustomSearchSkill({
    required this.dio,
    required this.endpoint,
    required this.apiKey,
  });

  @override
  String get id => 'custom';

  @override
  String get displayName => 'Custom';

  @override
  bool get requiresConfig => true;

  @override
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = 5,
  }) async {
    final resp = await dio.post<Map<String, dynamic>>(
      endpoint,
      data: {'query': query, 'api_key': apiKey, 'max_results': maxResults},
    );
    final data = resp.data;
    final raw = data?['results'] ?? data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .take(maxResults)
        .map(
          (m) => SearchResult(
            title: m['title']?.toString() ?? '',
            url: m['url']?.toString() ?? '',
            snippet: m['snippet']?.toString() ?? m['content']?.toString() ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<bool> validateConfig() async {
    if (endpoint.trim().isEmpty) return false;
    try {
      await search('test', maxResults: 1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
