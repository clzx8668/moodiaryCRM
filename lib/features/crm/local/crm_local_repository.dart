import 'package:drift/drift.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 本地优先 CRM 仓储层（唯一读写入口）。
///
/// - 基础对象（客户/联系人/机会/合同）走强类型表（19 表设计文档）；
/// - 自定义对象走「对象定义 + 通用记录 JSON 宽表」（用户自建对象）；
/// - 实体 ↔ 日记/待办关联（跟进/认领/时间线）走 CrmEntityLinks。
class CrmLocalRepository {
  final AppDatabase db;

  CrmLocalRepository([AppDatabase? db]) : db = db ?? IsarUtil.database;

  static const List<String> baseObjectTypes = [
    'account',
    'contact',
    'opportunity',
    'contract',
    'product',
    'quote',
  ];

  // ==================== 客户/账户 ====================

  Future<List<LocalAccount>> listAccounts({String? keyword}) async {
    final query = db.select(db.crmAccounts)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim();
      query.where(
        (t) =>
            t.name.contains(k) |
            t.phone.contains(k) |
            t.email.contains(k) |
            t.industry.contains(k),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_accountFromRow).toList();
  }

  Future<LocalAccount?> getAccount(String id) async {
    final row = await (db.select(db.crmAccounts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _accountFromRow(row);
  }

  Future<LocalAccount> createAccount(LocalAccount account) async {
    final now = DateTime.now();
    final entity = account
      ..id = account.id.isEmpty ? const Uuid().v7() : account.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmAccounts).insert(_accountCompanion(entity));
    return entity;
  }

  Future<LocalAccount> updateAccount(LocalAccount account) async {
    account.updatedAt = DateTime.now();
    await (db.update(db.crmAccounts)..where((t) => t.id.equals(account.id)))
        .write(_accountCompanion(account));
    return account;
  }

  Future<void> deleteAccount(String id) async {
    await (db.update(db.crmAccounts)..where((t) => t.id.equals(id))).write(
      CrmAccountsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countAccounts() async => (await listAccounts()).length;

  // ==================== 联系人 ====================

  Future<List<LocalContact>> listContacts({String? keyword}) async {
    final query = db.select(db.crmContacts)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim();
      query.where(
        (t) =>
            t.name.contains(k) |
            t.title.contains(k) |
            t.phone.contains(k) |
            t.email.contains(k),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_contactFromRow).toList();
  }

  Future<List<LocalContact>> contactsOfAccount(String accountId) async {
    final rows = await (db.select(db.crmContacts)
          ..where(
            (t) => t.accountId.equals(accountId) & t.deleted.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_contactFromRow).toList();
  }

  Future<LocalContact?> getContact(String id) async {
    final row = await (db.select(db.crmContacts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _contactFromRow(row);
  }

  Future<LocalContact> createContact(LocalContact contact) async {
    final now = DateTime.now();
    final entity = contact
      ..id = contact.id.isEmpty ? const Uuid().v7() : contact.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmContacts).insert(_contactCompanion(entity));
    return entity;
  }

  Future<LocalContact> updateContact(LocalContact contact) async {
    contact.updatedAt = DateTime.now();
    await (db.update(db.crmContacts)..where((t) => t.id.equals(contact.id)))
        .write(_contactCompanion(contact));
    return contact;
  }

  Future<void> deleteContact(String id) async {
    await (db.update(db.crmContacts)..where((t) => t.id.equals(id))).write(
      CrmContactsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countContacts() async => (await listContacts()).length;

  // ==================== 机会/线索 ====================

  Future<List<LocalOpportunity>> listOpportunities({String? keyword}) async {
    final query = db.select(db.crmOpportunities)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim();
      query.where(
        (t) =>
            t.name.contains(k) |
            t.stage.contains(k) |
            t.source.contains(k),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_opportunityFromRow).toList();
  }

  Future<LocalOpportunity?> getOpportunity(String id) async {
    final row = await (db.select(db.crmOpportunities)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _opportunityFromRow(row);
  }

  Future<LocalOpportunity> createOpportunity(LocalOpportunity opp) async {
    final now = DateTime.now();
    final entity = opp..id = opp.id.isEmpty ? const Uuid().v7() : opp.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmOpportunities).insert(_opportunityCompanion(entity));
    return entity;
  }

  Future<LocalOpportunity> updateOpportunity(LocalOpportunity opp) async {
    opp.updatedAt = DateTime.now();
    await (db.update(db.crmOpportunities)
          ..where((t) => t.id.equals(opp.id)))
        .write(_opportunityCompanion(opp));
    return opp;
  }

  Future<void> deleteOpportunity(String id) async {
    await (db.update(db.crmOpportunities)..where((t) => t.id.equals(id))).write(
      CrmOpportunitiesCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countOpportunities() async =>
      (await listOpportunities()).length;

  // ==================== 合同 ====================

  Future<List<LocalContract>> listContracts({String? keyword}) async {
    final query = db.select(db.crmContracts)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim();
      query.where(
        (t) =>
            t.name.contains(k) |
            t.contractNo.contains(k) |
            t.status.contains(k),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_contractFromRow).toList();
  }

  Future<LocalContract?> getContract(String id) async {
    final row = await (db.select(db.crmContracts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _contractFromRow(row);
  }

  Future<LocalContract> createContract(LocalContract contract) async {
    final now = DateTime.now();
    final entity = contract
      ..id = contract.id.isEmpty ? const Uuid().v7() : contract.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    if (entity.contractNo.isEmpty) {
      entity.contractNo = await _nextSequenceNo('HT');
    }
    await db.into(db.crmContracts).insert(_contractCompanion(entity));
    return entity;
  }

  Future<LocalContract> updateContract(LocalContract contract) async {
    contract.updatedAt = DateTime.now();
    await (db.update(db.crmContracts)
          ..where((t) => t.id.equals(contract.id)))
        .write(_contractCompanion(contract));
    return contract;
  }

  Future<void> deleteContract(String id) async {
    await (db.update(db.crmContracts)..where((t) => t.id.equals(id))).write(
      CrmContractsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countContracts() async => (await listContracts()).length;

  // ==================== 产品分类 / 产品 ====================

  Future<List<LocalProductCategory>> listProductCategories() async {
    final rows = await db.select(db.crmProductCategories).get();
    return rows
        .map(
          (r) => LocalProductCategory(id: r.id, name: r.name, parentId: r.parentId),
        )
        .toList();
  }

  Future<LocalProductCategory> createProductCategory(
    LocalProductCategory category,
  ) async {
    final entity = category
      ..id = category.id.isEmpty ? const Uuid().v7() : category.id;
    await db.into(db.crmProductCategories).insert(
      CrmProductCategoriesCompanion.insert(
        id: entity.id,
        name: entity.name,
        parentId: Value(entity.parentId),
      ),
    );
    return entity;
  }

  Future<List<LocalProduct>> listProducts({String? keyword}) async {
    final query = db.select(db.crmProducts)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim();
      query.where(
        (t) =>
            t.name.contains(k) |
            t.sku.contains(k) |
            t.type.contains(k),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_productFromRow).toList();
  }

  Future<LocalProduct?> getProduct(String id) async {
    final row = await (db.select(db.crmProducts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _productFromRow(row);
  }

  Future<LocalProduct> createProduct(LocalProduct product) async {
    final now = DateTime.now();
    final entity = product
      ..id = product.id.isEmpty ? const Uuid().v7() : product.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    if (entity.sku.trim().isNotEmpty) {
      final dup = await (db.select(db.crmProducts)
            ..where(
              (t) =>
                  t.sku.equals(entity.sku.trim()) & t.deleted.equals(false),
            ))
          .getSingleOrNull();
      if (dup != null && dup.id != entity.id) {
        throw ArgumentError('SKU 已存在：${entity.sku}');
      }
    }
    await db.into(db.crmProducts).insert(_productCompanion(entity));
    return entity;
  }

  Future<LocalProduct> updateProduct(LocalProduct product) async {
    product.updatedAt = DateTime.now();
    await (db.update(db.crmProducts)..where((t) => t.id.equals(product.id)))
        .write(_productCompanion(product));
    return product;
  }

  Future<void> deleteProduct(String id) async {
    await (db.update(db.crmProducts)..where((t) => t.id.equals(id))).write(
      CrmProductsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countProducts() async => (await listProducts()).length;

  // ==================== 报价单 / 明细 ====================

  Future<List<LocalQuote>> listQuotes({String? keyword}) async {
    final query = db.select(db.crmQuotes)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim();
      query.where(
        (t) =>
            t.quoteNo.contains(k) |
            t.status.contains(k) |
            t.note.contains(k),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_quoteFromRow).toList();
  }

  Future<LocalQuote?> getQuote(String id) async {
    final row = await (db.select(db.crmQuotes)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _quoteFromRow(row);
  }

  Future<LocalQuote> createQuote(LocalQuote quote) async {
    final now = DateTime.now();
    final entity = quote..id = quote.id.isEmpty ? const Uuid().v7() : quote.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    if (entity.quoteNo.isEmpty) {
      entity.quoteNo = await _nextSequenceNo('QT');
    }
    await db.into(db.crmQuotes).insert(_quoteCompanion(entity));
    return entity;
  }

  Future<LocalQuote> updateQuote(LocalQuote quote) async {
    quote.updatedAt = DateTime.now();
    await (db.update(db.crmQuotes)..where((t) => t.id.equals(quote.id)))
        .write(_quoteCompanion(quote));
    return quote;
  }

  Future<void> deleteQuote(String id) async {
    await db.transaction(() async {
      await (db.delete(db.crmQuoteItems)..where((t) => t.quoteId.equals(id)))
          .go();
      await (db.update(db.crmQuotes)..where((t) => t.id.equals(id))).write(
        CrmQuotesCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<List<LocalQuoteItem>> quoteItems(String quoteId) async {
    final rows = await (db.select(db.crmQuoteItems)
          ..where((t) => t.quoteId.equals(quoteId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_quoteItemFromRow).toList();
  }

  Future<LocalQuoteItem> addQuoteItem(LocalQuoteItem item) async {
    final entity = item..id = item.id.isEmpty ? const Uuid().v7() : item.id;
    entity.amount = entity.quantity * entity.unitPrice * entity.discount;
    await db.into(db.crmQuoteItems).insert(_quoteItemCompanion(entity));
    await _recalcQuote(entity.quoteId);
    return entity;
  }

  Future<LocalQuoteItem> updateQuoteItem(LocalQuoteItem item) async {
    item.amount = item.quantity * item.unitPrice * item.discount;
    await (db.update(db.crmQuoteItems)..where((t) => t.id.equals(item.id)))
        .write(_quoteItemCompanion(item));
    await _recalcQuote(item.quoteId);
    return item;
  }

  Future<void> removeQuoteItem(String id) async {
    final row = await (db.select(db.crmQuoteItems)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (db.delete(db.crmQuoteItems)..where((t) => t.id.equals(id))).go();
    if (row != null) await _recalcQuote(row.quoteId);
  }

  Future<void> _recalcQuote(String quoteId) async {
    final items = await quoteItems(quoteId);
    final total = items.fold<double>(0, (s, i) => s + i.amount);
    final quote = await getQuote(quoteId);
    if (quote != null) {
      quote.totalAmount = total;
      await updateQuote(quote);
    }
  }

  /// 报价转合同（幂等）：accepted 报价 → 生成合同 + 明细快照。
  Future<LocalContract> quoteToContract(String quoteId) async {
    final quote = await getQuote(quoteId);
    if (quote == null) throw StateError('报价单不存在');
    if (quote.status != 'accepted') {
      throw StateError('仅 accepted 状态的报价可转合同（当前 ${quote.status}）');
    }
    // 幂等：已存在来源报价的合同直接返回
    final existing = await (db.select(db.crmContracts)
          ..where((t) => t.quoteId.equals(quoteId) & t.deleted.equals(false)))
        .getSingleOrNull();
    if (existing != null) return _contractFromRow(existing);

    final contract = await createContract(
      LocalContract(
        id: '',
        name: '合同-${quote.quoteNo}',
        accountId: quote.accountId,
        contactId: quote.contactId,
        opportunityId: quote.opportunityId,
        quoteId: quote.id,
        status: 'active',
        totalAmount: quote.totalAmount,
      ),
    );
    final items = await quoteItems(quoteId);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      var warrantyMonths = 0;
      if (item.productId != null) {
        final product = await getProduct(item.productId!);
        warrantyMonths = product?.warrantyMonths ?? 0;
      }
      await addContractItem(
        LocalContractItem(
          id: '',
          contractId: contract.id,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          amount: item.amount,
          warrantyMonths: warrantyMonths,
          sortOrder: i,
        ),
      );
    }
    quote.status = 'accepted';
    await updateQuote(quote);
    return contract;
  }

  Future<int> countQuotes() async => (await listQuotes()).length;

  // ==================== 合同明细 ====================

  Future<List<LocalContractItem>> contractItems(String contractId) async {
    final rows = await (db.select(db.crmContractItems)
          ..where((t) => t.contractId.equals(contractId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_contractItemFromRow).toList();
  }

  Future<LocalContractItem> addContractItem(LocalContractItem item) async {
    final entity = item..id = item.id.isEmpty ? const Uuid().v7() : item.id;
    entity.amount = entity.quantity * entity.unitPrice;
    await db.into(db.crmContractItems).insert(_contractItemCompanion(entity));
    await _recalcContract(entity.contractId);
    return entity;
  }

  Future<void> _recalcContract(String contractId) async {
    final items = await contractItems(contractId);
    final total = items.fold<double>(0, (s, i) => s + i.amount);
    final contract = await getContract(contractId);
    if (contract != null) {
      contract.totalAmount = total;
      await updateContract(contract);
    }
  }

  // ==================== 回款计划 / 回款 / 发票 ====================

  Future<List<LocalPaymentPlan>> listPaymentPlans({String? contractId}) async {
    final query = db.select(db.crmPaymentPlans);
    if (contractId != null) {
      query.where((t) => t.contractId.equals(contractId));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.planDate)]);
    final rows = await query.get();
    return rows.map(_paymentPlanFromRow).toList();
  }

  Future<LocalPaymentPlan> createPaymentPlan(LocalPaymentPlan plan) async {
    final entity = plan..id = plan.id.isEmpty ? const Uuid().v7() : plan.id;
    await db.into(db.crmPaymentPlans).insert(_paymentPlanCompanion(entity));
    return entity;
  }

  Future<LocalPaymentPlan?> getPaymentPlan(String id) async {
    final row = await (db.select(db.crmPaymentPlans)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _paymentPlanFromRow(row);
  }

  Future<LocalPaymentPlan> updatePaymentPlan(LocalPaymentPlan plan) async {
    await (db.update(db.crmPaymentPlans)
          ..where((t) => t.id.equals(plan.id)))
        .write(_paymentPlanCompanion(plan));
    return plan;
  }

  Future<void> deletePaymentPlan(String id) async {
    await (db.delete(db.crmPaymentPlans)..where((t) => t.id.equals(id))).go();
  }

  Future<List<LocalPayment>> listPayments({String? contractId}) async {
    final query = db.select(db.crmPayments);
    if (contractId != null) {
      query.where((t) => t.contractId.equals(contractId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.paymentDate)]);
    final rows = await query.get();
    return rows.map(_paymentFromRow).toList();
  }

  Future<LocalPayment> createPayment(LocalPayment payment) async {
    final entity = payment
      ..id = payment.id.isEmpty ? const Uuid().v7() : payment.id;
    await db.transaction(() async {
      await db.into(db.crmPayments).insert(_paymentCompanion(entity));
      await _recalcContractPaid(entity.contractId);
      if (entity.planId != null) await _recalcPlanPaid(entity.planId!);
    });
    return entity;
  }

  Future<LocalPayment?> getPayment(String id) async {
    final row = await (db.select(db.crmPayments)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _paymentFromRow(row);
  }

  Future<LocalPayment> updatePayment(LocalPayment payment) async {
    await (db.update(db.crmPayments)..where((t) => t.id.equals(payment.id)))
        .write(_paymentCompanion(payment));
    await _recalcContractPaid(payment.contractId);
    if (payment.planId != null) await _recalcPlanPaid(payment.planId!);
    return payment;
  }

  Future<void> deletePayment(String id) async {
    final row = await (db.select(db.crmPayments)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await db.transaction(() async {
      await (db.delete(db.crmPayments)..where((t) => t.id.equals(id))).go();
      await _recalcContractPaid(row.contractId);
      if (row.planId != null) await _recalcPlanPaid(row.planId!);
    });
  }

  Future<void> _recalcContractPaid(String contractId) async {
    final payments = await listPayments(contractId: contractId);
    final total = payments.fold<double>(0, (s, p) => s + p.amount);
    final contract = await getContract(contractId);
    if (contract != null && contract.paidAmount != total) {
      contract.paidAmount = total;
      await updateContract(contract);
    }
  }

  Future<void> _recalcPlanPaid(String planId) async {
    final row = await (db.select(db.crmPaymentPlans)
          ..where((t) => t.id.equals(planId)))
        .getSingleOrNull();
    if (row == null) return;
    final payments = await (db.select(db.crmPayments)
          ..where((t) => t.planId.equals(planId)))
        .get();
    final paid = payments.fold<double>(0, (s, p) => s + p.amount);
    final today = DateTime.now();
    var status = 'pending';
    if (paid >= row.planAmount && row.planAmount > 0) {
      status = 'completed';
    } else if (paid > 0) {
      status = 'partial';
    } else if (row.planDate.isBefore(DateTime(today.year, today.month, today.day))) {
      status = 'overdue';
    }
    final plan = _paymentPlanFromRow(row);
    plan.paidAmount = paid;
    plan.status = status;
    await updatePaymentPlan(plan);
  }

  Future<List<LocalInvoice>> listInvoices({String? contractId}) async {
    final query = db.select(db.crmInvoices);
    if (contractId != null) {
      query.where((t) => t.contractId.equals(contractId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_invoiceFromRow).toList();
  }

  Future<LocalInvoice> createInvoice(LocalInvoice invoice) async {
    final entity = invoice
      ..id = invoice.id.isEmpty ? const Uuid().v7() : invoice.id;
    await db.transaction(() async {
      await db.into(db.crmInvoices).insert(_invoiceCompanion(entity));
      await _recalcContractInvoiced(entity.contractId);
    });
    return entity;
  }

  Future<LocalInvoice?> getInvoice(String id) async {
    final row = await (db.select(db.crmInvoices)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _invoiceFromRow(row);
  }

  Future<LocalInvoice> updateInvoice(LocalInvoice invoice) async {
    await (db.update(db.crmInvoices)..where((t) => t.id.equals(invoice.id)))
        .write(_invoiceCompanion(invoice));
    await _recalcContractInvoiced(invoice.contractId);
    return invoice;
  }

  Future<void> deleteInvoice(String id) async {
    final row = await (db.select(db.crmInvoices)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await db.transaction(() async {
      await (db.delete(db.crmInvoices)..where((t) => t.id.equals(id))).go();
      await _recalcContractInvoiced(row.contractId);
    });
  }

  Future<void> _recalcContractInvoiced(String contractId) async {
    final invoices = await listInvoices(contractId: contractId);
    final total = invoices
        .where((i) => i.status != 'void')
        .fold<double>(0, (s, i) => s + i.amount);
    final contract = await getContract(contractId);
    if (contract != null && contract.invoicedAmount != total) {
      contract.invoicedAmount = total;
      await updateContract(contract);
    }
  }

  /// 到期提醒聚合：回款到期（7 天内未完成）/ 合同到期（30 天内）。
  Future<List<CrmReminderItem>> dueReminders() async {
    final today = DateTime.now();
    final in7 = today.add(const Duration(days: 7));
    final in30 = today.add(const Duration(days: 30));
    final result = <CrmReminderItem>[];

    final plans = await listPaymentPlans();
    for (final plan in plans) {
      if (plan.status == 'completed') continue;
      if (!plan.planDate.isBefore(in7)) continue;
      final contract = await getContract(plan.contractId);
      result.add(
        CrmReminderItem(
          type: 'paymentDue',
          title: '回款到期：${contract?.name ?? plan.contractId} · ${plan.planName}',
          at: plan.planDate,
          entityId: plan.contractId,
        ),
      );
    }

    final contracts = await listContracts();
    for (final contract in contracts) {
      final end = contract.endDate;
      if (end == null || contract.status == 'completed' || contract.status == 'terminated') {
        continue;
      }
      if (!end.isBefore(in30)) continue;
      result.add(
        CrmReminderItem(
          type: 'contractExpire',
          title: '合同到期：${contract.name}',
          at: end,
          entityId: contract.id,
        ),
      );
    }

    final warranties = await listWarranties();
    for (final warranty in warranties) {
      if (warranty.status != 'active') continue;
      if (!warranty.endDate.isBefore(in30)) continue;
      final contract = await getContract(warranty.contractId);
      result.add(
        CrmReminderItem(
          type: 'warrantyExpire',
          title:
              '质保到期：${contract?.name ?? warranty.contractId}'
              '${warranty.serialNo.isEmpty ? '' : '（${warranty.serialNo}）'}',
          at: warranty.endDate,
          entityId: warranty.contractId,
        ),
      );
    }

    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  // ==================== 质保 / 售后 ====================

  Future<List<LocalWarranty>> listWarranties({String? contractId}) async {
    final query = db.select(db.crmWarranties);
    if (contractId != null) {
      query.where((t) => t.contractId.equals(contractId));
    }
    final rows = await query.get();
    final today = DateTime.now();
    final result = <LocalWarranty>[];
    for (final row in rows) {
      final warranty = _warrantyFromRow(row);
      // 到期自动置 expired
      if (warranty.status == 'active' &&
          warranty.endDate.isBefore(today)) {
        warranty.status = 'expired';
        await updateWarranty(warranty);
      }
      result.add(warranty);
    }
    result.sort((a, b) => a.endDate.compareTo(b.endDate));
    return result;
  }

  Future<LocalWarranty?> getWarranty(String id) async {
    final row = await (db.select(db.crmWarranties)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _warrantyFromRow(row);
  }

  Future<LocalWarranty> createWarranty(LocalWarranty warranty) async {
    final entity = warranty
      ..id = warranty.id.isEmpty ? const Uuid().v7() : warranty.id;
    await db.into(db.crmWarranties).insert(_warrantyCompanion(entity));
    return entity;
  }

  Future<LocalWarranty> updateWarranty(LocalWarranty warranty) async {
    await (db.update(db.crmWarranties)
          ..where((t) => t.id.equals(warranty.id)))
        .write(_warrantyCompanion(warranty));
    return warranty;
  }

  Future<void> deleteWarranty(String id) async {
    await (db.delete(db.crmWarranties)..where((t) => t.id.equals(id))).go();
  }

  Future<List<LocalAfterSales>> listAfterSales({String? accountId}) async {
    final query = db.select(db.crmAfterSales)
      ..where((t) => t.deleted.equals(false));
    if (accountId != null) {
      query.where((t) => t.accountId.equals(accountId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_afterSalesFromRow).toList();
  }

  Future<LocalAfterSales?> getAfterSales(String id) async {
    final row = await (db.select(db.crmAfterSales)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _afterSalesFromRow(row);
  }

  Future<LocalAfterSales> createAfterSales(LocalAfterSales ticket) async {
    final now = DateTime.now();
    final entity = ticket
      ..id = ticket.id.isEmpty ? const Uuid().v7() : ticket.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    if (entity.ticketNo.isEmpty) {
      entity.ticketNo = await _nextSequenceNo('AS');
    }
    await db.into(db.crmAfterSales).insert(_afterSalesCompanion(entity));
    return entity;
  }

  Future<LocalAfterSales> updateAfterSales(LocalAfterSales ticket) async {
    ticket.updatedAt = DateTime.now();
    if (ticket.status == 'resolved' && ticket.resolvedAt == null) {
      ticket.resolvedAt = DateTime.now();
    }
    if (ticket.status == 'closed' && ticket.closedAt == null) {
      ticket.closedAt = DateTime.now();
    }
    await (db.update(db.crmAfterSales)
          ..where((t) => t.id.equals(ticket.id)))
        .write(_afterSalesCompanion(ticket));
    return ticket;
  }

  Future<void> deleteAfterSales(String id) async {
    await (db.update(db.crmAfterSales)..where((t) => t.id.equals(id))).write(
      CrmAfterSalesCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countAfterSales() async => (await listAfterSales()).length;

  // ==================== 跟进记录 / 标签 ====================

  Future<List<LocalActivity>> listActivities({
    String? relatedType,
    String? relatedId,
  }) async {
    final query = db.select(db.crmActivities);
    if (relatedType != null && relatedId != null) {
      query.where(
        (t) => t.relatedType.equals(relatedType) & t.relatedId.equals(relatedId),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_activityFromRow).toList();
  }

  Future<LocalActivity?> getActivity(String id) async {
    final row = await (db.select(db.crmActivities)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _activityFromRow(row);
  }

  Future<LocalActivity> createActivity(LocalActivity activity) async {
    final entity = activity
      ..id = activity.id.isEmpty ? const Uuid().v7() : activity.id;
    await db.into(db.crmActivities).insert(_activityCompanion(entity));
    return entity;
  }

  Future<LocalActivity> updateActivity(LocalActivity activity) async {
    await (db.update(db.crmActivities)
          ..where((t) => t.id.equals(activity.id)))
        .write(_activityCompanion(activity));
    return activity;
  }

  Future<void> deleteActivity(String id) async {
    await (db.delete(db.crmActivities)..where((t) => t.id.equals(id))).go();
  }

  Future<List<LocalTag>> listTags() async {
    final rows = await db.select(db.crmTags).get();
    return rows.map((r) => LocalTag(id: r.id, name: r.name, color: r.color)).toList();
  }

  Future<LocalTag> createTag(String name) async {
    final trimmed = name.trim();
    final existing = await (db.select(db.crmTags)
          ..where((t) => t.name.equals(trimmed)))
        .getSingleOrNull();
    if (existing != null) {
      return LocalTag(id: existing.id, name: existing.name, color: existing.color);
    }
    final tag = LocalTag(id: const Uuid().v7(), name: trimmed);
    await db.into(db.crmTags).insert(
      CrmTagsCompanion.insert(id: tag.id, name: tag.name, color: Value(tag.color)),
    );
    return tag;
  }

  Future<void> deleteTag(String id) async {
    await db.transaction(() async {
      await (db.delete(db.crmEntityTags)..where((t) => t.tagId.equals(id))).go();
      await (db.delete(db.crmTags)..where((t) => t.id.equals(id))).go();
    });
  }

  /// 设置实体标签（差异同步：新增缺失、断开移除的关联）。
  Future<List<String>> setEntityTags(
    String entityType,
    String entityId,
    List<String> names,
  ) async {
    final cleaned = names.map((n) => n.trim()).where((n) => n.isNotEmpty).toSet();
    await db.transaction(() async {
      final current = await tagsForEntity(entityType, entityId);
      final currentIds = current.map((t) => t.id).toSet();
      final desiredIds = <String>{};
      for (final name in cleaned) {
        final tag = await createTag(name);
        desiredIds.add(tag.id);
        if (!currentIds.contains(tag.id)) {
          await db.into(db.crmEntityTags).insert(
            CrmEntityTagsCompanion.insert(
              entityType: entityType,
              entityId: entityId,
              tagId: tag.id,
            ),
          );
        }
      }
      for (final id in currentIds.difference(desiredIds)) {
        await (db.delete(db.crmEntityTags)
              ..where(
                (t) =>
                    t.entityType.equals(entityType) &
                    t.entityId.equals(entityId) &
                    t.tagId.equals(id),
              ))
            .go();
      }
    });
    return (await tagsForEntity(entityType, entityId)).map((t) => t.name).toList();
  }

  Future<List<LocalTag>> tagsForEntity(String entityType, String entityId) async {
    final rows = await (db.select(db.crmEntityTags)
          ..where(
            (t) => t.entityType.equals(entityType) & t.entityId.equals(entityId),
          ))
        .get();
    final tags = <LocalTag>[];
    for (final row in rows) {
      final tag = await (db.select(db.crmTags)
            ..where((t) => t.id.equals(row.tagId)))
          .getSingleOrNull();
      if (tag != null) {
        tags.add(LocalTag(id: tag.id, name: tag.name, color: tag.color));
      }
    }
    return tags;
  }

  // ==================== 附件 / 提醒 ====================

  Future<List<LocalAttachment>> listAttachments(
    String relatedType,
    String relatedId,
  ) async {
    final rows = await (db.select(db.crmAttachments)
          ..where(
            (t) => t.relatedType.equals(relatedType) & t.relatedId.equals(relatedId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_attachmentFromRow).toList();
  }

  Future<LocalAttachment> addAttachment(LocalAttachment attachment) async {
    final entity = attachment
      ..id = attachment.id.isEmpty ? const Uuid().v7() : attachment.id;
    await db.into(db.crmAttachments).insert(_attachmentCompanion(entity));
    return entity;
  }

  Future<LocalAttachment?> getAttachment(String id) async {
    final row = await (db.select(db.crmAttachments)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _attachmentFromRow(row);
  }

  Future<void> deleteAttachment(String id) async {
    await (db.delete(db.crmAttachments)..where((t) => t.id.equals(id))).go();
  }

  Future<List<LocalReminder>> listReminders({
    bool includeCompleted = false,
  }) async {
    final query = db.select(db.crmReminders);
    if (!includeCompleted) {
      query.where((t) => t.isCompleted.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.remindAt)]);
    final rows = await query.get();
    return rows.map(_reminderFromRow).toList();
  }

  Future<LocalReminder> createReminder(LocalReminder reminder) async {
    final entity = reminder
      ..id = reminder.id.isEmpty ? const Uuid().v7() : reminder.id;
    await db.into(db.crmReminders).insert(_reminderCompanion(entity));
    return entity;
  }

  Future<LocalReminder?> getReminder(String id) async {
    final row = await (db.select(db.crmReminders)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _reminderFromRow(row);
  }

  Future<LocalReminder> updateReminder(LocalReminder reminder) async {
    await (db.update(db.crmReminders)
          ..where((t) => t.id.equals(reminder.id)))
        .write(_reminderCompanion(reminder));
    return reminder;
  }

  Future<LocalReminder> completeReminder(String id) async {
    final row = await (db.select(db.crmReminders)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw StateError('提醒不存在');
    final reminder = _reminderFromRow(row)..isCompleted = true;
    await (db.update(db.crmReminders)..where((t) => t.id.equals(id))).write(
      const CrmRemindersCompanion(isCompleted: Value(true)),
    );
    return reminder;
  }

  Future<void> deleteReminder(String id) async {
    await (db.delete(db.crmReminders)..where((t) => t.id.equals(id))).go();
  }

  /// 单号生成：前缀 + YYYYMMDD + 当日自增 3 位（QT/HT/AS）
  Future<String> _nextSequenceNo(String prefix) async {
    final now = DateTime.now();
    final date = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final like = '$prefix-$date-%';
    var maxSeq = 0;
    if (prefix == 'HT') {
      final rows = await (db.select(db.crmContracts)
            ..where((t) => t.contractNo.like(like)))
          .get();
      for (final row in rows) {
        final seq =
            int.tryParse(row.contractNo.substring(row.contractNo.length - 3)) ??
            0;
        if (seq > maxSeq) maxSeq = seq;
      }
    } else if (prefix == 'QT') {
      final rows = await (db.select(db.crmQuotes)
            ..where((t) => t.quoteNo.like(like)))
          .get();
      for (final row in rows) {
        final seq =
            int.tryParse(row.quoteNo.substring(row.quoteNo.length - 3)) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    } else if (prefix == 'AS') {
      final rows = await (db.select(db.crmAfterSales)
            ..where((t) => t.ticketNo.like(like)))
          .get();
      for (final row in rows) {
        final seq =
            int.tryParse(row.ticketNo.substring(row.ticketNo.length - 3)) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    } else {
      throw ArgumentError('不支持的编号前缀：$prefix');
    }
    return '$prefix-$date-${(maxSeq + 1).toString().padLeft(3, '0')}';
  }

  // ==================== 自定义对象 ====================

  Future<List<LocalCustomObject>> listCustomObjects() async {
    final rows = await db.select(db.crmObjectDefs).get();
    return rows.map(_objectDefFromRow).toList();
  }

  Future<LocalCustomObject?> getCustomObject(String id) async {
    final row = await (db.select(db.crmObjectDefs)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _objectDefFromRow(row);
  }

  Future<LocalCustomObject> createCustomObject(LocalCustomObject def) async {
    final now = DateTime.now();
    final entity = def..id = def.id.isEmpty ? const Uuid().v7() : def.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmObjectDefs).insert(_objectDefCompanion(entity));
    return entity;
  }

  Future<LocalCustomObject> updateCustomObject(LocalCustomObject def) async {
    def.updatedAt = DateTime.now();
    await (db.update(db.crmObjectDefs)..where((t) => t.id.equals(def.id)))
        .write(_objectDefCompanion(def));
    return def;
  }

  Future<void> deleteCustomObject(String id) async {
    await db.transaction(() async {
      await (db.delete(db.crmCustomRecords)
            ..where((t) => t.objectId.equals(id)))
          .go();
      await (db.delete(db.crmObjectDefs)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<List<LocalCustomRecord>> listCustomRecords(
    String objectId, {
    String? keyword,
  }) async {
    final query = db.select(db.crmCustomRecords)
      ..where(
        (t) => t.objectId.equals(objectId) & t.deleted.equals(false),
      );
    if (keyword != null && keyword.trim().isNotEmpty) {
      query.where((t) => t.label.contains(keyword.trim()));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_customRecordFromRow).toList();
  }

  Future<LocalCustomRecord?> getCustomRecord(String id) async {
    final row = await (db.select(db.crmCustomRecords)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _customRecordFromRow(row);
  }

  Future<LocalCustomRecord> createCustomRecord(LocalCustomRecord record) async {
    final now = DateTime.now();
    final entity = record
      ..id = record.id.isEmpty ? const Uuid().v7() : record.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmCustomRecords).insert(_customRecordCompanion(entity));
    return entity;
  }

  Future<LocalCustomRecord> updateCustomRecord(LocalCustomRecord record) async {
    record.updatedAt = DateTime.now();
    await (db.update(db.crmCustomRecords)
          ..where((t) => t.id.equals(record.id)))
        .write(_customRecordCompanion(record));
    return record;
  }

  Future<void> deleteCustomRecord(String id) async {
    await (db.update(db.crmCustomRecords)..where((t) => t.id.equals(id))).write(
      CrmCustomRecordsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countCustomRecords(String objectId) async =>
      (await listCustomRecords(objectId)).length;

  // ==================== 实体 ↔ 内容关联 ====================

  Future<LocalEntityLink> linkEntity({
    required String entityType,
    required String entityId,
    required String localType,
    required String localId,
    String relation = 'followup',
  }) async {
    final link = LocalEntityLink(
      id: const Uuid().v7(),
      entityType: entityType,
      entityId: entityId,
      localType: localType,
      localId: localId,
      relation: relation,
    );
    await db.into(db.crmEntityLinks).insert(
      CrmEntityLinksCompanion.insert(
        id: link.id,
        entityType: link.entityType,
        entityId: link.entityId,
        localType: link.localType,
        localId: link.localId,
        relation: Value(link.relation),
        createdAt: link.createdAt,
      ),
    );
    return link;
  }

  Future<void> unlinkEntity({
    required String entityType,
    required String entityId,
    required String localType,
    required String localId,
    String? relation,
  }) async {
    final query = db.delete(db.crmEntityLinks)
      ..where(
        (t) =>
            t.entityType.equals(entityType) &
            t.entityId.equals(entityId) &
            t.localType.equals(localType) &
            t.localId.equals(localId),
      );
    if (relation != null) {
      query.where((t) => t.relation.equals(relation));
    }
    await query.go();
  }

  Future<List<LocalEntityLink>> linksForEntity(
    String entityType,
    String entityId,
  ) async {
    final rows = await (db.select(db.crmEntityLinks)
          ..where(
            (t) => t.entityType.equals(entityType) & t.entityId.equals(entityId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_linkFromRow).toList();
  }

  // ==================== 统计 ====================

  Future<Map<String, int>> stats() async {
    final result = <String, int>{};
    result['account'] = await countAccounts();
    result['contact'] = await countContacts();
    result['opportunity'] = await countOpportunities();
    result['contract'] = await countContracts();
    result['product'] = await countProducts();
    result['quote'] = await countQuotes();
    result['afterSales'] = await countAfterSales();
    for (final def in await listCustomObjects()) {
      result['custom:${def.id}'] = await countCustomRecords(def.id);
    }
    return result;
  }

  // ==================== 行 ↔ 模型 ====================

  CrmAccountsCompanion _accountCompanion(LocalAccount a) {
    return CrmAccountsCompanion(
      id: Value(a.id),
      name: Value(a.name),
      type: Value(a.type),
      industry: Value(a.industry),
      level: Value(a.level),
      source: Value(a.source),
      phone: Value(a.phone),
      email: Value(a.email),
      address: Value(a.address),
      website: Value(a.website),
      creditCode: Value(a.creditCode),
      note: Value(a.note),
      status: Value(a.status),
      createdAt: Value(a.createdAt),
      updatedAt: Value(a.updatedAt),
      deleted: Value(a.deleted),
    );
  }

  LocalAccount _accountFromRow(CrmAccountRow row) => LocalAccount(
    id: row.id,
    name: row.name,
    type: row.type,
    industry: row.industry,
    level: row.level,
    source: row.source,
    phone: row.phone,
    email: row.email,
    address: row.address,
    website: row.website,
    creditCode: row.creditCode,
    note: row.note,
    status: row.status,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmContactsCompanion _contactCompanion(LocalContact c) {
    return CrmContactsCompanion(
      id: Value(c.id),
      accountId: Value(c.accountId),
      name: Value(c.name),
      title: Value(c.title),
      department: Value(c.department),
      phone: Value(c.phone),
      email: Value(c.email),
      wechat: Value(c.wechat),
      isPrimary: Value(c.isPrimary),
      isDecisionMaker: Value(c.isDecisionMaker),
      note: Value(c.note),
      createdAt: Value(c.createdAt),
      updatedAt: Value(c.updatedAt),
      deleted: Value(c.deleted),
    );
  }

  LocalContact _contactFromRow(CrmContactRow row) => LocalContact(
    id: row.id,
    accountId: row.accountId,
    name: row.name,
    title: row.title,
    department: row.department,
    phone: row.phone,
    email: row.email,
    wechat: row.wechat,
    isPrimary: row.isPrimary,
    isDecisionMaker: row.isDecisionMaker,
    note: row.note,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmOpportunitiesCompanion _opportunityCompanion(LocalOpportunity o) {
    return CrmOpportunitiesCompanion(
      id: Value(o.id),
      name: Value(o.name),
      accountId: Value(o.accountId),
      contactId: Value(o.contactId),
      stage: Value(o.stage),
      probability: Value(o.probability),
      amount: Value(o.amount),
      currency: Value(o.currency),
      source: Value(o.source),
      leadContactName: Value(o.leadContactName),
      leadPhone: Value(o.leadPhone),
      leadEmail: Value(o.leadEmail),
      expectedCloseDate: Value(o.expectedCloseDate),
      actualCloseDate: Value(o.actualCloseDate),
      lossReason: Value(o.lossReason),
      note: Value(o.note),
      createdAt: Value(o.createdAt),
      updatedAt: Value(o.updatedAt),
      deleted: Value(o.deleted),
    );
  }

  LocalOpportunity _opportunityFromRow(CrmOpportunityRow row) =>
      LocalOpportunity(
        id: row.id,
        name: row.name,
        accountId: row.accountId,
        contactId: row.contactId,
        stage: row.stage,
        probability: row.probability,
        amount: row.amount,
        currency: row.currency,
        source: row.source,
        leadContactName: row.leadContactName,
        leadPhone: row.leadPhone,
        leadEmail: row.leadEmail,
        expectedCloseDate: row.expectedCloseDate,
        actualCloseDate: row.actualCloseDate,
        lossReason: row.lossReason,
        note: row.note,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
      );

  CrmContractsCompanion _contractCompanion(LocalContract c) {
    return CrmContractsCompanion(
      id: Value(c.id),
      contractNo: Value(c.contractNo),
      name: Value(c.name),
      accountId: Value(c.accountId),
      contactId: Value(c.contactId),
      opportunityId: Value(c.opportunityId),
      quoteId: Value(c.quoteId),
      status: Value(c.status),
      totalAmount: Value(c.totalAmount),
      paidAmount: Value(c.paidAmount),
      invoicedAmount: Value(c.invoicedAmount),
      signDate: Value(c.signDate),
      startDate: Value(c.startDate),
      endDate: Value(c.endDate),
      warrantyEndDate: Value(c.warrantyEndDate),
      note: Value(c.note),
      createdAt: Value(c.createdAt),
      updatedAt: Value(c.updatedAt),
      deleted: Value(c.deleted),
    );
  }

  LocalContract _contractFromRow(CrmContractRow row) => LocalContract(
    id: row.id,
    contractNo: row.contractNo,
    name: row.name,
    accountId: row.accountId,
    contactId: row.contactId,
    opportunityId: row.opportunityId,
    quoteId: row.quoteId,
    status: row.status,
    totalAmount: row.totalAmount,
    paidAmount: row.paidAmount,
    invoicedAmount: row.invoicedAmount,
    signDate: row.signDate,
    startDate: row.startDate,
    endDate: row.endDate,
    warrantyEndDate: row.warrantyEndDate,
    note: row.note,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmObjectDefsCompanion _objectDefCompanion(LocalCustomObject def) {
    return CrmObjectDefsCompanion(
      id: Value(def.id),
      labelSingular: Value(def.labelSingular),
      labelPlural: Value(def.labelPlural),
      icon: Value(def.icon),
      fieldsJson: Value(def.fields.map((f) => f.toJson()).toList()),
      builtin: Value(def.builtin),
      createdAt: Value(def.createdAt),
      updatedAt: Value(def.updatedAt),
    );
  }

  LocalCustomObject _objectDefFromRow(CrmObjectDefRow row) => LocalCustomObject(
    id: row.id,
    labelSingular: row.labelSingular,
    labelPlural: row.labelPlural,
    icon: row.icon,
    fields: row.fieldsJson
        .map((e) => CrmFieldDef.fromJson(e as Map<String, dynamic>))
        .toList(),
    builtin: row.builtin,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  CrmCustomRecordsCompanion _customRecordCompanion(LocalCustomRecord r) {
    return CrmCustomRecordsCompanion(
      id: Value(r.id),
      objectId: Value(r.objectId),
      label: Value(r.label),
      dataJson: Value(r.data),
      createdAt: Value(r.createdAt),
      updatedAt: Value(r.updatedAt),
      deleted: Value(r.deleted),
    );
  }

  LocalCustomRecord _customRecordFromRow(CrmCustomRecordRow row) =>
      LocalCustomRecord(
        id: row.id,
        objectId: row.objectId,
        label: row.label,
        data: row.dataJson,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
      );

  LocalEntityLink _linkFromRow(CrmEntityLinkRow row) => LocalEntityLink(
    id: row.id,
    entityType: row.entityType,
    entityId: row.entityId,
    localType: row.localType,
    localId: row.localId,
    relation: row.relation,
    createdAt: row.createdAt,
  );

  CrmProductsCompanion _productCompanion(LocalProduct p) {
    return CrmProductsCompanion(
      id: Value(p.id),
      categoryId: Value(p.categoryId),
      name: Value(p.name),
      sku: Value(p.sku),
      type: Value(p.type),
      unit: Value(p.unit),
      price: Value(p.price),
      cost: Value(p.cost),
      warrantyMonths: Value(p.warrantyMonths),
      isActive: Value(p.isActive),
      note: Value(p.note),
      createdAt: Value(p.createdAt),
      updatedAt: Value(p.updatedAt),
      deleted: Value(p.deleted),
    );
  }

  LocalProduct _productFromRow(CrmProductRow row) => LocalProduct(
    id: row.id,
    categoryId: row.categoryId,
    name: row.name,
    sku: row.sku ?? '',
    type: row.type,
    unit: row.unit,
    price: row.price,
    cost: row.cost,
    warrantyMonths: row.warrantyMonths,
    isActive: row.isActive,
    note: row.note,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmQuotesCompanion _quoteCompanion(LocalQuote q) {
    return CrmQuotesCompanion(
      id: Value(q.id),
      quoteNo: Value(q.quoteNo),
      opportunityId: Value(q.opportunityId),
      accountId: Value(q.accountId),
      contactId: Value(q.contactId),
      status: Value(q.status),
      totalAmount: Value(q.totalAmount),
      discountAmount: Value(q.discountAmount),
      validUntil: Value(q.validUntil),
      note: Value(q.note),
      createdAt: Value(q.createdAt),
      updatedAt: Value(q.updatedAt),
      deleted: Value(q.deleted),
    );
  }

  LocalQuote _quoteFromRow(CrmQuoteRow row) => LocalQuote(
    id: row.id,
    quoteNo: row.quoteNo,
    opportunityId: row.opportunityId,
    accountId: row.accountId,
    contactId: row.contactId,
    status: row.status,
    totalAmount: row.totalAmount,
    discountAmount: row.discountAmount,
    validUntil: row.validUntil,
    note: row.note,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmQuoteItemsCompanion _quoteItemCompanion(LocalQuoteItem i) {
    return CrmQuoteItemsCompanion(
      id: Value(i.id),
      quoteId: Value(i.quoteId),
      productId: Value(i.productId),
      productName: Value(i.productName),
      quantity: Value(i.quantity),
      unitPrice: Value(i.unitPrice),
      discount: Value(i.discount),
      amount: Value(i.amount),
      sortOrder: Value(i.sortOrder),
    );
  }

  LocalQuoteItem _quoteItemFromRow(CrmQuoteItemRow row) => LocalQuoteItem(
    id: row.id,
    quoteId: row.quoteId,
    productId: row.productId,
    productName: row.productName,
    quantity: row.quantity,
    unitPrice: row.unitPrice,
    discount: row.discount,
    amount: row.amount,
    sortOrder: row.sortOrder,
  );

  CrmContractItemsCompanion _contractItemCompanion(LocalContractItem i) {
    return CrmContractItemsCompanion(
      id: Value(i.id),
      contractId: Value(i.contractId),
      productId: Value(i.productId),
      productName: Value(i.productName),
      quantity: Value(i.quantity),
      unitPrice: Value(i.unitPrice),
      amount: Value(i.amount),
      warrantyMonths: Value(i.warrantyMonths),
      sortOrder: Value(i.sortOrder),
    );
  }

  LocalContractItem _contractItemFromRow(CrmContractItemRow row) =>
      LocalContractItem(
        id: row.id,
        contractId: row.contractId,
        productId: row.productId,
        productName: row.productName,
        quantity: row.quantity,
        unitPrice: row.unitPrice,
        amount: row.amount,
        warrantyMonths: row.warrantyMonths,
        sortOrder: row.sortOrder,
      );

  CrmPaymentPlansCompanion _paymentPlanCompanion(LocalPaymentPlan p) {
    return CrmPaymentPlansCompanion(
      id: Value(p.id),
      contractId: Value(p.contractId),
      planName: Value(p.planName),
      planAmount: Value(p.planAmount),
      paidAmount: Value(p.paidAmount),
      planDate: Value(p.planDate),
      status: Value(p.status),
    );
  }

  LocalPaymentPlan _paymentPlanFromRow(CrmPaymentPlanRow row) =>
      LocalPaymentPlan(
        id: row.id,
        contractId: row.contractId,
        planName: row.planName,
        planAmount: row.planAmount,
        paidAmount: row.paidAmount,
        planDate: row.planDate,
        status: row.status,
      );

  CrmPaymentsCompanion _paymentCompanion(LocalPayment p) {
    return CrmPaymentsCompanion(
      id: Value(p.id),
      contractId: Value(p.contractId),
      planId: Value(p.planId),
      amount: Value(p.amount),
      paymentDate: Value(p.paymentDate),
      method: Value(p.method),
      invoiceId: Value(p.invoiceId),
      note: Value(p.note),
      createdAt: Value(p.createdAt),
    );
  }

  LocalPayment _paymentFromRow(CrmPaymentRow row) => LocalPayment(
    id: row.id,
    contractId: row.contractId,
    planId: row.planId,
    amount: row.amount,
    paymentDate: row.paymentDate,
    method: row.method,
    invoiceId: row.invoiceId,
    note: row.note,
    createdAt: row.createdAt,
  );

  CrmInvoicesCompanion _invoiceCompanion(LocalInvoice i) {
    return CrmInvoicesCompanion(
      id: Value(i.id),
      contractId: Value(i.contractId),
      invoiceNo: Value(i.invoiceNo),
      type: Value(i.type),
      amount: Value(i.amount),
      taxRate: Value(i.taxRate),
      issueDate: Value(i.issueDate),
      status: Value(i.status),
      receiverName: Value(i.receiverName),
      note: Value(i.note),
      createdAt: Value(i.createdAt),
    );
  }

  LocalInvoice _invoiceFromRow(CrmInvoiceRow row) => LocalInvoice(
    id: row.id,
    contractId: row.contractId,
    invoiceNo: row.invoiceNo,
    type: row.type,
    amount: row.amount,
    taxRate: row.taxRate,
    issueDate: row.issueDate,
    status: row.status,
    receiverName: row.receiverName,
    note: row.note,
    createdAt: row.createdAt,
  );

  CrmWarrantiesCompanion _warrantyCompanion(LocalWarranty w) {
    return CrmWarrantiesCompanion(
      id: Value(w.id),
      contractId: Value(w.contractId),
      contractItemId: Value(w.contractItemId),
      productId: Value(w.productId),
      serialNo: Value(w.serialNo),
      startDate: Value(w.startDate),
      endDate: Value(w.endDate),
      status: Value(w.status),
      note: Value(w.note),
      createdAt: Value(w.createdAt),
    );
  }

  LocalWarranty _warrantyFromRow(CrmWarrantyRow row) => LocalWarranty(
    id: row.id,
    contractId: row.contractId,
    contractItemId: row.contractItemId,
    productId: row.productId,
    serialNo: row.serialNo,
    startDate: row.startDate,
    endDate: row.endDate,
    status: row.status,
    note: row.note,
    createdAt: row.createdAt,
  );

  CrmAfterSalesCompanion _afterSalesCompanion(LocalAfterSales t) {
    return CrmAfterSalesCompanion(
      id: Value(t.id),
      ticketNo: Value(t.ticketNo),
      accountId: Value(t.accountId),
      contactId: Value(t.contactId),
      contractId: Value(t.contractId),
      warrantyId: Value(t.warrantyId),
      type: Value(t.type),
      priority: Value(t.priority),
      status: Value(t.status),
      subject: Value(t.subject),
      description: Value(t.description),
      resolution: Value(t.resolution),
      resolvedAt: Value(t.resolvedAt),
      closedAt: Value(t.closedAt),
      note: Value(t.note),
      createdAt: Value(t.createdAt),
      updatedAt: Value(t.updatedAt),
      deleted: Value(t.deleted),
    );
  }

  LocalAfterSales _afterSalesFromRow(CrmAfterSalesRow row) => LocalAfterSales(
    id: row.id,
    ticketNo: row.ticketNo,
    accountId: row.accountId,
    contactId: row.contactId,
    contractId: row.contractId,
    warrantyId: row.warrantyId,
    type: row.type,
    priority: row.priority,
    status: row.status,
    subject: row.subject,
    description: row.description,
    resolution: row.resolution,
    resolvedAt: row.resolvedAt,
    closedAt: row.closedAt,
    note: row.note,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmActivitiesCompanion _activityCompanion(LocalActivity a) {
    return CrmActivitiesCompanion(
      id: Value(a.id),
      type: Value(a.type),
      direction: Value(a.direction),
      relatedType: Value(a.relatedType),
      relatedId: Value(a.relatedId),
      subject: Value(a.subject),
      content: Value(a.content),
      status: Value(a.status),
      scheduledAt: Value(a.scheduledAt),
      completedAt: Value(a.completedAt),
      createdAt: Value(a.createdAt),
    );
  }

  LocalActivity _activityFromRow(CrmActivityRow row) => LocalActivity(
    id: row.id,
    type: row.type,
    direction: row.direction,
    relatedType: row.relatedType,
    relatedId: row.relatedId,
    subject: row.subject,
    content: row.content,
    status: row.status,
    scheduledAt: row.scheduledAt,
    completedAt: row.completedAt,
    createdAt: row.createdAt,
  );

  CrmAttachmentsCompanion _attachmentCompanion(LocalAttachment a) {
    return CrmAttachmentsCompanion(
      id: Value(a.id),
      relatedType: Value(a.relatedType),
      relatedId: Value(a.relatedId),
      fileName: Value(a.fileName),
      filePath: Value(a.filePath),
      mimeType: Value(a.mimeType),
      fileSize: Value(a.fileSize),
      createdAt: Value(a.createdAt),
    );
  }

  LocalAttachment _attachmentFromRow(CrmAttachmentRow row) => LocalAttachment(
    id: row.id,
    relatedType: row.relatedType,
    relatedId: row.relatedId,
    fileName: row.fileName,
    filePath: row.filePath,
    mimeType: row.mimeType,
    fileSize: row.fileSize,
    createdAt: row.createdAt,
  );

  CrmRemindersCompanion _reminderCompanion(LocalReminder r) {
    return CrmRemindersCompanion(
      id: Value(r.id),
      relatedType: Value(r.relatedType),
      relatedId: Value(r.relatedId),
      type: Value(r.type),
      title: Value(r.title),
      remindAt: Value(r.remindAt),
      isCompleted: Value(r.isCompleted),
      createdAt: Value(r.createdAt),
    );
  }

  LocalReminder _reminderFromRow(CrmReminderRow row) => LocalReminder(
    id: row.id,
    relatedType: row.relatedType,
    relatedId: row.relatedId,
    type: row.type,
    title: row.title,
    remindAt: row.remindAt,
    isCompleted: row.isCompleted,
    createdAt: row.createdAt,
  );
}
