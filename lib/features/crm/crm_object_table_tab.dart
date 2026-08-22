import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_entity_detail_page.dart';
import 'package:moodiary/features/crm/crm_entity_side_panel.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_ai_assist.dart';
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
  CrmEntityCache? _selected;

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
    setState(() {
      _future = _loadItems();
    });
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
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _aiFill(controllers, fields),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('AI 填充（粘贴文本提取）'),
                  ),
                ),
                const SizedBox(height: 4),
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
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    if (desktop) {
      setState(() => _selected = item);
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

  Future<void> _aiFill(
    Map<String, TextEditingController> controllers,
    List<LocalObjectField> fields,
  ) async {
    final input = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI 填充'),
        content: TextField(
          controller: input,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '粘贴客户/机会描述文本，自动提取名称、金额、电话、邮箱、日期、阶段等',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final extraction = CrmAiAssist.extractFromText(input.text);
              _applyExtraction(extraction, controllers, fields);
              Navigator.pop(dialogContext);
            },
            child: const Text('提取并填充'),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  void _applyExtraction(
    CrmAiExtraction extraction,
    Map<String, TextEditingController> controllers,
    List<LocalObjectField> fields,
  ) {
    void setField(String name, String? value) {
      if (value != null && value.isNotEmpty && controllers.containsKey(name)) {
        controllers[name]!.text = value;
      }
    }

    setField('name', extraction.name);
    if (extraction.amount != null) {
      final amountText = extraction.amount!.toStringAsFixed(2);
      setField('amount', amountText);
      setField('planAmount', amountText);
      setField('price', amountText);
    }
    setField('phone', extraction.phone);
    setField('email', extraction.email);
    if (extraction.closeDate != null) {
      final d = extraction.closeDate!;
      final dateText = '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      setField('expectedCloseDate', dateText);
      setField('closeDate', dateText);
      setField('issueDate', dateText);
    }
    setField('stage', extraction.stage);
    setField('note', extraction.note);
    toast.success(message: '已填充，可修改后创建');
  }

  Future<void> _deleteSelected() async {
    final item = _selected;
    if (item == null) return;
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
      await CrmEntityDeleter.delete(widget.objectType, item.twentyId);
      toast.success(message: '已删除');
      setState(() => _selected = null);
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
      case 'product':
        await repo.createProduct(
          LocalProduct(
            id: '',
            name: data['name']?.toString() ?? '',
            sku: data['sku']?.toString() ?? '',
            type: data['type']?.toString() ?? 'product',
            unit: data['unit']?.toString() ?? '',
            price: _toDouble(data['price']) ?? 0,
            cost: _toDouble(data['cost']) ?? 0,
            warrantyMonths: _toInt(data['warrantyMonths']) ?? 0,
            isActive: data['isActive']?.toString() != 'false',
            note: data['note']?.toString() ?? '',
          ),
        );
      case 'quote':
        await repo.createQuote(
          LocalQuote(
            id: '',
            status: data['status']?.toString() ?? 'draft',
            totalAmount: _toDouble(data['totalAmount']) ?? 0,
            discountAmount: _toDouble(data['discountAmount']) ?? 0,
            validUntil: _parseDate(data['validUntil']),
            note: data['note']?.toString() ?? '',
          ),
        );
      case 'paymentPlan':
        await repo.createPaymentPlan(
          LocalPaymentPlan(
            id: '',
            contractId: '',
            planName: data['planName']?.toString() ?? '',
            planAmount: _toDouble(data['planAmount']) ?? 0,
            planDate: _parseDate(data['planDate']) ?? DateTime.now(),
            status: data['status']?.toString() ?? 'pending',
          ),
        );
      case 'payment':
        await repo.createPayment(
          LocalPayment(
            id: '',
            contractId: '',
            amount: _toDouble(data['amount']) ?? 0,
            paymentDate: _parseDate(data['paymentDate']) ?? DateTime.now(),
            method: data['method']?.toString() ?? 'transfer',
            note: data['note']?.toString() ?? '',
          ),
        );
      case 'invoice':
        await repo.createInvoice(
          LocalInvoice(
            id: '',
            contractId: '',
            invoiceNo: data['invoiceNo']?.toString() ?? '',
            type: data['type']?.toString() ?? 'vat_normal',
            amount: _toDouble(data['amount']) ?? 0,
            taxRate: _toDouble(data['taxRate']) ?? 0.13,
            issueDate: _parseDate(data['issueDate']),
            status: data['status']?.toString() ?? 'pending',
            receiverName: data['receiverName']?.toString() ?? '',
            note: data['note']?.toString() ?? '',
          ),
        );
      case 'warranty':
        await repo.createWarranty(
          LocalWarranty(
            id: '',
            contractId: '',
            serialNo: data['serialNo']?.toString() ?? '',
            startDate: _parseDate(data['startDate']) ?? DateTime.now(),
            endDate: _parseDate(data['endDate']) ?? DateTime.now(),
            status: data['status']?.toString() ?? 'active',
            note: data['note']?.toString() ?? '',
          ),
        );
      case 'afterSales':
        await repo.createAfterSales(
          LocalAfterSales(
            id: '',
            subject: data['subject']?.toString() ?? '',
            type: data['type']?.toString() ?? 'other',
            priority: data['priority']?.toString() ?? 'medium',
            status: data['status']?.toString() ?? 'open',
            description: data['description']?.toString() ?? '',
            resolution: data['resolution']?.toString() ?? '',
            note: data['note']?.toString() ?? '',
          ),
        );
      case 'activity':
        await repo.createActivity(
          LocalActivity(
            id: '',
            subject: data['subject']?.toString() ?? '',
            type: data['type']?.toString() ?? 'note',
            direction: data['direction']?.toString(),
            status: data['status']?.toString() ?? 'completed',
            scheduledAt: _parseDate(data['scheduledAt']),
            content: data['content']?.toString() ?? '',
          ),
        );
      case 'reminder':
        await repo.createReminder(
          LocalReminder(
            id: '',
            title: data['title']?.toString() ?? '',
            type: data['type']?.toString() ?? 'custom',
            remindAt: _parseDate(data['remindAt']) ?? DateTime.now(),
            isCompleted: data['isCompleted']?.toString() == 'true',
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
              child: Row(
                children: [
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
                  if (_selected != null &&
                      MediaQuery.sizeOf(context).width >= 900) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 420,
                      child: CrmEntitySidePanel(
                        objectType: widget.objectType,
                        item: _selected!,
                        fields: _fields,
                        onClose: () => setState(() => _selected = null),
                        onChanged: _reload,
                        onDelete: _deleteSelected,
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
}
