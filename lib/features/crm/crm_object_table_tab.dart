import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/crm/crm_field_registry.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/crm/widgets/crm_smart_table.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

/// CRM 主要对象（顶部 Tab 页定义）：与 Twenty 对象名保持动态对应。
class CrmTabDef {
  final String type;
  final String label;

  const CrmTabDef(this.type, this.label);
}

/// CRM 顶部 Tab 默认集合（设置页可开关各页显隐）
const List<CrmTabDef> kCrmTabs = [
  CrmTabDef('company', '客户'),
  CrmTabDef('person', '联系人'),
  CrmTabDef('opportunity', '机会'),
  CrmTabDef('contractsHeTongGuanLi', '合同'),
  CrmTabDef('paymentsHuiKuanJiLu', '回款'),
  CrmTabDef('invoiceFaPiao', '发票'),
  CrmTabDef('commissionsTiChengJieSuan', '提成'),
  CrmTabDef('task', '任务'),
  CrmTabDef('note', '笔记'),
  CrmTabDef('moodiaryGeneric', '通用记录'),
];

/// 按设置过滤后的可见 Tab
List<CrmTabDef> visibleCrmTabs() {
  return kCrmTabs
      .where(
        (tab) => PrefUtil.getValue<bool>('crmTabVisible_${tab.type}') ?? true,
      )
      .toList();
}

String crmTypeLabel(String type) {
  const labels = {
    'company': '客户',
    'person': '联系人',
    'opportunity': '机会',
    'task': '任务',
    'note': '笔记',
    'moodiaryGeneric': '通用记录',
    'contractsHeTongGuanLi': '合同',
    'paymentsHuiKuanJiLu': '回款',
    'invoiceFaPiao': '发票',
    'commissionsTiChengJieSuan': '提成',
  };
  return labels[type] ?? type;
}

IconData crmTypeIcon(String type) {
  switch (type) {
    case 'company':
      return Icons.business_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'opportunity':
      return Icons.trending_up_rounded;
    case 'task':
      return Icons.task_alt_rounded;
    case 'note':
      return Icons.notes_rounded;
    case 'moodiaryGeneric':
      return Icons.inbox_rounded;
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

Color crmTypeColor(String type) {
  switch (type) {
    case 'company':
      return Colors.blue.shade400;
    case 'person':
      return Colors.green.shade400;
    case 'opportunity':
      return Colors.orange.shade400;
    case 'task':
      return Colors.purple.shade400;
    case 'note':
      return Colors.brown.shade400;
    case 'moodiaryGeneric':
      return Colors.blueGrey.shade400;
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

/// 单个对象 Tab：智能表格 + 搜索/列设置 + 同步 + 增删改查 + 业务下钻。
class CrmObjectTableTab extends StatefulWidget {
  final String objectType;
  final String title;

  /// 全量同步等外部事件触发的重载令牌（变化时重新加载数据）
  final int reloadToken;

  const CrmObjectTableTab({
    super.key,
    required this.objectType,
    required this.title,
    this.reloadToken = 0,
  });

  @override
  State<CrmObjectTableTab> createState() => _CrmObjectTableTabState();
}

class _CrmObjectTableTabState extends State<CrmObjectTableTab> {
  late Future<List<CrmEntityCache>> _future;
  bool _syncing = false;
  bool _saving = false;
  String _query = '';
  List<String> _columns = [];
  CrmObjectMeta? _meta;

  String get _columnPrefKey => 'crmTableColumns_${widget.objectType}';

  @override
  void initState() {
    super.initState();
    _future = IsarUtil.getCrmEntitiesByType(widget.objectType);
    _columns = PrefUtil.getValue<List<String>>(_columnPrefKey) ?? [];
    _loadFieldMeta();
  }

  Future<void> _loadFieldMeta() async {
    try {
      final service = await _service();
      final meta = await CrmFieldRegistry.fetchObjectMeta(
        service.client,
        widget.objectType,
      );
      if (mounted && meta != null) {
        setState(() => _meta = meta);
      }
    } catch (_) {
      // 元数据拉取失败不阻塞表格（回退快照字段）
    }
  }

  @override
  void didUpdateWidget(covariant CrmObjectTableTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _future = IsarUtil.getCrmEntitiesByType(widget.objectType);
    });
  }

  Future<void> _sync() async {
    if (_syncing) return;
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
        setState(() => _syncing = false);
        _reload();
      }
    }
  }

  static bool isDisplayField(String key) {
    if (key == 'id' || key == 'name') return false;
    if (key.endsWith('Id')) return false;
    if (key.startsWith('__')) return false;
    const audit = {
      'createdAt',
      'updatedAt',
      'deletedAt',
      'lastSyncedAt',
      'position',
      'searchVector',
    };
    if (audit.contains(key)) return false;
    return true;
  }

  static bool isEditableField(String key) {
    if (key == 'id' || key == 'twentyId') return false;
    if (key.endsWith('Id')) return false;
    if (key.startsWith('__')) return false;
    if (key == 'createdAt' ||
        key == 'updatedAt' ||
        key == 'lastSyncedAt' ||
        key == 'deletedAt' ||
        key == 'position') {
      return false;
    }
    return true;
  }

  List<String> _fieldNames(List<CrmEntityCache> items) {
    final names = <String>[_labelField];
    for (final item in items) {
      for (final key in item.data.keys) {
        if (isDisplayField(key) && !names.contains(key)) names.add(key);
      }
    }
    return names;
  }

  /// 对象标签字段（优先 Twenty labelIdentifier，兜底命名规则）
  String get _labelField =>
      (_meta?.labelField.isNotEmpty == true
          ? _meta!.labelField
          : CrmSyncService.labelFieldFor(widget.objectType));

  /// 是否已自定义列（默认 false → 跟随 Twenty 默认字段）
  bool get _customized =>
      PrefUtil.getValue<bool>(
        'crmTableColumnsCustomized_${widget.objectType}',
      ) ??
      false;

  /// 当前展示列：自定义时用持久化顺序，否则用 Twenty 默认字段
  List<String> _effectiveColumns(List<CrmEntityCache> items, List<String> all) {
    if (_customized && _columns.isNotEmpty) {
      return _columns.where(all.contains).toList();
    }
    final meta = _meta;
    if (meta != null) {
      final defaults = CrmFieldRegistry.defaultDisplayFields(meta)
          .map((f) => f.name)
          .where(all.contains)
          .toList();
      if (defaults.isNotEmpty) return defaults;
    }
    return [_labelField];
  }

  List<CrmEntityCache> _filtered(List<CrmEntityCache> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.data.values.any(
                (v) => v?.toString().toLowerCase().contains(q) == true,
              ),
        )
        .toList();
  }

  Future<void> _showColumnSettings(List<CrmEntityCache> items) async {
    final all = _fieldNames(items);
    final candidates = _allCandidateFields(all);
    if (candidates.length <= 1) {
      toast.info(message: '该对象暂无可配置字段');
      return;
    }
    var visible = _effectiveColumns(items, all).toList();
    if (visible.isEmpty) visible = [candidates.first];
    var customized = _customized;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final hidden = candidates
              .where((f) => !visible.contains(f))
              .toList();
          return AlertDialog(
            title: const Text('列设置（显示 / 顺序）'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '拖动调整顺序，勾选控制显示（遵循 Twenty 对象字段规则）',
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      onReorder: (oldIndex, newIndex) {
                        setDialogState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = visible.removeAt(oldIndex);
                          visible.insert(newIndex, item);
                          customized = true;
                        });
                      },
                      itemBuilder: (context, index) {
                        final field = visible[index];
                        return ListTile(
                          key: ValueKey(field),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle_rounded),
                          ),
                          title: Text(
                            _fieldLabel(field),
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: Checkbox(
                            value: true,
                            onChanged: (v) => setDialogState(() {
                              if (v == false) {
                                visible.remove(field);
                                customized = true;
                              }
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                  if (hidden.isNotEmpty) ...[
                    const Divider(height: 8),
                    Text(
                      '隐藏字段（点击恢复显示）',
                      style: context.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final field in hidden)
                          ActionChip(
                            label: Text(
                              _fieldLabel(field),
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setDialogState(() {
                              visible.add(field);
                              customized = true;
                            }),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(() {
                  visible = _defaultColumns(all);
                  customized = false;
                }),
                child: const Text('恢复默认'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      setState(() => _columns = visible);
      await PrefUtil.setValue<List<String>>(_columnPrefKey, visible);
      await PrefUtil.setValue<bool>(
        'crmTableColumnsCustomized_${widget.objectType}',
        customized,
      );
    }
  }

  /// 候选字段：Twenty metadata（标签 + 可展示标量）优先，快照字段兜底
  List<String> _allCandidateFields(List<String> snapshotFields) {
    final result = <String>[];
    final meta = _meta;
    if (meta != null) {
      final ordered = CrmFieldRegistry.defaultDisplayFields(meta);
      for (final f in ordered) {
        if (!result.contains(f.name)) result.add(f.name);
      }
    }
    for (final f in snapshotFields) {
      if (!result.contains(f)) result.add(f);
    }
    return result;
  }

  /// 默认列（Twenty 规则；meta 缺失时退化为标签字段）
  List<String> _defaultColumns(List<String> snapshotFields) {
    final meta = _meta;
    if (meta != null) {
      final defaults = CrmFieldRegistry.defaultDisplayFields(meta)
          .map((f) => f.name)
          .where(snapshotFields.contains)
          .toList();
      if (defaults.isNotEmpty) return defaults;
    }
    return [_labelField];
  }

  /// 表格内拖拽列排序 → 持久化
  Future<void> _persistColumnOrder(List<String> order) async {
    if (order.isEmpty || _listEquals(order, _columns)) return;
    setState(() => _columns = List<String>.from(order));
    await PrefUtil.setValue<List<String>>(_columnPrefKey, List<String>.from(order));
    await PrefUtil.setValue<bool>(
      'crmTableColumnsCustomized_${widget.objectType}',
      true,
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _create(List<CrmEntityCache> items) async {
    final fields = _editableColumns(items);
    final controllers = <String, TextEditingController>{
      for (final f in fields) f: TextEditingController(),
    };
    if (controllers.isEmpty) {
      toast.info(message: '无可编辑字段，请先在列设置中勾选字段');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('新增${widget.title}'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[field],
                      keyboardType: _isNumber(field, items)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : null,
                      decoration: InputDecoration(
                        labelText: _fieldLabel(field),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('创建并同步'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        for (final field in fields)
          if (controllers[field]!.text.trim().isNotEmpty)
            field: _typedValue(field, controllers[field]!.text.trim(), items),
      };
      if (data.isEmpty) {
        toast.info(message: '请至少填写一个字段');
        return;
      }
      final service = await _service();
      await service.createEntity(widget.objectType, data);
      toast.success(message: '已创建并同步');
      _reload();
    } catch (e) {
      toast.error(message: '创建失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(CrmEntityCache item) async {
    final fields = _editableColumns([item]);
    final controllers = <String, TextEditingController>{
      for (final f in fields)
        f: TextEditingController(
          text: _stringValue(item, f),
        ),
    };
    if (controllers.isEmpty) {
      _showDetail(item);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('编辑 ${item.name}'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[field],
                      keyboardType: _isNumber(field, [item])
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : null,
                      decoration: InputDecoration(
                        labelText: _fieldLabel(field),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存并同步'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        for (final field in fields)
          if (controllers[field]!.text.trim().isNotEmpty)
            field: _typedValue(field, controllers[field]!.text.trim(), [item]),
      };
      final service = await _service();
      await service.updateEntity(widget.objectType, item.twentyId, data);
      toast.success(message: '已保存并同步');
      _reload();
    } catch (e) {
      toast.error(message: '更新失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(CrmEntityCache item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('将删除「${item.name}」并同步 Twenty，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final service = await _service();
      await service.deleteEntity(widget.objectType, item.twentyId);
      toast.success(message: '已删除');
      _reload();
    } catch (e) {
      toast.error(message: '删除失败：$e');
    }
  }

  Future<void> _updateCell(
    CrmEntityCache item,
    String field,
    Object? value,
  ) async {
    if (!isEditableField(field)) return;
    setState(() => _saving = true);
    try {
      // 仅提交可编辑字段，避免把 createdAt/position/xxId 等只读字段带入 UpdateInput
      final data = <String, dynamic>{};
      for (final entry in item.data.entries) {
        if (isEditableField(entry.key)) {
          data[entry.key] = entry.value;
        }
      }
      if (field == _labelField) {
        data[_labelField] = value;
      } else {
        data[field] = value;
      }
      final service = await _service();
      await service.updateEntity(widget.objectType, item.twentyId, data);
    } catch (e) {
      toast.error(message: '保存失败：$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _reload();
      }
    }
  }

  Future<CrmSyncService> _service() async {
    final baseUrl = await SecureStorageUtil.getValue('twentyBaseUrl');
    final token = await SecureStorageUtil.getValue('twentyApiToken');
    return CrmSyncService.fromConfig(
      TwentyConfig(
        baseUrl: baseUrl?.isNotEmpty == true
            ? baseUrl!
            : 'http://10.200.245.54:3000',
        apiToken: token ?? '',
      ),
    );
  }

  List<String> _editableColumns(List<CrmEntityCache> items) {
    final all = _fieldNames(items);
    final effective = _effectiveColumns(items, all);
    return effective.where(isEditableField).toList();
  }

  bool _isNumber(String field, List<CrmEntityCache> items) {
    for (final item in items) {
      final value = item.data[field];
      if (value is num) return true;
      if (value is String && value.isNotEmpty && double.tryParse(value) != null) {
        return true;
      }
    }
    return false;
  }

  Object? _typedValue(
    String field,
    String raw,
    List<CrmEntityCache> items,
  ) {
    if (_isNumber(field, items)) {
      return num.tryParse(raw) ?? raw;
    }
    return raw;
  }

  String _stringValue(CrmEntityCache item, String field) {
    if (field == _labelField) return item.name;
    return item.data[field]?.toString() ?? '';
  }

  String _fieldLabel(String field) {
    final meta = _meta;
    if (meta != null) {
      for (final f in meta.fields) {
        if (f.name == field && f.label.isNotEmpty) return f.label;
      }
    }
    const labels = {
      'name': '名称',
      'title': '标题',
      'contractName': '合同名称',
      'amount': '金额',
      'status': '状态',
      'dueAt': '到期时间',
      'description': '描述',
      'note': '备注',
      'phone': '电话',
      'email': '邮箱',
    };
    return labels[field] ?? field;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CrmEntityCache>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!;
        final items = _filtered(all);
        final fields = _fieldNames(all);
        final effectiveColumns = _effectiveColumns(all, fields);
        final needsSync =
            !_customized &&
            _meta != null &&
            effectiveColumns.length <= 1 &&
            fields.length > 1;
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
                    tooltip: '列设置',
                    onPressed: () => _showColumnSettings(all),
                    icon: const Icon(Icons.view_column_outlined),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : () => _create(all),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('新增'),
                  ),
                  const SizedBox(width: 6),
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
                  '${needsSync ? ' · 重新同步可加载全部字段' : ''}'
                  ' · 双击行编辑 / 右键更多',
                  style: context.textTheme.bodySmall,
                ),
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            crmTypeIcon(widget.objectType),
                            size: 40,
                            color: crmTypeColor(widget.objectType),
                          ),
                          const SizedBox(height: 8),
                          const Text('暂无数据，点击「同步」拉取 Twenty 数据'),
                        ],
                      ),
                    )
                  : CrmSmartTable(
                      items: items,
                      fields: effectiveColumns,
                      onCellChanged: _updateCell,
                      onOpen: _edit,
                      onColumnsReordered: _persistColumnOrder,
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 业务下钻：实体详情 + 相关日记（保留 P2.5 能力）
  void _showDetail(CrmEntityCache item) {
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
                  '类型：${crmTypeLabel(item.entityType)}\n'
                  'Twenty ID：${item.twentyId}\n'
                  '最近同步：${item.lastSyncedAt.toLocal()}',
                  style: context.textTheme.bodySmall,
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Text('快照', style: context.textTheme.titleSmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _edit(item),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('编辑'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Get.back();
                        _delete(item);
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      label: const Text('删除'),
                    ),
                  ],
                ),
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
