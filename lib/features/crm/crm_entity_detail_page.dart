import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_create_form_panel.dart';
import 'package:moodiary/features/crm/crm_entity_detail_view.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_attachment_store.dart';
import 'package:moodiary/features/crm/local/crm_entity_creator.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 实体详情页（移动/窄屏整页）：复用 [CrmEntityDetailView]。
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
  int _refreshTick = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${crmTypeLabel(widget.objectType)} · ${widget.item.name}',
        ),
        actions: [
          IconButton(
            tooltip: '添加附件',
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: _pickAttachment,
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteEntity,
          ),
        ],
      ),
      body: CrmEntityDetailView(
        objectType: widget.objectType,
        item: widget.item,
        fields: widget.fields,
        onLinkRelated: _linkRelated,
        onCreateRelated: _createRelated,
        onCreateBackRelated: _createBackRelated,
        onOpenRelated: _openRelated,
        refreshTick: _refreshTick,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _linkRelated(String targetType, String targetId) async {
    try {
      await CrmEntityLinker.link(
        repo: CrmLocalRepository(),
        parentType: widget.objectType,
        parentId: widget.item.twentyId,
        targetType: targetType,
        targetId: targetId,
      );
      toast.success(message: '已关联${crmTypeLabel(targetType)}');
      if (mounted) setState(() => _refreshTick++);
    } catch (e) {
      toast.error(message: '关联失败：$e');
    }
  }

  void _createRelated(String targetType) {
    final future = Get.to(
      () => CrmCreatePage(
        objectType: targetType,
        title: crmTypeLabel(targetType),
        fields: kBaseObjectFields[targetType] ?? const [],
        contextLabel: '关联：${widget.item.name}',
        onCreate: (data) async {
          final id = await createCrmEntity(
            repo: CrmLocalRepository(),
            objectType: targetType,
            data: data,
          );
          if (id != null) {
            await CrmEntityLinker.link(
              repo: CrmLocalRepository(),
              parentType: widget.objectType,
              parentId: widget.item.twentyId,
              targetType: targetType,
              targetId: id,
            );
          }
        },
      ),
    );
    future?.then((_) {
      if (mounted) setState(() => _refreshTick++);
    });
  }

  /// 子侧关系字段「新增并关联」：新建父实体后把当前实体挂上去。
  void _createBackRelated(String targetType) {
    final future = Get.to(
      () => CrmCreatePage(
        objectType: targetType,
        title: crmTypeLabel(targetType),
        fields: kBaseObjectFields[targetType] ?? const [],
        contextLabel: '关联：${widget.item.name}',
        onCreate: (data) async {
          final id = await createCrmEntity(
            repo: CrmLocalRepository(),
            objectType: targetType,
            data: data,
          );
          if (id != null) {
            await CrmEntityLinker.link(
              repo: CrmLocalRepository(),
              parentType: targetType,
              parentId: id,
              targetType: widget.objectType,
              targetId: widget.item.twentyId,
            );
          }
        },
      ),
    );
    future?.then((_) {
      if (mounted) setState(() => _refreshTick++);
    });
  }

  Future<void> _openRelated(String targetType, String targetId) async {
    final cache = await _relatedCache(targetType, targetId);
    if (cache == null || !mounted) return;
    Get.to(
      () => CrmEntityDetailPage(
        objectType: targetType,
        item: cache,
        fields: kBaseObjectFields[targetType] ?? const [],
      ),
    );
  }

  /// 移动端下钻：按类型加载单条记录并构造缓存（复用字段定义的数据映射）。
  Future<CrmEntityCache?> _relatedCache(String type, String id) async {
    final repo = CrmLocalRepository();
    CrmEntityCache build(
      String name,
      Map<String, dynamic> data,
      DateTime updated,
    ) =>
        CrmEntityCache()
          ..id = id
          ..twentyId = id
          ..entityType = type
          ..name = name
          ..setData(data)
          ..updatedAt = updated;
    Future<String?> accountNameOf(String? accountId) async {
      if (accountId == null) return null;
      return (await repo.getAccount(accountId))?.name;
    }

    Future<String?> contactNameOf(String? contactId) async {
      if (contactId == null) return null;
      return (await repo.getContact(contactId))?.name;
    }

    Future<String?> oppNameOf(String? oppId) async {
      if (oppId == null) return null;
      return (await repo.getOpportunity(oppId))?.name;
    }

    switch (type) {
      case 'account':
        final a = await repo.getAccount(id);
        if (a == null) return null;
        return build(a.name, accountToDataMap(a), a.updatedAt);
      case 'contact':
        final c = await repo.getContact(id);
        if (c == null) return null;
        return build(
          c.name,
          contactToDataMap(c, accountName: await accountNameOf(c.accountId)),
          c.updatedAt,
        );
      case 'opportunity':
        final o = await repo.getOpportunity(id);
        if (o == null) return null;
        return build(
          o.name,
          opportunityToDataMap(
            o,
            accountName: await accountNameOf(o.accountId),
            contactName: await contactNameOf(o.contactId),
          ),
          o.updatedAt,
        );
      case 'contract':
        final c = await repo.getContract(id);
        if (c == null) return null;
        return build(
          c.name,
          contractToDataMap(c, accountName: await accountNameOf(c.accountId)),
          c.updatedAt,
        );
      case 'quote':
        final q = await repo.getQuote(id);
        if (q == null) return null;
        return build(
          q.quoteNo,
          quoteToDataMap(
            q,
            accountName: await accountNameOf(q.accountId),
            contactName: await contactNameOf(q.contactId),
            opportunityName: await oppNameOf(q.opportunityId),
          ),
          q.updatedAt,
        );
      case 'paymentPlan':
        final p = await repo.getPaymentPlan(id);
        if (p == null) return null;
        return build(p.planName, paymentPlanToDataMap(p), p.planDate);
      case 'payment':
        final p = await repo.getPayment(id);
        if (p == null) return null;
        return build(
          '¥${p.amount.toStringAsFixed(2)}',
          paymentToDataMap(p),
          p.paymentDate,
        );
      case 'invoice':
        final i = await repo.getInvoice(id);
        if (i == null) return null;
        return build(i.invoiceNo, invoiceToDataMap(i), i.createdAt);
      case 'warranty':
        final w = await repo.getWarranty(id);
        if (w == null) return null;
        return build(w.serialNo, warrantyToDataMap(w), w.endDate);
      case 'afterSales':
        final t = await repo.getAfterSales(id);
        if (t == null) return null;
        return build(t.ticketNo, afterSalesToDataMap(t), t.updatedAt);
    }
    return null;
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await CrmAttachmentStore.storeAndAttach(
        sourcePath: path,
        relatedType: widget.objectType,
        relatedId: widget.item.twentyId,
      );
      if (mounted) setState(() {});
      toast.success(message: '附件已添加');
    } catch (e) {
      toast.error(message: '添加附件失败：$e');
    }
  }

  Future<void> _deleteEntity() async {
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
      await CrmEntityDeleter.delete(widget.objectType, widget.item.twentyId);
      toast.success(message: '已删除');
      Get.back();
    } catch (e) {
      toast.error(message: '删除失败：$e');
    }
  }
}
