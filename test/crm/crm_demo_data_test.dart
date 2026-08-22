import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/local/crm_demo_data.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;
  late CrmLocalRepository repo;

  setUp(() {
    db = openTestDb();
    repo = CrmLocalRepository(db);
  });

  tearDown(() {
    closeTestDb(db);
  });

  test('演示数据覆盖全部表且数量达标', () async {
    final counts = await CrmDemoData.seed(repo);

    const minByKey = {
      'account': 5,
      'contact': 5,
      'opportunity': 5,
      'contract': 5,
      'product': 5,
      'productCategory': 3,
      'quote': 5,
      'quoteItem': 5,
      'contractItem': 5,
      'paymentPlan': 5,
      'payment': 5,
      'invoice': 5,
      'warranty': 5,
      'afterSales': 5,
      'customObject': 1,
      'customRecord': 5,
    };
    for (final entry in minByKey.entries) {
      expect(
        counts[entry.key],
        greaterThanOrEqualTo(entry.value),
        reason: '${entry.key} 应至少 ${entry.value} 条，实际 ${counts[entry.key]}',
      );
    }
  });

  test('演示数据关系完整：报价转合同、冗余金额、单号', () async {
    await CrmDemoData.seed(repo);

    final contracts = await repo.listContracts();
    // 至少 2 条合同来自报价转合同且有明细
    final fromQuote = contracts.where((c) => c.quoteId != null).toList();
    expect(fromQuote.length, greaterThanOrEqualTo(2));
    for (final contract in fromQuote) {
      expect((await repo.contractItems(contract.id)).length, greaterThanOrEqualTo(2));
      expect(contract.totalAmount, greaterThan(0));
      expect(contract.contractNo, startsWith('HT-'));
    }

    // 合同已回款冗余与回款记录一致
    final contractsWithPayment = await repo.listContracts();
    var checked = 0;
    for (final contract in contractsWithPayment) {
      final payments = await repo.listPayments(contractId: contract.id);
      if (payments.isEmpty) continue;
      final sum = payments.fold<double>(0, (s, p) => s + p.amount);
      expect(contract.paidAmount, closeTo(sum, 0.001));
      checked++;
    }
    expect(checked, greaterThanOrEqualTo(1));

    // 发票冗余
    final invoices = await repo.listInvoices();
    expect(invoices.length, greaterThanOrEqualTo(5));

    // 自定义对象记录
    expect((await repo.listCustomRecords('visits')).length, greaterThanOrEqualTo(5));
  });
}
