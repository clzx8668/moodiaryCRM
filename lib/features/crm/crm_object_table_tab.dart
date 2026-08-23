import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_entity_detail_page.dart';
import 'package:moodiary/features/crm/crm_entity_side_panel.dart';
import 'package:moodiary/features/crm/crm_column_settings_panel.dart';
import 'package:moodiary/features/crm/crm_create_form_panel.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_entity_creator.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/widgets/crm_smart_table.dart';
import 'package:moodiary/persistence/pref.dart';
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
  CrmTabDef('product', '产品'),
  CrmTabDef('quote', '报价'),
  CrmTabDef('paymentPlan', '回款计划'),
  CrmTabDef('payment', '回款'),
  CrmTabDef('invoice', '发票'),
  CrmTabDef('warranty', '质保'),
  CrmTabDef('afterSales', '售后'),
  CrmTabDef('activity', '跟进'),
  CrmTabDef('reminder', '提醒'),
];

String crmTypeLabel(String type) {
  const labels = {
    'account': '客户',
    'contact': '联系人',
    'opportunity': '机会/线索',
    'contract': '合同',
    'product': '产品',
    'quote': '报价',
    'paymentPlan': '回款计划',
    'payment': '回款',
    'invoice': '发票',
    'warranty': '质保',
    'afterSales': '售后',
    'activity': '跟进',
    'reminder': '提醒',
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
    case 'product':
      return Icons.inventory_2_rounded;
    case 'quote':
      return Icons.request_quote_rounded;
    case 'paymentPlan':
      return Icons.account_balance_wallet_rounded;
    case 'payment':
      return Icons.payments_rounded;
    case 'invoice':
      return Icons.receipt_rounded;
    case 'warranty':
      return Icons.verified_rounded;
    case 'afterSales':
      return Icons.support_agent_rounded;
    case 'activity':
      return Icons.history_rounded;
    case 'reminder':
      return Icons.alarm_rounded;
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
    case 'product':
      return Colors.indigo.shade400;
    case 'quote':
      return Colors.amber.shade700;
    case 'paymentPlan':
      return Colors.lightBlue.shade400;
    case 'payment':
      return Colors.red.shade400;
    case 'invoice':
      return Colors.purple.shade400;
    case 'warranty':
      return Colors.cyan.shade400;
    case 'afterSales':
      return Colors.deepOrange.shade400;
    case 'activity':
      return Colors.brown.shade400;
    case 'reminder':
      return Colors.orange.shade800;
    default:
      return Colors.grey;
  }
}

/// 单个对象 Tab：智能表格（本地数据）+ 搜索/列设置 + 增删改查 + 业务下钻。
enum _PanelMode { detail, columns, create }

/// 关联新增上下文：创建成功后把新记录挂到父实体。
class _LinkContext {
  /// 正向：新建记录挂到已存在的父实体
  final String? parentType;
  final String? parentId;

  /// 反向：新建父实体后，把 [backType]/[backId]（当前实体）挂上去
  final String? backType;
  final String? backId;

  final String parentLabel;

  const _LinkContext({
    this.parentType,
    this.parentId,
    this.backType,
    this.backId,
    required this.parentLabel,
  });
}

/// 右侧栏面板栈的一帧：详情 / 列设置 / 新增，逐层压入与弹出。
class _PanelFrame {
  final _PanelMode mode;
  final String objectType;
  final List<LocalObjectField> fields;
  final LocalCustomObject? customObject;

  /// detail 帧对应的记录
  final CrmEntityCache? item;

  /// create 帧的标题（如「联系人」→ 新增联系人）
  final String? title;

  /// create 帧的关联上下文提示（如「关联：客户 XXX」）
  final String? subtitle;

  /// create 帧成功后的自动关联目标
  final _LinkContext? linkContext;

  const _PanelFrame({
    required this.mode,
    required this.objectType,
    required this.fields,
    this.customObject,
    this.item,
    this.title,
    this.subtitle,
    this.linkContext,
  });
}

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
  List<String> _hidden = [];
  List<String> _lastAll = [];
  int _refreshToken = 0;
  final List<_PanelFrame> _panels = [];

  CrmLocalRepository get _repo => CrmLocalRepository();

  _PanelFrame? get _panel => _panels.isEmpty ? null : _panels.last;

  String get _columnPrefKey => 'crmTableColumns_${widget.objectType}';

  String get _hiddenPrefKey => 'crmTableHidden_${widget.objectType}';

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
    _hidden = PrefUtil.getValue<List<String>>(_hiddenPrefKey) ?? [];
    _reload();
  }

  @override
  void didUpdateWidget(covariant CrmObjectTableTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _refreshGrid();
    }
  }

  void _reload() {
    setState(() {
      _future = _loadItems();
    });
  }

  /// 外部数据/列变更后重建网格（pluto_grid 不响应列/行更新，需换 key 重建）。
  void _refreshGrid() {
    setState(() {
      _refreshToken++;
      _future = _loadItems();
    });
  }

  // ==================== 数据加载（本地仓储 → 表格视图） ====================

  Future<List<CrmEntityCache>> _loadItems({
    String? objectType,
  }) async {
    await _ensureNewDefaults();
    final repo = _repo;
    final type = objectType ?? widget.objectType;
    switch (type) {
      case 'account':
        final accounts = await repo.listAccounts();
        final contacts = await repo.listContacts();
        final opps = await repo.listOpportunities();
        final contracts = await repo.listContracts();
        final quotes = await repo.listQuotes();
        // 父侧多值关系：按 accountId 分组，表格列直接显示对象名称列表
        final contactsByAccount = _groupNamesBy(
          contacts,
          (c) => (c as LocalContact).accountId,
          (c) => (c as LocalContact).name,
        );
        final oppsByAccount = _groupNamesBy(
          opps,
          (o) => (o as LocalOpportunity).accountId,
          (o) => (o as LocalOpportunity).name,
        );
        final contractsByAccount = _groupNamesBy(
          contracts,
          (c) => (c as LocalContract).accountId,
          (c) => (c as LocalContract).name,
        );
        final quotesByAccount = _groupNamesBy(
          quotes,
          (q) => (q as LocalQuote).accountId,
          (q) => (q as LocalQuote).quoteNo,
        );
        return accounts
            .map(
              (a) {
                final data = accountToDataMap(a);
                data['contact'] = {
                  'name': joinRelationNames(contactsByAccount[a.id] ?? const []),
                };
                data['opportunity'] = {
                  'name': joinRelationNames(oppsByAccount[a.id] ?? const []),
                };
                data['contract'] = {
                  'name': joinRelationNames(
                    contractsByAccount[a.id] ?? const [],
                  ),
                };
                data['quote'] = {
                  'name': joinRelationNames(quotesByAccount[a.id] ?? const []),
                };
                return CrmEntityCache()
                  ..id = a.id
                  ..twentyId = a.id
                  ..entityType = 'account'
                  ..name = a.name.isEmpty ? '（未命名客户）' : a.name
                  ..setData(data)
                  ..updatedAt = a.updatedAt;
              },
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
      case 'product':
        return (await repo.listProducts())
            .map(
              (p) => CrmEntityCache()
                ..id = p.id
                ..twentyId = p.id
                ..entityType = 'product'
                ..name = p.name.isEmpty ? '（未命名产品）' : p.name
                ..setData(productToDataMap(p))
                ..updatedAt = p.updatedAt,
            )
            .toList();
      case 'quote':
        final quotes = await repo.listQuotes();
        final accountNames = await _accountNameMap();
        final contactNames = await _contactNameMap();
        final oppNames = await _opportunityNameMap();
        return quotes
            .map(
              (q) => CrmEntityCache()
                ..id = q.id
                ..twentyId = q.id
                ..entityType = 'quote'
                ..name = q.quoteNo.isEmpty ? '（未编号报价）' : q.quoteNo
                ..setData(
                  quoteToDataMap(
                    q,
                    accountName: accountNames[q.accountId],
                    contactName: contactNames[q.contactId],
                    opportunityName: oppNames[q.opportunityId],
                  ),
                )
                ..updatedAt = q.updatedAt,
            )
            .toList();
      case 'paymentPlan':
        final plans = await repo.listPaymentPlans();
        final contractNames = await _contractNameMap();
        return plans
            .map(
              (p) => CrmEntityCache()
                ..id = p.id
                ..twentyId = p.id
                ..entityType = 'paymentPlan'
                ..name = p.planName.isEmpty ? '（未命名期次）' : p.planName
                ..setData(
                  paymentPlanToDataMap(
                    p,
                    contractName: contractNames[p.contractId],
                  ),
                )
                ..updatedAt = p.planDate,
            )
            .toList();
      case 'payment':
        final payments = await repo.listPayments();
        final contractNames = await _contractNameMap();
        final planNames = await _planNameMap();
        return payments
            .map(
              (p) => CrmEntityCache()
                ..id = p.id
                ..twentyId = p.id
                ..entityType = 'payment'
                ..name =
                    '¥${p.amount.toStringAsFixed(2)} · ${p.paymentDate.toLocal().toString().substring(0, 10)}'
                ..setData(
                  paymentToDataMap(
                    p,
                    contractName: contractNames[p.contractId],
                    planName: planNames[p.planId],
                  ),
                )
                ..updatedAt = p.paymentDate,
            )
            .toList();
      case 'invoice':
        final invoices = await repo.listInvoices();
        final contractNames = await _contractNameMap();
        return invoices
            .map(
              (i) => CrmEntityCache()
                ..id = i.id
                ..twentyId = i.id
                ..entityType = 'invoice'
                ..name = i.invoiceNo.isEmpty ? '（未编号发票）' : i.invoiceNo
                ..setData(
                  invoiceToDataMap(i, contractName: contractNames[i.contractId]),
                )
                ..updatedAt = i.createdAt,
            )
            .toList();
      case 'warranty':
        final warranties = await repo.listWarranties();
        final contractNames = await _contractNameMap();
        final productNames = await _productNameMap();
        return warranties
            .map(
              (w) => CrmEntityCache()
                ..id = w.id
                ..twentyId = w.id
                ..entityType = 'warranty'
                ..name = w.serialNo.isEmpty ? '（质保）' : w.serialNo
                ..setData(
                  warrantyToDataMap(
                    w,
                    contractName: contractNames[w.contractId],
                    productName: productNames[w.productId],
                  ),
                )
                ..updatedAt = w.endDate,
            )
            .toList();
      case 'afterSales':
        final tickets = await repo.listAfterSales();
        final accountNames = await _accountNameMap();
        final contactNames = await _contactNameMap();
        final contractNames = await _contractNameMap();
        return tickets
            .map(
              (t) => CrmEntityCache()
                ..id = t.id
                ..twentyId = t.id
                ..entityType = 'afterSales'
                ..name = t.ticketNo.isEmpty ? '（未编号工单）' : t.ticketNo
                ..setData(
                  afterSalesToDataMap(
                    t,
                    accountName: accountNames[t.accountId],
                    contactName: contactNames[t.contactId],
                    contractName: contractNames[t.contractId],
                  ),
                )
                ..updatedAt = t.updatedAt,
            )
            .toList();
      case 'activity':
        return (await repo.listActivities())
            .map(
              (a) => CrmEntityCache()
                ..id = a.id
                ..twentyId = a.id
                ..entityType = 'activity'
                ..name = a.subject.isEmpty ? '（跟进）' : a.subject
                ..setData(activityToDataMap(a))
                ..updatedAt = a.createdAt,
            )
            .toList();
      case 'reminder':
        return (await repo.listReminders(includeCompleted: true))
            .map(
              (r) => CrmEntityCache()
                ..id = r.id
                ..twentyId = r.id
                ..entityType = 'reminder'
                ..name = r.title.isEmpty ? '（提醒）' : r.title
                ..setData(reminderToDataMap(r))
                ..updatedAt = r.createdAt,
            )
            .toList();
      default:
        // 自定义对象
        final objectId = type.startsWith('custom:') ? type.substring(7) : type;
        final records = await repo.listCustomRecords(objectId);
        return records
            .map(
              (r) => CrmEntityCache()
                ..id = r.id
                ..twentyId = r.id
                ..entityType = type
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

  /// 按外键 id 分组记录，值为展示名称列表（父侧多值关系列用）。
  Map<String, List<String>> _groupNamesBy(
    Iterable records,
    String? Function(dynamic) idOf,
    String Function(dynamic) nameOf,
  ) {
    final map = <String, List<String>>{};
    for (final record in records) {
      final id = idOf(record);
      if (id == null || id.isEmpty) continue;
      map.putIfAbsent(id, () => []).add(nameOf(record));
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

  Future<Map<String?, String>> _opportunityNameMap() async {
    final map = <String?, String>{};
    for (final o in await _repo.listOpportunities()) {
      map[o.id] = o.name;
    }
    return map;
  }

  Future<Map<String?, String>> _contractNameMap() async {
    final map = <String?, String>{};
    for (final c in await _repo.listContracts()) {
      map[c.id] = c.name;
    }
    return map;
  }

  Future<Map<String?, String>> _planNameMap() async {
    final map = <String?, String>{};
    for (final p in await _repo.listPaymentPlans()) {
      map[p.id] = p.planName;
    }
    return map;
  }

  Future<Map<String?, String>> _productNameMap() async {
    final map = <String?, String>{};
    for (final p in await _repo.listProducts()) {
      map[p.id] = p.name;
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

  List<String> _effectiveColumns(List<String> all) {
    final defaults = _fields.map((f) => f.name).where(all.contains).toList();
    if (_customized && _columns.isNotEmpty) {
      return _columns.where(all.contains).toList();
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
    await PrefUtil.setValue<List<String>>(
      _columnPrefKey,
      List<String>.from(order),
    );
    await PrefUtil.setValue<bool>(
      'crmTableColumnsCustomized_${widget.objectType}',
      true,
    );
    if (mounted) {
      setState(() => _columns = List<String>.from(order));
    }
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
          final hiddenChips = all.where((f) => !visible.contains(f)).toList();
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
                      // 关闭默认右侧拖拽把手，避免与复选框重叠（左侧已自定义拖拽把手）
                      buildDefaultDragHandles: false,
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
                  if (hiddenChips.isNotEmpty) ...[
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
                        for (final field in hiddenChips)
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
      // 先落盘再刷新，避免重建时读取到旧的自定义标记
      await PrefUtil.setValue<List<String>>(_columnPrefKey, visible);
      final hiddenList = all.where((f) => !visible.contains(f)).toList();
      await PrefUtil.setValue<List<String>>(
        _hiddenPrefKey,
        hiddenList,
      );
      await PrefUtil.setValue<bool>(
        'crmTableColumnsCustomized_${widget.objectType}',
        customized,
      );
      if (mounted) {
        setState(() {
          _columns = visible;
          _hidden = hiddenList;
          _refreshToken++;
        });
      }
    }
  }

  // ==================== CRUD（本地仓储） ====================

  void _edit(CrmEntityCache item) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    if (desktop) {
      setState(() {
        _panels.add(
          _PanelFrame(
            mode: _PanelMode.detail,
            objectType: widget.objectType,
            fields: _fields,
            customObject: widget.customObject,
            item: item,
          ),
        );
      });
    } else {
      Get.to(
        () => CrmEntityDetailPage(
          objectType: widget.objectType,
          item: item,
          fields: _fields,
        ),
      );
    }
  }

  /// 打开目标对象（下钻）详情：从面板栈压入新的一层，返回时逐层弹出。
  Future<void> _openRelatedDetail(String targetType, String targetId) async {
    try {
      final items = await _loadItems(objectType: targetType);
      CrmEntityCache? found;
      for (final item in items) {
        if (item.twentyId == targetId) {
          found = item;
          break;
        }
      }
      if (found == null || !mounted) return;
      setState(() {
        _panels.add(
          _PanelFrame(
            mode: _PanelMode.detail,
            objectType: targetType,
            fields: kBaseObjectFields[targetType] ?? const [],
            item: found,
          ),
        );
      });
    } catch (e) {
      toast.error(message: '打开失败：$e');
    }
  }

  void _openColumns(List<CrmEntityCache> items) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    if (desktop) {
      setState(() {
        _panels.add(
          _PanelFrame(
            mode: _PanelMode.columns,
            objectType: widget.objectType,
            fields: _fields,
            customObject: widget.customObject,
          ),
        );
      });
    } else {
      _showColumnSettings(items);
    }
  }

  /// 打开「新增」侧栏帧；带 [linkContext] 时创建成功自动关联父实体。
  void _openCreateFor({
    required String objectType,
    required String title,
    LocalCustomObject? customObject,
    _LinkContext? linkContext,
    String? subtitle,
  }) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final fields =
        customObject != null
            ? [
                for (final f in customObject.fields)
                  LocalObjectField(
                    f.name,
                    f.label,
                    type: f.type,
                    options: f.options,
                  ),
              ]
            : kBaseObjectFields[objectType] ?? const [];
    if (desktop) {
      setState(() {
        _panels.add(
          _PanelFrame(
            mode: _PanelMode.create,
            objectType: objectType,
            fields: fields,
            customObject: customObject,
            title: title,
            subtitle: subtitle,
            linkContext: linkContext,
          ),
        );
      });
    } else {
      Get.to(
        () => CrmCreatePage(
          objectType: objectType,
          title: title,
          fields: fields,
          contextLabel: subtitle,
          onCreate: (data) => _createFromPanel(
            data,
            objectType: objectType,
            linkContext: linkContext,
          ),
        ),
      );
    }
  }

  /// 关闭最上层面板（弹出），逐层返回；refresh 时刷新网格。
  void _closeTopPanel({bool refresh = false}) {
    if (!mounted) return;
    setState(() {
      if (_panels.isNotEmpty) _panels.removeLast();
    });
    if (refresh) _refreshGrid();
  }

  /// 点击面板外：等待失焦自动提交完成后，弹出最上层面板并刷新网格。
  Future<void> _closeTopAndRefresh() async {
    // 给字段失焦提交留出执行时间（DB 写入为异步）
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() {
      if (_panels.isNotEmpty) _panels.removeLast();
    });
    _refreshGrid();
  }

  Future<void> _saveColumns(List<String> visible, bool customized) async {
    final hiddenList = _lastAll.where((f) => !visible.contains(f)).toList();
    await PrefUtil.setValue<List<String>>(_columnPrefKey, visible);
    await PrefUtil.setValue<List<String>>(_hiddenPrefKey, hiddenList);
    await PrefUtil.setValue<bool>(
      'crmTableColumnsCustomized_${widget.objectType}',
      customized,
    );
    if (mounted) {
      setState(() {
        _columns = visible;
        _hidden = hiddenList;
        if (_panels.isNotEmpty && _panels.last.mode == _PanelMode.columns) {
          _panels.removeLast();
        }
        _refreshToken++;
      });
    }
  }

  /// 新增帧创建成功：可选自动关联父实体（关联新增流程）。
  Future<void> _createFromPanel(
    Map<String, dynamic> data, {
    String? objectType,
    _LinkContext? linkContext,
  }) async {
    final frame = _panel;
    final type = objectType ?? frame?.objectType ?? widget.objectType;
    final ctx = linkContext ?? frame?.linkContext;
    final newId = await createCrmEntity(
      repo: _repo,
      objectType: type,
      data: data,
    );
    if (newId != null && ctx != null) {
      if (ctx.backType != null && ctx.backId != null) {
        // 反向：新建父实体，把当前实体挂上去
        await CrmEntityLinker.link(
          repo: _repo,
          parentType: type,
          parentId: newId,
          targetType: ctx.backType!,
          targetId: ctx.backId!,
        );
        toast.success(message: '已创建并关联「${ctx.parentLabel}」');
      } else if (ctx.parentType != null && ctx.parentId != null) {
        // 正向：新记录挂到已存在父实体
        await CrmEntityLinker.link(
          repo: _repo,
          parentType: ctx.parentType!,
          parentId: ctx.parentId!,
          targetType: type,
          targetId: newId,
        );
        toast.success(message: '已创建并关联「${ctx.parentLabel}」');
      }
    }
  }

  /// 客户/机会/合同详情内「关联已有记录」：原位下拉选择后挂到当前实体。
  Future<void> _linkToCurrentEntity(
    String targetType,
    String targetId,
  ) async {
    final frame = _panel;
    final item = frame?.item;
    if (frame == null || item == null) return;
    try {
      await CrmEntityLinker.link(
        repo: _repo,
        parentType: frame.objectType,
        parentId: item.twentyId,
        targetType: targetType,
        targetId: targetId,
      );
      toast.success(message: '已关联${crmTypeLabel(targetType)}');
      _refreshGrid();
    } catch (e) {
      toast.error(message: '关联失败：$e');
    }
  }

  /// 客户/机会/合同详情内「新增并关联」：压入新增帧，创建后自动关联并逐层返回。
  void _createRelatedFromPanel(String targetType) {
    final frame = _panel;
    final item = frame?.item;
    if (frame == null || item == null) return;
    _openCreateFor(
      objectType: targetType,
      title: crmTypeLabel(targetType),
      linkContext: _LinkContext(
        parentType: frame.objectType,
        parentId: item.twentyId,
        parentLabel: item.name,
      ),
      subtitle: '关联：${item.name}',
    );
  }

  /// 子侧关系字段「新增并关联」：新建父实体，把当前实体挂上去。
  void _createBackRelatedFromPanel(String targetType) {
    final frame = _panel;
    final item = frame?.item;
    if (frame == null || item == null) return;
    _openCreateFor(
      objectType: targetType,
      title: crmTypeLabel(targetType),
      linkContext: _LinkContext(
        backType: frame.objectType,
        backId: item.twentyId,
        parentLabel: item.name,
      ),
      subtitle: '挂到：${item.name}',
    );
  }

  /// 追加「用户从未决定过」的新默认字段（显式隐藏的除外）：
  /// 保证 Twenty 新增字段自动出现，同时尊重用户显式取消勾选。
  Future<void> _ensureNewDefaults() async {
    if (!_customized) return;
    final hidden = _hidden.toSet();
    var changed = false;
    for (final d in _fields.map((f) => f.name)) {
      if (!_columns.contains(d) && !hidden.contains(d)) {
        _columns.add(d);
        changed = true;
      }
    }
    if (changed) {
      await PrefUtil.setValue<List<String>>(_columnPrefKey, _columns);
    }
  }

  Future<void> _deleteSelected() async {
    final frame = _panel;
    final item = frame?.item;
    if (frame == null || item == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('将删除「${item.name}」，此操作不可撤销。'),
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
      await CrmEntityDeleter.delete(frame.objectType, item.twentyId);
      toast.success(message: '已删除');
      _closeTopPanel(refresh: true);
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

  Future<void> _updateEntityField(
    String id,
    String field,
    Object? value,
  ) async {
    await CrmEntityFieldUpdater.update(
      objectType: widget.objectType,
      id: id,
      field: field,
      value: value,
    );
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
        _lastAll = fieldNames;
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
                    onPressed: () => _openColumns(all),
                    icon: const Icon(Icons.view_column_outlined),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: _refreshGrid,
                    icon: const Icon(Icons.refresh_rounded),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: items.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              crmTypeIcon(widget.objectType),
                                              size: 40,
                                              color: crmTypeColor(
                                                widget.objectType,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              '暂无数据，点击下方「新增」创建',
                                            ),
                                          ],
                                        ),
                                      )
                                    : CrmSmartTable(
                                        key: ValueKey(
                                          '${widget.objectType}-grid-$_refreshToken',
                                        ),
                                        items: items,
                                        fields: effectiveColumns,
                                        selectOptions: {
                                          for (final f in _fields)
                                            if (f.type == 'select' ||
                                                (f.type == 'currency' &&
                                                    f.name == 'currency'))
                                              f.name: f.type == 'currency'
                                                  ? [...kCurrencies]
                                                  : f.options,
                                        },
                                        onCellChanged: _updateCell,
                                        onOpen: _edit,
                                        onColumnsReordered:
                                            _persistColumnOrder,
                                      ),
                              ),
                              if (_panels.isNotEmpty &&
                                  MediaQuery.sizeOf(context).width >= 900)
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _closeTopAndRefresh,
                                    child: const ColoredBox(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        _buildAddRow(),
                      ],
                    ),
                  ),
                  if (_panels.isNotEmpty &&
                      MediaQuery.sizeOf(context).width >= 900) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 420,
                      child: Stack(
                        children: [
                          for (var i = 0; i < _panels.length; i++)
                            Positioned.fill(
                              child: Offstage(
                                offstage: i != _panels.length - 1,
                                child: _buildPanelFrame(_panels[i]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 列表内容末尾的「＋ 新增某某」内联操作行（Twenty 风格，替代工具栏加号）。
  Widget _buildAddRow() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: _saving
            ? null
            : () => _openCreateFor(
                objectType: widget.objectType,
                title: widget.title,
                customObject: widget.customObject,
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '新增${widget.title}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 渲染面板栈中的一帧（详情 / 列设置 / 新增）。
  Widget _buildPanelFrame(_PanelFrame frame) {
    switch (frame.mode) {
      case _PanelMode.detail:
        return CrmEntitySidePanel(
          objectType: frame.objectType,
          item: frame.item!,
          fields: frame.fields,
          onClose: _closeTopAndRefresh,
          onChanged: _refreshGrid,
          onDelete: _deleteSelected,
          refreshTick: _refreshToken,
          onLinkRelated: _linkToCurrentEntity,
          onCreateRelated: _createRelatedFromPanel,
          onCreateBackRelated: _createBackRelatedFromPanel,
          onOpenRelated: _openRelatedDetail,
        );
      case _PanelMode.columns:
        return CrmColumnSettingsPanel(
          fields: frame.fields,
          allFieldNames: _lastAll,
          visible: _effectiveColumns(_lastAll),
          customized: _customized,
          onSave: _saveColumns,
          onClose: () => _closeTopPanel(refresh: false),
        );
      case _PanelMode.create:
        return CrmCreateFormPanel(
          objectType: frame.objectType,
          title: frame.title ?? widget.title,
          contextLabel: frame.subtitle,
          fields: frame.fields,
          onCreate: _createFromPanel,
          onClose: () => _closeTopPanel(refresh: true),
        );
    }
  }
}
