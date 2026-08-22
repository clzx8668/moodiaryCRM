import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/widgets/crm_smart_table.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

/// CRM 顶部 Tab 定义（本地基础对象）
class CrmTabDef {
  final String type;
  final String label;

  const CrmTabDef(this.type, this.label);
}

const List<CrmTabDef> kCrmTabs = [
  CrmTabDef('account', '客户'),
  CrmTabDef('contact', '联系人'),
  CrmTabDef('opportunity', '机会/线索'),
  CrmTabDef('contract', '合同'),
];

String crmTypeLabel(String type) {
  const labels = {
    'account': '客户',
    'contact': '联系人',
    'opportunity': '机会/线索',
    'contract': '合同',
  };
  return labels[type] ?? type;
}

IconData crmTypeIcon(String type) {
  switch (type) {
    case 'account':
      return Icons.business_rounded;
    case 'contact':
      return Icons.person_rounded;
    case 'opportunity':
      return Icons.trending_up_rounded;
    case 'contract':
      return Icons.description_rounded;
    default:
      return Icons.folder_rounded;
  }
}

Color crmTypeColor(String type) {
  switch (type) {
    case 'account':
      return Colors.blue.shade400;
    case 'contact':
      return Colors.green.shade400;
    case 'opportunity':
      return Colors.orange.shade400;
    case 'contract':
      return Colors.teal.shade400;
    default:
      return Colors.grey;
  }
}

/// 单个对象 Tab：智能表格（本地数据）+ 搜索/列设置 + 增删改查 + 业务下钻。
class CrmObjectTableTab extends StatefulWidget {
  final String objectType;
  final String title;
  final int reloadToken;

  /// 自定义对象定义（objectType 形如 `custom:<id>` 时传入）
  final LocalCustomObject? customObject;

  const CrmObjectTableTab({
    super.key,
    required this.objectType,
    required this.title,
    this.reloadToken = 0,
    this.customObject,
  });

  @override
  State<CrmObjectTableTab> createState() => _CrmObjectTableTabState();
}

class _CrmObjectTableTabState extends State<CrmObjectTableTab> {
  late Future<List<CrmEntityCache>> _future;
  bool _saving = false;
  String _query = '';
  List<String> _columns = [];

  CrmLocalRepository get _repo => CrmLocalRepository();

  String get _columnPrefKey => 'crmTableColumns_${widget.objectType}';

  bool get _customized =>
      PrefUtil.getValue<bool>(
        'crmTableColumnsCustomized_${widget.objectType}',
      ) ??
      false;

  List<LocalObjectField> get _fields {
    final custom = widget.customObject;
    if (custom != null) {
      return [
        for (final f in custom.fields)
          LocalObjectField(
            f.name,
            f.label,
            type: f.type,
            options: f.options,
          ),
      ];
    }
    return kBaseObjectFields[widget.objectType] ?? const [];
  }

  String get _labelField => kLocalLabelFields[widget.objectType] ?? 'name';

  @override
  void initState() {
    super.initState();
    _columns = PrefUtil.getValue<List<String>>(_columnPrefKey) ?? [];
    _reload();
  }

  @override
  void didUpdateWidget(covariant CrmObjectTableTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _reload();
    }
  }

  void _reload() {
    setState(() => _future = _loadItems());
  }

  // ==================== 数据加载（本地仓储 → 表格视图） ====================

  Future<List<CrmEntityCache>> _loadItems() async {
    final repo = _repo;
    switch (widget.objectType) {
      case 'account':
        return (await repo.listAccounts())
            .map(
              (a) => CrmEntityCache()
                ..id = a.id
                ..twentyId = a.id
                ..entityType = 'account'
                ..name = a.name.isEmpty ? '（未命名客户）' : a.name
                ..setData(accountToDataMap(a))
                ..updatedAt = a.updatedAt,
            )
            .toList();
      case 'contact':
        final contacts = await repo.listContacts();
        final accountNames = await _accountNameMap();
        return contacts
            .map(
              (c) => CrmEntityCache()
                ..id = c.id
                ..twentyId = c.id
                ..entityType = 'contact'
                ..name = c.name.isEmpty ? '（未命名联系人）' : c.name
                ..setData(contactToDataMap(c, accountName: accountNames[c.accountId]))
                ..updatedAt = c.updatedAt,
            )
            .toList();
      case 'opportunity':
        final opps = await repo.listOpportunities();
        final accountNames = await _accountNameMap();
        final contactNames = await _contactNameMap();
        return opps
            .map(
              (o) => CrmEntityCache()
                ..id = o.id
                ..twentyId = o.id
                ..entityType = 'opportunity'
                ..name = o.name.isEmpty ? '（未命名机会）' : o.name
                ..setData(
                  opportunityToDataMap(
                    o,
                    accountName: accountNames[o.accountId],
                    contactName: contactNames[o.contactId],
                  ),
                )
                ..updatedAt = o.updatedAt,
            )
            .toList();
      case 'contract':
        final contracts = await repo.listContracts();
        final accountNames = await _accountNameMap();
        return contracts
            .map(
              (c) => CrmEntityCache()
                ..id = c.id
                ..twentyId = c.id
                ..entityType = 'contract'
                ..name = c.name.isEmpty ? '（未命名合同）' : c.name
                ..setData(contractToDataMap(c, accountName: accountNames[c.accountId]))
                ..updatedAt = c.updatedAt,
            )
            .toList();
      default:
        // 自定义对象
        final objectId = widget.objectType.startsWith('custom:')
            ? widget.objectType.substring(7)
            : widget.objectType;
        return (await repo.listCustomRecords(objectId))
            .map(
              (r) => CrmEntityCache()
                ..id = r.id
                ..twentyId = r.id
                ..entityType = widget.objectType
                ..name = r.label.isEmpty ? '（未命名记录）' : r.label
                ..setData({'name': r.label, ...r.data})
                ..updatedAt = r.updatedAt,
            )
            .toList();
    }
  }

  Future<Map<String?, String>> _accountNameMap() async {
    final map = <String?, String>{};
    for (final a in await _repo.listAccounts()) {
      map[a.id] = a.name;
    }
    return map;
  }

  Future<Map<String?, String>> _contactNameMap() async {
    final map = <String?, String>{};
    for (final c in await _repo.listContacts()) {
      map[c.id] = c.name;
    }
    return map;
  }

  // ==================== 列表/列处理 ====================

  List<String> _allFieldNames(List<CrmEntityCache> items) {
    final names = <String>[_labelField];
    for (final item in items) {
      for (final key in item.data.keys) {
        if (isDisplayField(key) && !names.contains(key)) names.add(key);
      }
    }
    for (final f in _fields) {
      if (!names.contains(f.name)) names.add(f.name);
    }
    return names;
  }

  static bool isDisplayField(String key) {
    if (key == 'id' || key == 'name') return false;
    if (key.endsWith('Id')) return false;
    if (key.startsWith('__')) return false;
    return true;
  }

  static bool isEditableField(LocalObjectField field) {
    if (field.name == 'id') return false;
    if (field.name.endsWith('Id')) return false;
    if (field.type == 'relation') return false;
    if (field.name == 'createdAt' || field.name == 'updatedAt') return false;
    return true;
  }

  List<String> _effectiveColumns(List<String> all) {
    final defaults = _fields.map((f) => f.name).where(all.contains).toList();
    if (_customized && _columns.isNotEmpty) {
      final persisted = _columns.where(all.contains).toList();
      for (final d in defaults) {
        if (!persisted.contains(d)) persisted.add(d);
      }
      return persisted;
    }
    return defaults.isEmpty ? [_labelField] : defaults;
  }

  String _fieldLabel(String name) {
    for (final f in _fields) {
      if (f.name == name) return f.label;
    }
    return name;
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

  Future<void> _persistColumnOrder(List<String> order) async {
    if (order.isEmpty) return;
    setState(() => _columns = List<String>.from(order));
    await PrefUtil.setValue<List<String>>(
      _columnPrefKey,
      List<String>.from(order),
    );
    await PrefUtil.setValue<bool>(
      'crmTableColumnsCustomized_${widget.objectType}',
      true,
    );
  }

  Future<void> _showColumnSettings(List<CrmEntityCache> items) async {
    final all = _allFieldNames(items);
    if (all.length <= 1) {
      toast.info(message: '该对象暂无可配置字段');
      return;
    }
    var visible = _effectiveColumns(all);
    var customized = _customized;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final hidden = all.where((f) => !visible.contains(f)).toList();
          return AlertDialog(
            title: const Text('列设置（显示 / 顺序）'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '拖动调整顺序，勾选控制显示',
                    style: Theme.of(context).textTheme.bodySmall,
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
                      style: Theme.of(context).textTheme.bodySmall,
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
                  visible = _fields.map((f) => f.name).where(all.contains).toList();
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

  // ==================== CRUD（本地仓储） ====================

  Future<void> _create(List<CrmEntityCache> items) async {
    final fields = _fields
        .where(isEditableField)
        .where((f) => f.name != _labelField || true)
        .toList();
    final controllers = <String, TextEditingController>{
      for (final f in fields) f.name: TextEditingController(),
    };
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
                      controller: controllers[field.name],
                      keyboardType: field.type == 'number'
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : null,
                      decoration: InputDecoration(
                        labelText: _fieldLabel(field.name),
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
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        for (final f in fields)
          if (controllers[f.name]!.text.trim().isNotEmpty)
            f.name: _typedInput(f, controllers[f.name]!.text.trim()),
      };
      await _createEntity(data);
      toast.success(message: '已创建');
      _reload();
    } catch (e) {
      toast.error(message: '创建失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(CrmEntityCache item) async {
    _showDetail(item);
  }

  Future<void> _delete(CrmEntityCache item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('将删除「${item.name}」${widget.title}，此操作不可撤销。'),
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
      await _deleteEntity(item.twentyId);
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
    if (item.data[field] is Map) return; // 复合/关系字段只读
    if (field == _labelField && item.data[field] is! Map) {
      // 允许更新名称
    }
    setState(() => _saving = true);
    try {
      await _updateEntityField(item.twentyId, field, value);
    } catch (e) {
      toast.error(message: '保存失败：$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _reload();
      }
    }
  }

  // ---- 类型化写操作 ----

  Future<void> _createEntity(Map<String, dynamic> data) async {
    final repo = _repo;
    switch (widget.objectType) {
      case 'account':
        await repo.createAccount(
          LocalAccount(
            id: '',
            name: data['name']?.toString() ?? '',
            type: data['type']?.toString() ?? 'company',
            industry: data['industry']?.toString() ?? '',
            level: data['level']?.toString() ?? 'normal',
            source: data['source']?.toString() ?? '',
            phone: data['phone']?.toString() ?? '',
            email: data['email']?.toString() ?? '',
            address: data['address']?.toString() ?? '',
            website: data['website']?.toString() ?? '',
            creditCode: data['creditCode']?.toString() ?? '',
            note: data['note']?.toString() ?? '',
            status: data['status']?.toString() ?? 'active',
          ),
        );
      case 'contact':
        await repo.createContact(
          LocalContact(
            id: '',
            name: data['name']?.toString() ?? '',
            title: data['title']?.toString() ?? '',
            department: data['department']?.toString() ?? '',
            phone: data['phone']?.toString() ?? '',
            email: data['email']?.toString() ?? '',
            wechat: data['wechat']?.toString() ?? '',
            isPrimary: data['isPrimary']?.toString() == 'true',
            isDecisionMaker: data['isDecisionMaker']?.toString() == 'true',
            note: data['note']?.toString() ?? '',
          ),
        );
      case 'opportunity':
        await repo.createOpportunity(
          LocalOpportunity(
            id: '',
            name: data['name']?.toString() ?? '',
            stage: data['stage']?.toString() ?? 'newLead',
            probability: _toInt(data['probability']) ?? 0,
            amount: _toDouble(data['amount']) ?? 0,
            currency: data['currency']?.toString() ?? 'CNY',
            source: data['source']?.toString() ?? '',
            leadContactName: data['leadContactName']?.toString() ?? '',
            leadPhone: data['leadPhone']?.toString() ?? '',
            leadEmail: data['leadEmail']?.toString() ?? '',
            expectedCloseDate: _parseDate(data['expectedCloseDate']),
            actualCloseDate: _parseDate(data['actualCloseDate']),
            lossReason: data['lossReason']?.toString() ?? '',
            note: data['note']?.toString() ?? '',
          ),
        );
      case 'contract':
        await repo.createContract(
          LocalContract(
            id: '',
            contractNo: data['contractNo']?.toString() ?? '',
            name: data['name']?.toString() ?? '',
            status: data['status']?.toString() ?? '',
            totalAmount: _toDouble(data['totalAmount']) ?? 0,
            paidAmount: _toDouble(data['paidAmount']) ?? 0,
            invoicedAmount: _toDouble(data['invoicedAmount']) ?? 0,
            signDate: _parseDate(data['signDate']),
            startDate: _parseDate(data['startDate']),
            endDate: _parseDate(data['endDate']),
            warrantyEndDate: _parseDate(data['warrantyEndDate']),
            note: data['note']?.toString() ?? '',
          ),
        );
      default:
        final objectId = widget.objectType.startsWith('custom:')
            ? widget.objectType.substring(7)
            : widget.objectType;
        await repo.createCustomRecord(
          LocalCustomRecord(
            id: '',
            objectId: objectId,
            label: data['name']?.toString() ?? '',
            data: data,
          ),
        );
    }
  }

  Future<void> _deleteEntity(String id) async {
    final repo = _repo;
    switch (widget.objectType) {
      case 'account':
        await repo.deleteAccount(id);
      case 'contact':
        await repo.deleteContact(id);
      case 'opportunity':
        await repo.deleteOpportunity(id);
      case 'contract':
        await repo.deleteContract(id);
      default:
        await repo.deleteCustomRecord(id);
    }
  }

  Future<void> _updateEntityField(
    String id,
    String field,
    Object? value,
  ) async {
    final repo = _repo;
    switch (widget.objectType) {
      case 'account':
        final a = await repo.getAccount(id);
        if (a == null) return;
        _assign(a, field, value);
        await repo.updateAccount(a);
      case 'contact':
        final c = await repo.getContact(id);
        if (c == null) return;
        _assign(c, field, value);
        await repo.updateContact(c);
      case 'opportunity':
        final o = await repo.getOpportunity(id);
        if (o == null) return;
        _assign(o, field, value);
        await repo.updateOpportunity(o);
      case 'contract':
        final c = await repo.getContract(id);
        if (c == null) return;
        _assign(c, field, value);
        await repo.updateContract(c);
      default:
        final r = await repo.getCustomRecord(id);
        if (r == null) return;
        if (field == 'name') {
          r.label = value?.toString() ?? '';
        } else {
          r.data[field] = value;
        }
        await repo.updateCustomRecord(r);
    }
  }

  void _assign(dynamic entity, String field, Object? value) {
    switch (field) {
      case 'name':
        entity.name = value?.toString() ?? '';
      case 'type':
        entity.type = value?.toString() ?? 'company';
      case 'industry':
        entity.industry = value?.toString() ?? '';
      case 'level':
        entity.level = value?.toString() ?? 'normal';
      case 'source':
        entity.source = value?.toString() ?? '';
      case 'phone':
        entity.phone = value?.toString() ?? '';
      case 'email':
        entity.email = value?.toString() ?? '';
      case 'address':
        entity.address = value?.toString() ?? '';
      case 'website':
        entity.website = value?.toString() ?? '';
      case 'creditCode':
        entity.creditCode = value?.toString() ?? '';
      case 'note':
        entity.note = value?.toString() ?? '';
      case 'status':
        entity.status = value?.toString() ?? '';
      case 'title':
        entity.title = value?.toString() ?? '';
      case 'department':
        entity.department = value?.toString() ?? '';
      case 'wechat':
        entity.wechat = value?.toString() ?? '';
      case 'isPrimary':
        entity.isPrimary = value?.toString() == 'true';
      case 'isDecisionMaker':
        entity.isDecisionMaker = value?.toString() == 'true';
      case 'stage':
        entity.stage = value?.toString() ?? '';
      case 'probability':
        entity.probability = _toInt(value) ?? 0;
      case 'amount':
        entity.amount = _toDouble(value) ?? 0;
      case 'currency':
        entity.currency = value?.toString() ?? 'CNY';
      case 'leadContactName':
        entity.leadContactName = value?.toString() ?? '';
      case 'leadPhone':
        entity.leadPhone = value?.toString() ?? '';
      case 'leadEmail':
        entity.leadEmail = value?.toString() ?? '';
      case 'expectedCloseDate':
        entity.expectedCloseDate = _parseDate(value);
      case 'actualCloseDate':
        entity.actualCloseDate = _parseDate(value);
      case 'lossReason':
        entity.lossReason = value?.toString() ?? '';
      case 'contractNo':
        entity.contractNo = value?.toString() ?? '';
      case 'totalAmount':
        entity.totalAmount = _toDouble(value) ?? 0;
      case 'paidAmount':
        entity.paidAmount = _toDouble(value) ?? 0;
      case 'invoicedAmount':
        entity.invoicedAmount = _toDouble(value) ?? 0;
      case 'signDate':
        entity.signDate = _parseDate(value);
      case 'startDate':
        entity.startDate = _parseDate(value);
      case 'endDate':
        entity.endDate = _parseDate(value);
      case 'warrantyEndDate':
        entity.warrantyEndDate = _parseDate(value);
    }
  }

  Object? _typedInput(LocalObjectField field, String raw) {
    if (field.type == 'number') return num.tryParse(raw) ?? raw;
    return raw;
  }

  int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  // ==================== 详情/下钻 ====================

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
                  '类型：${crmTypeLabel(widget.objectType)}\n'
                  '记录 ID：${item.twentyId}\n'
                  '更新时间：${item.updatedAt.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Text('详情', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
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
                Text('相关日记', style: Theme.of(context).textTheme.titleSmall),
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
                          style: Theme.of(context).textTheme.bodySmall,
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

  // ==================== UI ====================

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
        final fieldNames = _allFieldNames(all);
        final effectiveColumns = _effectiveColumns(fieldNames);
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
                  ' · 双击行查看详情',
                  style: Theme.of(context).textTheme.bodySmall,
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
                          const Text('暂无数据，点击「新增」创建'),
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
}
