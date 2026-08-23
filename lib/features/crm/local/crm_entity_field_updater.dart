import 'package:moodiary/features/crm/local/crm_local_repository.dart';

/// 实体字段更新器：类型化地把「字段名 + 新值」写入对应本地表。
/// 表格单元格编辑、详情面板原位编辑共用。
class CrmEntityFieldUpdater {
  static Future<void> update({
    required String objectType,
    required String id,
    required String field,
    required Object? value,
  }) async {
    final repo = CrmLocalRepository();
    switch (objectType) {
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
      case 'product':
        final p = await repo.getProduct(id);
        if (p == null) return;
        _assign(p, field, value);
        await repo.updateProduct(p);
      case 'quote':
        final q = await repo.getQuote(id);
        if (q == null) return;
        _assign(q, field, value);
        await repo.updateQuote(q);
      case 'paymentPlan':
        final p = await repo.getPaymentPlan(id);
        if (p == null) return;
        _assign(p, field, value);
        await repo.updatePaymentPlan(p);
      case 'payment':
        final p = await repo.getPayment(id);
        if (p == null) return;
        _assign(p, field, value);
        await repo.updatePayment(p);
      case 'invoice':
        final i = await repo.getInvoice(id);
        if (i == null) return;
        _assign(i, field, value);
        await repo.updateInvoice(i);
      case 'warranty':
        final w = await repo.getWarranty(id);
        if (w == null) return;
        _assign(w, field, value);
        await repo.updateWarranty(w);
      case 'afterSales':
        final t = await repo.getAfterSales(id);
        if (t == null) return;
        _assign(t, field, value);
        await repo.updateAfterSales(t);
      case 'activity':
        final a = await repo.getActivity(id);
        if (a == null) return;
        _assign(a, field, value);
        await repo.updateActivity(a);
      case 'reminder':
        final r = await repo.getReminder(id);
        if (r == null) return;
        _assign(r, field, value);
        await repo.updateReminder(r);
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

  static void _assign(dynamic entity, String field, Object? value) {
    switch (field) {
      case 'name':
        entity.name = value?.toString() ?? '';
      case 'type':
        entity.type = value?.toString() ?? '';
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
      case 'accountId':
        entity.accountId = _nullableStr(value);
      case 'contactId':
        entity.contactId = _nullableStr(value);
      case 'opportunityId':
        entity.opportunityId = _nullableStr(value);
      case 'contractId':
        entity.contractId = _nullableStr(value);
      case 'planId':
        entity.planId = _nullableStr(value);
      case 'productId':
        entity.productId = _nullableStr(value);
      case 'quoteId':
        entity.quoteId = _nullableStr(value);
      case 'stage':
        entity.stage = value?.toString() ?? '';
      case 'probability':
        entity.probability = _toInt(value) ?? 0;
      case 'amount':
        entity.amount = _toDouble(value) ?? 0;
      case 'currency':
        entity.currency = value?.toString() ?? 'CNY';
      case 'totalAmountCurrency':
      case 'amountCurrency':
      case 'priceCurrency':
      case 'planAmountCurrency':
      case 'discountAmountCurrency':
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
        entity.startDate = _parseDate(value) ?? DateTime.now();
      case 'endDate':
        entity.endDate = _parseDate(value) ?? DateTime.now();
      case 'warrantyEndDate':
        entity.warrantyEndDate = _parseDate(value);
      case 'sku':
        entity.sku = value?.toString() ?? '';
      case 'unit':
        entity.unit = value?.toString() ?? '';
      case 'price':
        entity.price = _toDouble(value) ?? 0;
      case 'cost':
        entity.cost = _toDouble(value) ?? 0;
      case 'warrantyMonths':
        entity.warrantyMonths = _toInt(value) ?? 0;
      case 'isActive':
        entity.isActive = value?.toString() == 'true';
      case 'quoteNo':
        entity.quoteNo = value?.toString() ?? '';
      case 'discountAmount':
        entity.discountAmount = _toDouble(value) ?? 0;
      case 'validUntil':
        entity.validUntil = _parseDate(value);
      case 'planName':
        entity.planName = value?.toString() ?? '';
      case 'planAmount':
        entity.planAmount = _toDouble(value) ?? 0;
      case 'planDate':
        entity.planDate = _parseDate(value) ?? DateTime.now();
      case 'paymentDate':
        entity.paymentDate = _parseDate(value) ?? DateTime.now();
      case 'method':
        entity.method = value?.toString() ?? 'transfer';
      case 'invoiceNo':
        entity.invoiceNo = value?.toString() ?? '';
      case 'taxRate':
        entity.taxRate = _toDouble(value) ?? 0.13;
      case 'issueDate':
        entity.issueDate = _parseDate(value);
      case 'receiverName':
        entity.receiverName = value?.toString() ?? '';
      case 'serialNo':
        entity.serialNo = value?.toString() ?? '';
      case 'subject':
        entity.subject = value?.toString() ?? '';
      case 'priority':
        entity.priority = value?.toString() ?? 'medium';
      case 'description':
        entity.description = value?.toString() ?? '';
      case 'resolution':
        entity.resolution = value?.toString() ?? '';
      case 'direction':
        entity.direction = value?.toString();
      case 'scheduledAt':
        entity.scheduledAt = _parseDate(value);
      case 'remindAt':
        entity.remindAt = _parseDate(value) ?? DateTime.now();
      case 'isCompleted':
        entity.isCompleted = value?.toString() == 'true';
    }
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String? _nullableStr(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

/// 实体删除器：按对象类型删除对应本地记录（含自定义对象）。
class CrmEntityDeleter {
  static Future<void> delete(String objectType, String id) async {
    final repo = CrmLocalRepository();
    switch (objectType) {
      case 'account':
        await repo.deleteAccount(id);
      case 'contact':
        await repo.deleteContact(id);
      case 'opportunity':
        await repo.deleteOpportunity(id);
      case 'contract':
        await repo.deleteContract(id);
      case 'product':
        await repo.deleteProduct(id);
      case 'quote':
        await repo.deleteQuote(id);
      case 'paymentPlan':
        await repo.deletePaymentPlan(id);
      case 'payment':
        await repo.deletePayment(id);
      case 'invoice':
        await repo.deleteInvoice(id);
      case 'warranty':
        await repo.deleteWarranty(id);
      case 'afterSales':
        await repo.deleteAfterSales(id);
      case 'activity':
        await repo.deleteActivity(id);
      case 'reminder':
        await repo.deleteReminder(id);
      default:
        await repo.deleteCustomRecord(id);
    }
  }
}

/// 实体关联写入器：把 target 记录挂到 parent（设置外键）。
/// 支持全部基础对象的关系方向；parentId 传空字符串表示解除该方向关联。
class CrmEntityLinker {
  static Future<void> link({
    required CrmLocalRepository repo,
    required String parentType,
    required String parentId,
    required String targetType,
    required String targetId,
  }) async {
    switch (targetType) {
      case 'account':
        // 账户是纯父实体，不作为子侧挂到其它对象
        return;
      case 'contact':
        final c = await repo.getContact(targetId);
        if (c == null) return;
        if (parentType == 'account') c.accountId = _emptyToNull(parentId);
        await repo.updateContact(c);
      case 'opportunity':
        final o = await repo.getOpportunity(targetId);
        if (o == null) return;
        if (parentType == 'account') o.accountId = _emptyToNull(parentId);
        if (parentType == 'contact') o.contactId = _emptyToNull(parentId);
        await repo.updateOpportunity(o);
      case 'contract':
        final c = await repo.getContract(targetId);
        if (c == null) return;
        if (parentType == 'account') c.accountId = _emptyToNull(parentId);
        if (parentType == 'contact') c.contactId = _emptyToNull(parentId);
        if (parentType == 'opportunity') c.opportunityId = _emptyToNull(parentId);
        if (parentType == 'quote') c.quoteId = _emptyToNull(parentId);
        await repo.updateContract(c);
      case 'quote':
        final q = await repo.getQuote(targetId);
        if (q == null) return;
        if (parentType == 'account') q.accountId = _emptyToNull(parentId);
        if (parentType == 'contact') q.contactId = _emptyToNull(parentId);
        if (parentType == 'opportunity') q.opportunityId = _emptyToNull(parentId);
        await repo.updateQuote(q);
      case 'paymentPlan':
        final p = await repo.getPaymentPlan(targetId);
        if (p == null) return;
        if (parentType == 'contract') p.contractId = _emptyOrEmpty(parentId);
        await repo.updatePaymentPlan(p);
      case 'payment':
        final p = await repo.getPayment(targetId);
        if (p == null) return;
        if (parentType == 'contract') p.contractId = _emptyOrEmpty(parentId);
        if (parentType == 'paymentPlan') p.planId = _emptyToNull(parentId);
        await repo.updatePayment(p);
      case 'invoice':
        final i = await repo.getInvoice(targetId);
        if (i == null) return;
        if (parentType == 'contract') i.contractId = _emptyOrEmpty(parentId);
        await repo.updateInvoice(i);
      case 'warranty':
        final w = await repo.getWarranty(targetId);
        if (w == null) return;
        if (parentType == 'contract') w.contractId = _emptyOrEmpty(parentId);
        if (parentType == 'product') w.productId = _emptyToNull(parentId);
        await repo.updateWarranty(w);
      case 'afterSales':
        final t = await repo.getAfterSales(targetId);
        if (t == null) return;
        if (parentType == 'account') t.accountId = _emptyOrEmpty(parentId);
        if (parentType == 'contact') t.contactId = _emptyToNull(parentId);
        if (parentType == 'contract') t.contractId = _emptyToNull(parentId);
        await repo.updateAfterSales(t);
    }
  }

  static String? _emptyToNull(String id) => id.isEmpty ? null : id;

  static String _emptyOrEmpty(String id) => id;
}
