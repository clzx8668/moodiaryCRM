import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 业务对象管理页：合同/回款/发票/提成等结构化浏览（P2.4 自定义表格 + P2.5 业务下钻）。
class BusinessObjectsPage extends StatelessWidget {
  const BusinessObjectsPage({super.key});

  static const tabs = [
    ('company', '客户'),
    ('person', '联系人'),
    ('opportunity', '商机'),
    ('task', '任务'),
    ('contractsHeTongGuanLi', '合同'),
    ('paymentsHuiKuanJiLu', '回款'),
    ('invoiceFaPiao', '发票'),
    ('commissionsTiChengJieSuan', '提成'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('业务对象'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in tabs) Tab(text: tab.$2)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in tabs)
              _ObjectTab(objectType: tab.$1, title: tab.$2),
          ],
        ),
      ),
    );
  }
}

class _ObjectTab extends StatefulWidget {
  final String objectType;
  final String title;

  const _ObjectTab({required this.objectType, required this.title});

  @override
  State<_ObjectTab> createState() => _ObjectTabState();
}

class _ObjectTabState extends State<_ObjectTab> {
  late Future<List<CrmEntityCache>> _future;
  bool _syncing = false;
  bool _tableView = false;
  String _query = '';
  String _sortField = 'name';
  bool _sortAsc = true;
  List<String> _columns = [];

  String get _columnPrefKey => 'crmTableColumns_${widget.objectType}';

  @override
  void initState() {
    super.initState();
    _future = IsarUtil.getCrmEntitiesByType(widget.objectType);
    _columns = PrefUtil.getValue<List<String>>(_columnPrefKey) ?? [];
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final baseUrl = await SecureStorageUtil.getValue('twentyBaseUrl');
      final token = await SecureStorageUtil.getValue('twentyApiToken');
      final service = CrmSyncService.fromConfig(
        TwentyConfig(
          baseUrl: baseUrl?.isNotEmpty == true
              ? baseUrl!
              : 'http://10.200.245.54:3000',
          apiToken: token ?? '',
        ),
      );
      final count = await service.pullObject(widget.objectType);
      toast.success(message: '已同步 $count 条 ${widget.title}');
    } catch (e) {
      toast.error(message: '同步失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _future = IsarUtil.getCrmEntitiesByType(widget.objectType);
        });
      }
    }
  }

  /// 可展示字段：排除 id/xxId/xxAt 等元字段
  static bool isDisplayField(String key) {
    if (key == 'id' || key == 'name') return false;
    if (key.endsWith('Id') || key.endsWith('At')) return false;
    if (key.startsWith('__')) return false;
    return true;
  }

  /// 从快照收集字段名（保持出现顺序稳定）
  List<String> _fieldNames(List<CrmEntityCache> items) {
    final names = <String>[];
    for (final item in items) {
      for (final key in item.data.keys) {
        if (isDisplayField(key) && !names.contains(key)) {
          names.add(key);
        }
      }
    }
    return names;
  }

  List<CrmEntityCache> _filtered(List<CrmEntityCache> items) {
    final q = _query.trim().toLowerCase();
    final list = items
        .where(
          (i) =>
              q.isEmpty ||
              i.name.toLowerCase().contains(q) ||
              i.data.values.any(
                (v) => v?.toString().toLowerCase().contains(q) == true,
              ),
        )
        .toList();
    list.sort((a, b) {
      final av = _fieldValue(a, _sortField);
      final bv = _fieldValue(b, _sortField);
      final cmp = av.compareTo(bv);
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  String _fieldValue(CrmEntityCache item, String field) {
    if (field == 'name') return item.name;
    return item.data[field]?.toString() ?? '';
  }

  Future<void> _showColumnSettings(List<CrmEntityCache> items) async {
    final all = _fieldNames(items);
    if (all.isEmpty) {
      toast.info(message: '该对象暂无可配置字段');
      return;
    }
    final local = List<String>.from(_columns);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('列设置'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final field in all)
                  CheckboxListTile(
                    dense: true,
                    value: local.contains(field),
                    title: Text(field, style: const TextStyle(fontSize: 13)),
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        if (!local.contains(field)) local.add(field);
                      } else {
                        local.remove(field);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() => _columns = local);
      await PrefUtil.setValue<List<String>>(_columnPrefKey, local);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CrmEntityCache>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = _filtered(snapshot.data!);
        final allFields = _fieldNames(snapshot.data!);
        final columns = _columns.where(allFields.contains).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: '搜索名称或字段…',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: '列表/表格',
                    onPressed: () => setState(() => _tableView = !_tableView),
                    icon: Icon(
                      _tableView
                          ? Icons.view_list_rounded
                          : Icons.table_chart_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: '列设置',
                    onPressed: () => _showColumnSettings(snapshot.data!),
                    icon: const Icon(Icons.view_column_outlined),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _syncing ? null : _sync,
                    icon: _syncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: const Text('同步'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '共 ${items.length} 条'
                  '${_query.trim().isNotEmpty ? '（过滤）' : ''}'
                  ' · ${_tableView ? '表格' : '列表'}视图',
                  style: context.textTheme.bodySmall,
                ),
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('暂无数据，请先同步'))
                  : _tableView
                  ? _buildTable(context, items, columns)
                  : _buildList(context, items),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(BuildContext context, List<CrmEntityCache> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Icon(
            _iconFor(item.entityType),
            color: _colorFor(item.entityType),
          ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _summary(item),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '${item.updatedAt.toLocal()}'.substring(0, 10),
            style: context.textTheme.labelSmall,
          ),
          onTap: () => _showDetail(context, item),
        );
      },
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<CrmEntityCache> items,
    List<String> columns,
  ) {
    final effectiveColumns = columns.isEmpty ? ['name'] : columns;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        sortColumnIndex: effectiveColumns.indexOf(_sortField),
        sortAscending: _sortAsc,
        columns: [
          for (final c in effectiveColumns)
            DataColumn(
              label: Text(
                c,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onSort: (i, asc) => setState(() {
                _sortField = effectiveColumns[i];
                _sortAsc = asc;
              }),
            ),
          const DataColumn(
            label: Text(''),
          ),
        ],
        rows: [
          for (final item in items)
            DataRow(
              onSelectChanged: (_) => _showDetail(context, item),
              cells: [
                for (final c in effectiveColumns)
                  DataCell(
                    Text(
                      _fieldValue(item, c),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                DataCell(
                  Icon(
                    _iconFor(item.entityType),
                    size: 16,
                    color: _colorFor(item.entityType),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _summary(CrmEntityCache item) {
    try {
      final data = item.data;
      final keys = data.keys.where(isDisplayField).take(3).toList();
      if (keys.isEmpty) return item.twentyId;
      return keys.map((k) => '$k: ${data[k]}').join(' · ');
    } catch (_) {
      return item.twentyId;
    }
  }

  /// P2.5 业务下钻：实体详情 + 相关日记
  void _showDetail(BuildContext context, CrmEntityCache item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '类型：${item.entityType}\n'
                  'Twenty ID：${item.twentyId}\n'
                  '最近同步：${item.lastSyncedAt.toLocal()}',
                  style: context.textTheme.bodySmall,
                ),
                const Divider(height: 16),
                Text('快照', style: context.textTheme.titleSmall),
                SelectableText(_prettyJson(item.dataJson)),
                const Divider(height: 16),
                Text('相关日记', style: context.textTheme.titleSmall),
                FutureBuilder<List<Diary>>(
                  future: IsarUtil.searchDiariesByText(item.name),
                  builder: (context, snapshot) {
                    final diaries = snapshot.data ?? [];
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (diaries.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '未找到包含「${item.name}」的日记',
                          style: context.textTheme.bodySmall,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final diary in diaries.take(10))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.article_outlined, size: 18),
                            title: Text(
                              diary.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${diary.time.toLocal()}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () {
                              Get.back();
                              Get.toNamed(
                                AppRoutes.diaryPage,
                                arguments: [diary, true],
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _prettyJson(String dataJson) {
    try {
      final decoded = jsonDecode(dataJson);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return dataJson;
    }
  }
}

IconData _iconFor(String type) {
  switch (type) {
    case 'company':
      return Icons.business_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'opportunity':
      return Icons.trending_up_rounded;
    case 'task':
      return Icons.task_alt_rounded;
    case 'contractsHeTongGuanLi':
      return Icons.description_rounded;
    case 'paymentsHuiKuanJiLu':
      return Icons.payments_rounded;
    case 'invoiceFaPiao':
      return Icons.receipt_rounded;
    case 'commissionsTiChengJieSuan':
      return Icons.savings_rounded;
    default:
      return Icons.folder_rounded;
  }
}

Color _colorFor(String type) {
  switch (type) {
    case 'company':
      return Colors.blue.shade400;
    case 'person':
      return Colors.green.shade400;
    case 'opportunity':
      return Colors.orange.shade400;
    case 'task':
      return Colors.purple.shade400;
    case 'contractsHeTongGuanLi':
      return Colors.teal.shade400;
    case 'paymentsHuiKuanJiLu':
      return Colors.red.shade400;
    case 'invoiceFaPiao':
      return Colors.indigo.shade400;
    case 'commissionsTiChengJieSuan':
      return Colors.pink.shade400;
    default:
      return Colors.grey;
  }
}
