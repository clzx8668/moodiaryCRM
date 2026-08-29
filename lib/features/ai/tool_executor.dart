import 'dart:convert';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/search/search_service.dart';
import 'package:moodiary/features/ai/search/search_skill.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/search/global_search_service.dart';

/// AI 工具执行器（M4）：Function Calling 的工具注册与执行。
///
/// 本期工具：`note_search`（跨笔记搜索）、`crm_query`（CRM 读查询）、
/// `web_search`（联网搜索，M7）。
class ToolExecutor {
  final Map<String, Future<String> Function(Map<String, dynamic> args)>
      _tools = {};

  ToolExecutor() {
    register('note_search', _noteSearch);
    register('crm_query', _crmQuery);
    register('web_search', _webSearch);
  }

  void register(
    String name,
    Future<String> Function(Map<String, dynamic>) handler,
  ) {
    _tools[name] = handler;
  }

  bool has(String name) => _tools.containsKey(name);

  /// 工具定义（注册给模型的 JSON Schema）
  List<AiToolDef> get toolDefs => const [
    AiToolDef(
      name: 'note_search',
      description: '搜索用户的日记与子笔记',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '搜索关键词'},
          'tag': {'type': 'string', 'description': '按标签过滤（可选）'},
        },
        'required': ['query'],
      },
    ),
    AiToolDef(
      name: 'crm_query',
      description: '查询 CRM 中的客户、联系人、机会、合同等记录（只读）',
      parameters: {
        'type': 'object',
        'properties': {
          'keyword': {'type': 'string', 'description': '名称/关键词'},
          'limit': {'type': 'integer', 'description': '返回条数，默认 5'},
        },
        'required': ['keyword'],
      },
    ),
    AiToolDef(
      name: 'web_search',
      description: '联网搜索最新信息',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '搜索问题'},
        },
        'required': ['query'],
      },
    ),
  ];

  /// 执行工具调用，返回给模型的结果文本（失败也不抛，回可读错误）。
  Future<String> execute(AiToolCall call) async {
    Map<String, dynamic> args = const {};
    if (call.arguments.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(call.arguments);
        if (decoded is Map<String, dynamic>) args = decoded;
      } catch (_) {}
    }
    final handler = _tools[call.name];
    if (handler == null) return '工具「${call.name}」不存在';
    try {
      return await handler(args);
    } catch (e) {
      return '工具「${call.name}」执行失败：$e';
    }
  }

  Future<String> _noteSearch(Map<String, dynamic> args) async {
    final query = args['query']?.toString() ?? '';
    if (query.trim().isEmpty) return '缺少搜索关键词';
    final results = await GlobalSearchService.search(query);
    final notes = results
        .where((r) => r.type == 'diary' || r.type == 'block')
        .take(5)
        .toList();
    if (notes.isEmpty) return '未找到相关笔记';
    return notes.map((r) => '- ${r.title}：${r.snippet}').join('\n');
  }

  Future<String> _crmQuery(Map<String, dynamic> args) async {
    final keyword = args['keyword']?.toString() ?? '';
    final limit = (args['limit'] as num?)?.toInt() ?? 5;
    if (keyword.trim().isEmpty) return '缺少查询关键词';
    final repo = CrmLocalRepository();
    final out = <String>[];
    for (final a in await repo.listAccounts()) {
      if (a.name.contains(keyword)) out.add('客户：${a.name}');
      if (out.length >= limit) break;
    }
    if (out.length < limit) {
      for (final c in await repo.listContacts()) {
        if (c.name.contains(keyword)) out.add('联系人：${c.name}');
        if (out.length >= limit) break;
      }
    }
    if (out.length < limit) {
      for (final o in await repo.listOpportunities()) {
        if (o.name.contains(keyword)) out.add('机会：${o.name}');
        if (out.length >= limit) break;
      }
    }
    if (out.length < limit) {
      for (final c in await repo.listContracts()) {
        if (c.name.contains(keyword)) out.add('合同：${c.name}');
        if (out.length >= limit) break;
      }
    }
    if (out.isEmpty) return '未找到相关 CRM 记录';
    return out.join('\n');
  }

  Future<String> _webSearch(Map<String, dynamic> args) async {
    final query = args['query']?.toString() ?? '';
    if (query.trim().isEmpty) return '缺少搜索问题';
    if (!SearchConfig.enabled) {
      return '联网搜索未启用（设置 → AI 设置 → 联网搜索）';
    }
    final results = await SearchService.fromPrefs().search(query, maxResults: 5);
    return SearchSkill.formatResults(results);
  }
}
