import 'crm_local_repository.dart';
import 'crm_models.dart';

/// 创建本地 CRM 实体（含自定义对象），返回新记录 id。
/// 表格新增、关联新增、移动端新增共用同一实现。
Future<String?> createCrmEntity({
  required CrmLocalRepository repo,
  required String objectType,
  required Map<String, dynamic> data,
}) async {
  switch (objectType) {
    case 'account':
      final a = await repo.createAccount(
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
      return a.id;
    case 'contact':
      final c = await repo.createContact(
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
      return c.id;
    case 'opportunity':
      final o = await repo.createOpportunity(
        LocalOpportunity(
          id: '',
          name: data['name']?.toString() ?? '',
          stage: data['stage']?.toString() ?? 'newLead',
          probability: _toInt(data['probability']) ?? 0,
          amount: _toDouble(data['amount']) ?? 0,
          currency:
              data['currency']?.toString() ??
              data['amountCurrency']?.toString() ??
              'CNY',
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
      return o.id;
    case 'contract':
      final c = await repo.createContract(
        LocalContract(
          id: '',
          contractNo: data['contractNo']?.toString() ?? '',
          name: data['name']?.toString() ?? '',
          status: data['status']?.toString() ?? '',
          currency:
              data['totalAmountCurrency']?.toString() ??
              data['currency']?.toString() ??
              'CNY',
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
      return c.id;
    case 'product':
      final p = await repo.createProduct(
        LocalProduct(
          id: '',
          name: data['name']?.toString() ?? '',
          sku: data['sku']?.toString() ?? '',
          type: data['type']?.toString() ?? 'product',
          unit: data['unit']?.toString() ?? '',
          currency:
              data['priceCurrency']?.toString() ??
              data['currency']?.toString() ??
              'CNY',
          price: _toDouble(data['price']) ?? 0,
          cost: _toDouble(data['cost']) ?? 0,
          warrantyMonths: _toInt(data['warrantyMonths']) ?? 0,
          isActive: data['isActive']?.toString() != 'false',
          note: data['note']?.toString() ?? '',
        ),
      );
      return p.id;
    case 'quote':
      final q = await repo.createQuote(
        LocalQuote(
          id: '',
          status: data['status']?.toString() ?? 'draft',
          currency:
              data['totalAmountCurrency']?.toString() ??
              data['currency']?.toString() ??
              'CNY',
          totalAmount: _toDouble(data['totalAmount']) ?? 0,
          discountAmount: _toDouble(data['discountAmount']) ?? 0,
          validUntil: _parseDate(data['validUntil']),
          note: data['note']?.toString() ?? '',
        ),
      );
      return q.id;
    case 'paymentPlan':
      final p = await repo.createPaymentPlan(
        LocalPaymentPlan(
          id: '',
          contractId: '',
          planName: data['planName']?.toString() ?? '',
          planAmount: _toDouble(data['planAmount']) ?? 0,
          planDate: _parseDate(data['planDate']) ?? DateTime.now(),
          status: data['status']?.toString() ?? 'pending',
        ),
      );
      return p.id;
    case 'payment':
      final p = await repo.createPayment(
        LocalPayment(
          id: '',
          contractId: '',
          amount: _toDouble(data['amount']) ?? 0,
          currency:
              data['amountCurrency']?.toString() ??
              data['currency']?.toString() ??
              'CNY',
          paymentDate: _parseDate(data['paymentDate']) ?? DateTime.now(),
          method: data['method']?.toString() ?? 'transfer',
          note: data['note']?.toString() ?? '',
        ),
      );
      return p.id;
    case 'invoice':
      final i = await repo.createInvoice(
        LocalInvoice(
          id: '',
          contractId: '',
          invoiceNo: data['invoiceNo']?.toString() ?? '',
          type: data['type']?.toString() ?? 'vat_normal',
          amount: _toDouble(data['amount']) ?? 0,
          currency:
              data['amountCurrency']?.toString() ??
              data['currency']?.toString() ??
              'CNY',
          taxRate: _toDouble(data['taxRate']) ?? 0.13,
          issueDate: _parseDate(data['issueDate']),
          status: data['status']?.toString() ?? 'pending',
          receiverName: data['receiverName']?.toString() ?? '',
          note: data['note']?.toString() ?? '',
        ),
      );
      return i.id;
    case 'warranty':
      final w = await repo.createWarranty(
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
      return w.id;
    case 'afterSales':
      final t = await repo.createAfterSales(
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
      return t.id;
    case 'activity':
      final a = await repo.createActivity(
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
      return a.id;
    case 'reminder':
      final r = await repo.createReminder(
        LocalReminder(
          id: '',
          title: data['title']?.toString() ?? '',
          type: data['type']?.toString() ?? 'custom',
          remindAt: _parseDate(data['remindAt']) ?? DateTime.now(),
          isCompleted: data['isCompleted']?.toString() == 'true',
        ),
      );
      return r.id;
    default:
      final objectId = objectType.startsWith('custom:')
          ? objectType.substring(7)
          : objectType;
      final r = await repo.createCustomRecord(
        LocalCustomRecord(
          id: '',
          objectId: objectId,
          label: data['name']?.toString() ?? '',
          data: data,
        ),
      );
      return r.id;
  }
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
