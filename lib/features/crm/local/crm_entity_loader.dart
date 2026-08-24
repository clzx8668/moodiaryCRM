import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';

/// 按对象类型加载单条记录并构造通用缓存（下钻详情 / 关联就地展开复用）。
Future<CrmEntityCache?> loadCrmEntityCache({
  required String type,
  required String id,
}) async {
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
