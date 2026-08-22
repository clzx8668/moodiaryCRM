import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/local/crm_ai_assist.dart';
import 'package:moodiary/features/crm/local/crm_backup_codec.dart';
import 'package:moodiary/features/crm/local/crm_demo_data.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_pdf_export.dart';
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

  group('CrmAiAssist 文本提取', () {
    test('提取名称/金额/电话/邮箱/日期/阶段', () {
      final e = CrmAiAssist.extractFromText(
        '客户：星辰科技，跟进 CRM 专业版采购项目，预算 26 万元，'
        '联系人电话 13812345678，邮箱 zhang@demo.com，预计 2026-09-30 前赢单',
      );
      expect(e.name, contains('星辰科技'));
      expect(e.amount, 260000);
      expect(e.phone, '13812345678');
      expect(e.email, 'zhang@demo.com');
      expect(e.closeDate?.year, 2026);
      expect(e.stage, '赢单');
    });

    test('空文本返回空', () {
      expect(CrmAiAssist.extractFromText('').isEmpty, isTrue);
    });
  });

  test('PDF 字节生成（报价/合同/发票）', () async {
    await CrmDemoData.seed(repo);
    final quote = (await repo.listQuotes()).first;
    final quoteBytes = await CrmPdfExport.quotePdfBytes(repo, quote.id);
    expect(quoteBytes.length, greaterThan(100));
    expect(quoteBytes.take(4), [0x25, 0x50, 0x44, 0x46]); // %PDF

    final contract = (await repo.listContracts()).first;
    final contractBytes = await CrmPdfExport.contractPdfBytes(repo, contract.id);
    expect(contractBytes.length, greaterThan(100));

    final invoice = (await repo.listInvoices()).first;
    final invoiceBytes = await CrmPdfExport.invoicePdfBytes(repo, invoice.id);
    expect(invoiceBytes.length, greaterThan(100));
  });

  test('本地 CRM 备份导出/导入往返一致', () async {
    await CrmDemoData.seed(repo);
    final data = await CrmBackupCodec.exportAll(repo);
    expect(data['accounts'], isA<List>());
    expect((data['accounts'] as List).length, greaterThanOrEqualTo(5));
    expect((data['quotes'] as List).length, greaterThanOrEqualTo(5));

    // 导入到全新库
    final db2 = openTestDb();
    final repo2 = CrmLocalRepository(db2);
    await CrmBackupCodec.importAll(repo2, data);

    expect((await repo2.listAccounts()).length, (await repo.listAccounts()).length);
    expect((await repo2.listContacts()).length, (await repo.listContacts()).length);
    expect(
      (await repo2.listOpportunities()).length,
      (await repo.listOpportunities()).length,
    );
    expect((await repo2.listContracts()).length, (await repo.listContracts()).length);
    expect((await repo2.listQuotes()).length, (await repo.listQuotes()).length);
    expect((await repo2.listInvoices()).length, (await repo.listInvoices()).length);
    closeTestDb(db2);
  });
}
