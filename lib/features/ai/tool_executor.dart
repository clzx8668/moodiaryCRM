import 'dart:convert';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/search/search_service.dart';
import 'package:moodiary/features/ai/search/search_skill.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_write_service.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/features/search/global_search_service.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';

/// CRM 写操作确认回调（由 UI 层注册弹确认卡片）。
typedef CrmWriteConfirmCallback =
    Future<bool> Function(CrmWriteProposal proposal);

/// AI 工具执行器（M4）：Function Calling 的工具注册与执行。
///
/// 工具：`note_search`（跨笔记搜索）、`crm_query`（CRM 读）、
/// `crm_create/update/delete`（CRM 写，需确认卡片，M6）、
/// `web_search`（联网搜索，M7）、`obsidian_search`（Obsidian 检索，M8）。
class ToolExecutor {
  final Map<String, Future<String> Function(Map<String, dynamic> args)>
      _tools = {};

  /// CRM 写操作确认回调；未注册时写工具拒绝执行（安全兜底）。
  CrmWriteConfirmCallback? onCrmWriteConfirm;

  ToolExecutor() {
    register('note_search', _noteSearch);
    register('crm_query', _crmQuery);
    register('web_search', _webSearch);
    register('obsidian_search', _obsidianSearch);
    register('crm_create', (args) => _crmWrite('create', args));
    register('crm_update', (args) => _crmWrite('update', args));
    register('crm_delete', (args) => _crmWrite('delete', args));
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
    AiToolDef(
      name: 'obsidian_search',
      description: '搜索 Obsidian Vault 中的笔记（需已配置并启用 Obsidian）',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '搜索关键词'},
        },
        'required': ['query'],
      },
    ),
    AiToolDef(
      name: 'crm_create',
      description: '创建 CRM 记录（客户/联系人/商机/合同等）；'
          '调用后必须等待用户确认再执行',
      parameters: {
        'type': 'object',
        'properties': {
          'object': {
            'type': 'string',
            'description': '对象类型：account/contact/opportunity/contract/'
                'product/quote/paymentPlan/payment/invoice/warranty/'
                'afterSales/activity/reminder',
          },
          'fields': {
            'type': 'object',
            'description': '字段名→值，如 {"name":"示例公司","phone":"13800000000"}',
          },
        },
        'required': ['object', 'fields'],
      },
    ),
    AiToolDef(
      name: 'crm_update',
      description: '更新 CRM 记录字段；调用后必须等待用户确认再执行',
      parameters: {
        'type': 'object',
        'properties': {
          'object': {
            'type': 'string',
            'description': '对象类型（同 crm_create）',
          },
          'id': {'type': 'string', 'description': '记录 id'},
          'fields': {
            'type': 'object',
            'description': '要更新的字段名→值',
          },
        },
        'required': ['object', 'id', 'fields'],
      },
    ),
    AiToolDef(
      name: 'crm_delete',
      description: '删除 CRM 记录（软删除）；调用后必须等待用户确认再执行',
      parameters: {
        'type': 'object',
        'properties': {
          'object': {
            'type': 'string',
            'description': '对象类型（同 crm_create）',
          },
          'id': {'type': 'string', 'description': '记录 id'},
        },
        'required': ['object', 'id'],
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

  Future<String> _obsidianSearch(Map<String, dynamic> args) async {
    final query = args['query']?.toString() ?? '';
    if (query.trim().isEmpty) return '缺少搜索关键词';
    if (!ObsidianConfig.isReady) {
      return 'Obsidian 未启用（设置 → 数据源 → Obsidian）';
    }
    await ObsidianService.instance.scan();
    final hits = ObsidianService.instance.search(query).take(5).toList();
    if (hits.isEmpty) return '未找到相关 Obsidian 笔记';
    return hits
        .map(
          (f) => '- ${f.relativePath}：'
              '${f.content.length > 80 ? f.content.substring(0, 80) : f.content}',
        )
        .join('\n');
  }

  Future<String> _crmWrite(
    String action,
    Map<String, dynamic> args,
  ) async {
    CrmWriteProposal proposal;
    try {
      proposal = await CrmWriteService.buildProposal(
        action: action,
        args: args,
      );
    } catch (e) {
      return 'CRM ${_actionName(action)}操作参数不完整：${_strip(e)}';
    }

    final confirm = onCrmWriteConfirm;
    if (confirm == null) {
      return 'CRM ${_actionName(action)}${proposal.objectLabel}操作需要用户确认，'
          '但当前界面未提供确认入口';
    }
    final approved = await confirm(proposal);
    if (!approved) {
      return '用户取消了「${proposal.actionLabel}${proposal.objectLabel}」操作，'
          '未执行任何修改';
    }

    try {
      return await CrmWriteService.execute(proposal);
    } catch (e) {
      await SyncLogService.instance.write(
        level: SyncLogLevel.error,
        operation: 'crm_write',
        target: proposal.objectType,
        detail: 'AI ${proposal.actionLabel}${proposal.objectLabel}失败',
        error: _strip(e),
      );
      return 'CRM ${proposal.actionLabel}${proposal.objectLabel}操作失败：'
          '${_strip(e)}';
    }
  }

  static String _actionName(String action) => switch (action) {
    'create' => '创建',
    'update' => '更新',
    _ => '删除',
  };

  static String _strip(Object e) =>
      e.toString().replaceFirst('Exception: ', '');
}
