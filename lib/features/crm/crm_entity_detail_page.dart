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
          _buildFields(),
          const SizedBox(height: 16),
          if (widget.objectType == 'account') _buildAccountDrilldown(),
          if (widget.objectType == 'opportunity') _buildOpportunityDrilldown(),
          if (widget.objectType == 'contract') _buildContractItems(),
          if (widget.objectType == 'quote') _buildQuoteItems(),
          const SizedBox(height: 16),
          _buildRelatedDiaries(),
        ],
      ),
    );
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

  Widget _buildRelatedDiaries() {
    return FutureBuilder<List<Diary>>(
      future: () async {
        final links = await _repo.linksForEntity(
          widget.objectType,
          widget.item.twentyId,
        );
        final diaries = <Diary>[];
        for (final link in links) {
          if (link.localType != 'diary') continue;
          final diary = await IsarUtil.getDiaryById(link.localId);
          if (diary != null) diaries.add(diary);
        }
        if (diaries.isEmpty) {
          diaries.addAll(await IsarUtil.searchDiariesByText(widget.item.name));
        }
        return diaries.take(20).toList();
      }(),
      builder: (context, snapshot) {
        final diaries = snapshot.data ?? const <Diary>[];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '相关日记（${diaries.length}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (diaries.isEmpty)
                  const Text('暂无相关日记')
                else
                  for (final diary in diaries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.article_outlined, size: 18),
                      title: Text(
                        diary.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${diary.time.toLocal()}'),
                      onTap: () => Get.toNamed(
                        AppRoutes.diaryPage,
                        arguments: [diary, true],
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
