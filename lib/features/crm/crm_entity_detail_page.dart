import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 实体详情页：字段展示 + 业务下钻 + 相关日记 + 报价明细/转合同。
class CrmEntityDetailPage extends StatefulWidget {
  final String objectType;
  final CrmEntityCache item;
  final List<LocalObjectField> fields;

  const CrmEntityDetailPage({
    super.key,
    required this.objectType,
    required this.item,
    required this.fields,
  });

  @override
  State<CrmEntityDetailPage> createState() => _CrmEntityDetailPageState();
}

class _CrmEntityDetailPageState extends State<CrmEntityDetailPage> {
  CrmLocalRepository get _repo => CrmLocalRepository();

  String get _title => '${crmTypeLabel(widget.objectType)} · ${widget.item.name}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: '新增跟进',
            icon: const Icon(Icons.add_comment_rounded),
            onPressed: () => _showQuickActivity(context),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteEntity(context),
          ),
          if (widget.objectType == 'quote')
            TextButton.icon(
              onPressed: () => _quoteToContract(context),
              icon: const Icon(Icons.description_rounded, size: 18),
              label: const Text('转合同'),
            ),
          if (widget.objectType == 'quote')
            TextButton.icon(
              onPressed: _showQuoteItemEditor,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('明细'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTags(),
          const SizedBox(height: 16),
          _buildFields(),
          const SizedBox(height: 16),
          if (widget.objectType == 'account') _buildAccountDrilldown(),
          if (widget.objectType == 'opportunity') _buildOpportunityDrilldown(),
          if (widget.objectType == 'contract') _buildContractItems(),
          if (widget.objectType == 'contract') _buildContractFinance(),
          if (widget.objectType == 'contract') _buildContractWarranties(),
          if (widget.objectType == 'quote') _buildQuoteItems(),
          const SizedBox(height: 16),
          _buildTimeline(),
        ],
      ),
    );
  }

  // ==================== 标签 ====================

  Widget _buildTags() {
    return FutureBuilder<List<LocalTag>>(
      future: _repo.tagsForEntity(widget.objectType, widget.item.twentyId),
      builder: (context, snapshot) {
        final tags = snapshot.data ?? const <LocalTag>[];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('标签', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in tags)
                      InputChip(
                        label: Text(tag.name),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => _removeTag(tag.name),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('添加'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _addTag(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addTag(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '标签名',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    final tags = await _repo.tagsForEntity(widget.objectType, widget.item.twentyId);
    await _repo.setEntityTags(
      widget.objectType,
      widget.item.twentyId,
      [...tags.map((t) => t.name), controller.text.trim()],
    );
    if (mounted) setState(() {});
  }

  Future<void> _removeTag(String name) async {
    final tags = await _repo.tagsForEntity(widget.objectType, widget.item.twentyId);
    await _repo.setEntityTags(
      widget.objectType,
      widget.item.twentyId,
      tags.map((t) => t.name).where((n) => n != name).toList(),
    );
    if (mounted) setState(() {});
  }

  // ==================== 快速跟进 ====================

  Future<void> _showQuickActivity(BuildContext context) async {
    final subject = TextEditingController();
    var type = 'call';
    var status = 'completed';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('新增跟进'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(
                    labelText: '主题',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'call', child: Text('电话')),
                    DropdownMenuItem(value: 'meeting', child: Text('会议')),
                    DropdownMenuItem(value: 'email', child: Text('邮件')),
                    DropdownMenuItem(value: 'wechat', child: Text('微信')),
                    DropdownMenuItem(value: 'visit', child: Text('拜访')),
                    DropdownMenuItem(value: 'task', child: Text('任务')),
                    DropdownMenuItem(value: 'note', child: Text('备注')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'call'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'planned', child: Text('计划')),
                    DropdownMenuItem(value: 'completed', child: Text('已完成')),
                    DropdownMenuItem(value: 'canceled', child: Text('已取消')),
                  ],
                  onChanged: (v) => setDialogState(() => status = v ?? 'completed'),
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
    if (ok != true || subject.text.trim().isEmpty) return;
    await _repo.createActivity(
      LocalActivity(
        id: '',
        type: type,
        relatedType: widget.objectType,
        relatedId: widget.item.twentyId,
        subject: subject.text.trim(),
        status: status,
        completedAt: status == 'completed' ? DateTime.now() : null,
      ),
    );
    if (mounted) setState(() {});
  }

  // ==================== 字段 ====================

  Widget _buildFields() {
    final data = widget.item.data;
    final rows = <Widget>[];
    for (final field in widget.fields) {
      if (field.type == 'relation') continue;
      final value = _format(data[field.name]);
      if (value.isEmpty && field.name != widget.item.name) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  field.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
              Expanded(child: SelectableText(value)),
            ],
          ),
        ),
      );
    }
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('字段', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ...rows,
          ],
        ),
      ),
    );
  }

  String _format(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return value['name']?.toString() ?? value.toString();
    }
    return value.toString();
  }

  // ==================== 客户下钻 ====================

  Widget _buildAccountDrilldown() {
    return FutureBuilder<List<Object>>(
      future: () async {
        final id = widget.item.twentyId;
        final contacts = await _repo.contactsOfAccount(id);
        final opps = (await _repo.listOpportunities())
            .where((o) => o.accountId == id)
            .toList();
        final contracts = (await _repo.listContracts())
            .where((c) => c.accountId == id)
            .toList();
        return <Object>[...contacts, ...opps, ...contracts];
      }(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '关联业务（${items.length}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Text('暂无联系人/机会/合同')
                else
                  for (final item in items.take(50))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item is LocalContact
                            ? Icons.person_outline_rounded
                            : item is LocalOpportunity
                            ? Icons.trending_up_rounded
                            : Icons.description_outlined,
                        size: 18,
                      ),
                      title: Text(
                        item is LocalContact
                            ? item.name
                            : item is LocalOpportunity
                            ? item.name
                            : (item as LocalContract).name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item is LocalContact
                            ? '联系人 · ${item.title}'
                            : item is LocalOpportunity
                            ? '机会 · ${item.stage}'
                            : '合同 · ${(item as LocalContract).status}',
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpportunityDrilldown() {
    return FutureBuilder<List<Object>>(
      future: () async {
        final id = widget.item.twentyId;
        final contracts = (await _repo.listContracts())
            .where((c) => c.opportunityId == id)
            .toList();
        final quotes = (await _repo.listQuotes())
            .where((q) => q.opportunityId == id)
            .toList();
        return <Object>[...contracts, ...quotes];
      }(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '关联报价/合同（${items.length}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Text('暂无报价/合同')
                else
                  for (final item in items.take(30))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item is LocalQuote
                            ? Icons.request_quote_outlined
                            : Icons.description_outlined,
                        size: 18,
                      ),
                      title: Text(
                        item is LocalQuote
                            ? '${item.quoteNo} · ${item.status}'
                            : (item as LocalContract).name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== 报价/合同明细 ====================

  Widget _buildQuoteItems() {
    return FutureBuilder<List<LocalQuoteItem>>(
      future: _repo.quoteItems(widget.item.twentyId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        final total = items.fold<double>(0, (s, i) => s + i.amount);
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '报价明细（${items.length} · 合计 ¥${total.toStringAsFixed(2)}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Text('暂无明细，点击右上「明细」添加')
                else
                  for (final item in items)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                        '×${item.quantity} @ ¥${item.unitPrice.toStringAsFixed(2)}'
                        '${item.discount < 1 ? '（${(item.discount * 100).toStringAsFixed(0)}%）' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('¥${item.amount.toStringAsFixed(2)}'),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () async {
                              await _repo.removeQuoteItem(item.id);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContractItems() {
    return FutureBuilder<List<LocalContractItem>>(
      future: _repo.contractItems(widget.item.twentyId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '合同明细（${items.length}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Text('暂无明细（报价转合同自动生成）')
                else
                  for (final item in items)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                        '×${item.quantity} @ ¥${item.unitPrice.toStringAsFixed(2)}'
                        '${item.warrantyMonths > 0 ? ' · 质保 ${item.warrantyMonths} 月' : ''}',
                      ),
                      trailing: Text('¥${item.amount.toStringAsFixed(2)}'),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContractFinance() {
    return FutureBuilder<List<Object>>(
      future: () async {
        final id = widget.item.twentyId;
        final plans = await _repo.listPaymentPlans(contractId: id);
        final payments = await _repo.listPayments(contractId: id);
        final invoices = await _repo.listInvoices(contractId: id);
        return <Object>[...plans, ...payments, ...invoices];
      }(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        final plans = items.whereType<LocalPaymentPlan>().toList();
        final payments = items.whereType<LocalPayment>().toList();
        final invoices = items.whereType<LocalInvoice>().toList();
        final paid = payments.fold<double>(0, (s, p) => s + p.amount);
        final invoiced = invoices.fold<double>(0, (s, i) => s + i.amount);
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '财务（已回款 ¥${paid.toStringAsFixed(2)} · 已开票 ¥${invoiced.toStringAsFixed(2)}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (plans.isNotEmpty) ...[
                  Text(
                    '回款计划',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  for (final plan in plans)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(plan.planName),
                      subtitle: Text(
                        '¥${plan.planAmount.toStringAsFixed(2)}'
                        ' · 已收 ¥${plan.paidAmount.toStringAsFixed(2)}'
                        ' · ${plan.status}',
                      ),
                    ),
                ],
                if (payments.isNotEmpty) ...[
                  Text(
                    '回款记录',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  for (final payment in payments)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '¥${payment.amount.toStringAsFixed(2)} · ${payment.paymentDate.toLocal().toString().substring(0, 10)}',
                      ),
                      subtitle: Text(payment.method),
                    ),
                ],
                if (invoices.isNotEmpty) ...[
                  Text(
                    '发票',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  for (final invoice in invoices)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${invoice.invoiceNo.isEmpty ? '（未编号）' : invoice.invoiceNo} · ¥${invoice.amount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text('${invoice.type} · ${invoice.status}'),
                    ),
                ],
                if (items.isEmpty) const Text('暂无财务记录'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContractWarranties() {
    return FutureBuilder<List<LocalWarranty>>(
      future: _repo.listWarranties(contractId: widget.item.twentyId),
      builder: (context, snapshot) {
        final warranties = snapshot.data ?? const [];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '质保（${warranties.length}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (warranties.isEmpty)
                  const Text('暂无质保')
                else
                  for (final warranty in warranties)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        warranty.serialNo.isEmpty
                            ? '（未登记序列号）'
                            : warranty.serialNo,
                      ),
                      subtitle: Text(
                        '${warranty.startDate.toLocal().toString().substring(0, 10)}'
                        ' ~ ${warranty.endDate.toLocal().toString().substring(0, 10)}'
                        ' · ${warranty.status}',
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _quoteToContract(BuildContext context) async {
    try {
      final contract = await _repo.quoteToContract(widget.item.twentyId);
      toast.success(message: '已转合同：${contract.contractNo}');
      Get.back();
    } catch (e) {
      toast.error(message: '转合同失败：$e');
    }
  }

  Future<void> _showQuoteItemEditor() async {
    final products = await _repo.listProducts();
    if (!mounted) return;
    var selectedProduct = products.isEmpty ? null : products.first;
    final quantity = TextEditingController(text: '1');
    final unitPrice = TextEditingController(
      text: selectedProduct == null ? '' : selectedProduct.price.toString(),
    );
    final discount = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('添加报价明细'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LocalProduct>(
                  initialValue: selectedProduct,
                  decoration: const InputDecoration(
                    labelText: '产品/服务',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final p in products)
                      DropdownMenuItem(value: p, child: Text(p.name)),
                  ],
                  onChanged: (v) => setDialogState(() {
                    selectedProduct = v;
                    if (v != null) {
                      unitPrice.text = v.price.toString();
                    }
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '数量',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '单价（元）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: discount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '折扣率（1=无折扣）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selectedProduct == null) return;
    try {
      await _repo.addQuoteItem(
        LocalQuoteItem(
          id: '',
          quoteId: widget.item.twentyId,
          productId: selectedProduct!.id,
          productName: selectedProduct!.name,
          quantity: double.tryParse(quantity.text) ?? 1,
          unitPrice: double.tryParse(unitPrice.text) ?? 0,
          discount: double.tryParse(discount.text) ?? 1,
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      toast.error(message: '添加失败：$e');
    }
  }

  // ==================== 相关日记 ====================

  Future<void> _deleteEntity(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('将删除「${widget.item.name}」，此操作不可撤销。'),
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
      final repo = _repo;
      switch (widget.objectType) {
        case 'account':
          await repo.deleteAccount(widget.item.twentyId);
        case 'contact':
          await repo.deleteContact(widget.item.twentyId);
        case 'opportunity':
          await repo.deleteOpportunity(widget.item.twentyId);
        case 'contract':
          await repo.deleteContract(widget.item.twentyId);
        case 'product':
          await repo.deleteProduct(widget.item.twentyId);
        case 'quote':
          await repo.deleteQuote(widget.item.twentyId);
        default:
          await repo.deleteCustomRecord(widget.item.twentyId);
      }
      toast.success(message: '已删除');
      Get.back();
    } catch (e) {
      toast.error(message: '删除失败：$e');
    }
  }

  Widget _buildTimeline() {
    return FutureBuilder<List<_TimelineEntry>>(
      future: () async {
        final entries = <_TimelineEntry>[];
        final activities = await _repo.listActivities(
          relatedType: widget.objectType,
          relatedId: widget.item.twentyId,
        );
        for (final activity in activities) {
          entries.add(
            _TimelineEntry(
              time:
                  activity.completedAt ??
                  activity.scheduledAt ??
                  activity.createdAt,
              title: activity.subject,
              subtitle: '${activity.type} · ${activity.status}',
              icon: Icons.event_available_rounded,
              diary: null,
            ),
          );
        }
        final links = await _repo.linksForEntity(
          widget.objectType,
          widget.item.twentyId,
        );
        for (final link in links) {
          if (link.localType != 'diary') continue;
          final diary = await IsarUtil.getDiaryById(link.localId);
          if (diary != null) {
            entries.add(
              _TimelineEntry(
                time: diary.time,
                title: diary.title.isEmpty ? '未命名日记' : diary.title,
                subtitle: '日记',
                icon: Icons.article_outlined,
                diary: diary,
              ),
            );
          }
        }
        if (entries.isEmpty) {
          final fallback = await IsarUtil.searchDiariesByText(widget.item.name);
          for (final diary in fallback.take(10)) {
            entries.add(
              _TimelineEntry(
                time: diary.time,
                title: diary.title.isEmpty ? '未命名日记' : diary.title,
                subtitle: '日记（名称匹配）',
                icon: Icons.article_outlined,
                diary: diary,
              ),
            );
          }
        }
        entries.sort((a, b) => b.time.compareTo(a.time));
        return entries.take(50).toList();
      }(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <_TimelineEntry>[];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '时间线（${entries.length}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (entries.isEmpty)
                  const Text('暂无跟进与相关日记')
                else
                  for (final entry in entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(entry.icon, size: 18),
                      title: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.time.toLocal()} · ${entry.subtitle}',
                      ),
                      onTap: entry.diary == null
                          ? null
                          : () => Get.toNamed(
                              AppRoutes.diaryPage,
                              arguments: [entry.diary, true],
                            ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimelineEntry {
  final DateTime time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Diary? diary;

  const _TimelineEntry({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.diary,
  });
}
