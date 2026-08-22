import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
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

  test('客户 Account CRUD 与软删除', () async {
    final account = await repo.createAccount(
      LocalAccount(id: '', name: 'Notion', type: 'company', industry: '软件'),
    );
    expect(account.id, isNotEmpty);

    final list = await repo.listAccounts();
    expect(list, hasLength(1));
    expect(list.first.name, 'Notion');
    expect(list.first.industry, '软件');

    account.name = 'Notion 中国';
    await repo.updateAccount(account);
    expect((await repo.getAccount(account.id))?.name, 'Notion 中国');

    await repo.deleteAccount(account.id);
    expect(await repo.listAccounts(), isEmpty);
    expect(await repo.countAccounts(), 0);
  });

  test('联系人 Contact 从属客户与列表过滤', () async {
    final account = await repo.createAccount(LocalAccount(id: '', name: 'Acme'));
    await repo.createContact(
      LocalContact(id: '', name: '张三', accountId: account.id, title: '销售'),
    );
    await repo.createContact(LocalContact(id: '', name: '李四'));

    expect((await repo.listContacts()).length, 2);
    expect((await repo.contactsOfAccount(account.id)).length, 1);
    expect((await repo.listContacts(keyword: '张')).length, 1);
  });

  test('机会 Opportunity 阶段/金额 CRUD', () async {
    final opp = await repo.createOpportunity(
      LocalOpportunity(
        id: '',
        name: '新机会',
        stage: '新线索',
        probability: 30,
        amount: 123000,
      ),
    );
    expect(opp.amount, 123000);
    await repo.updateOpportunity(opp..stage = '赢单');
    expect((await repo.getOpportunity(opp.id))?.stage, '赢单');
    expect((await repo.getOpportunity(opp.id))?.probability, 30);
  });

  test('合同 Contract CRUD 与冗余金额', () async {
    final contract = await repo.createContract(
      LocalContract(
        id: '',
        contractNo: 'HT-20260822-001',
        name: '年度合同',
        totalAmount: 500000,
      ),
    );
    contract.paidAmount = 200000;
    contract.invoicedAmount = 150000;
    await repo.updateContract(contract);
    final loaded = await repo.getContract(contract.id);
    expect(loaded?.paidAmount, 200000);
    expect(loaded?.invoicedAmount, 150000);
    expect((await repo.listContracts(keyword: 'HT-20260822')).length, 1);
    await repo.deleteContract(contract.id);
    expect(await repo.listContracts(), isEmpty);
  });

  test('自定义对象定义与记录', () async {
    final def = await repo.createCustomObject(
      LocalCustomObject(
        id: 'payments',
        labelSingular: '回款',
        labelPlural: '回款记录',
        fields: const [
          CrmFieldDef(name: 'amount', label: '金额', type: 'number'),
          CrmFieldDef(name: 'receivedAt', label: '到账日期', type: 'date'),
        ],
      ),
    );
    expect((await repo.listCustomObjects()).length, 1);

    final record = await repo.createCustomRecord(
      LocalCustomRecord(
        id: '',
        objectId: def.id,
        label: '第一笔回款',
        data: {'amount': 100000, 'receivedAt': '2026-08-22'},
      ),
    );
    final records = await repo.listCustomRecords(def.id);
    expect(records, hasLength(1));
    expect(records.first.label, '第一笔回款');
    expect(records.first.data['amount'], 100000);

    await repo.deleteCustomRecord(record.id);
    expect(await repo.listCustomRecords(def.id), isEmpty);
  });

  test('实体 ↔ 内容关联 与统计', () async {
    await repo.linkEntity(
      entityType: 'account',
      entityId: 'a1',
      localType: 'diary',
      localId: 'd1',
      relation: 'followup',
    );
    await repo.linkEntity(
      entityType: 'account',
      entityId: 'a1',
      localType: 'block',
      localId: 'b1',
      relation: 'todo',
    );
    expect((await repo.linksForEntity('account', 'a1')).length, 2);

    await repo.unlinkEntity(
      entityType: 'account',
      entityId: 'a1',
      localType: 'diary',
      localId: 'd1',
    );
    expect((await repo.linksForEntity('account', 'a1')).length, 1);

    await repo.createAccount(LocalAccount(id: '', name: 'X'));
    final stats = await repo.stats();
    expect(stats['account'], 1);
    expect(stats['contact'], 0);
  });

  test('产品与分类 CRUD + SKU 唯一', () async {
    await repo.createProductCategory(
      LocalProductCategory(id: '', name: '软件'),
    );
    await repo.createProduct(
      LocalProduct(id: '', name: 'CRM 基础版', sku: 'CRM-BASIC', price: 999),
    );
    await expectLater(
      repo.createProduct(
        LocalProduct(id: '', name: '重复', sku: 'CRM-BASIC'),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect((await repo.listProducts(keyword: 'CRM')).length, 1);
    expect((await repo.listProductCategories()).length, 1);
  });

  test('报价单号生成与明细合计', () async {
    final quote = await repo.createQuote(LocalQuote(id: ''));
    expect(quote.quoteNo, startsWith('QT-'));
    expect(quote.quoteNo.length, 'QT-20260822-001'.length);

    await repo.addQuoteItem(
      LocalQuoteItem(
        id: '',
        quoteId: quote.id,
        productName: 'A',
        quantity: 2,
        unitPrice: 100,
        discount: 0.9,
      ),
    );
    await repo.addQuoteItem(
      LocalQuoteItem(
        id: '',
        quoteId: quote.id,
        productName: 'B',
        quantity: 1,
        unitPrice: 50,
      ),
    );
    final loaded = await repo.getQuote(quote.id);
    expect(loaded?.totalAmount, closeTo(230, 0.001)); // 2*100*0.9 + 50
    expect((await repo.quoteItems(quote.id)).length, 2);
  });

  test('报价转合同：明细快照 + 幂等', () async {
    final quote = await repo.createQuote(LocalQuote(id: '', status: 'accepted'));
    await repo.addQuoteItem(
      LocalQuoteItem(
        id: '',
        quoteId: quote.id,
        productName: '实施服务',
        quantity: 1,
        unitPrice: 8000,
      ),
    );

    final contract = await repo.quoteToContract(quote.id);
    expect(contract.contractNo, startsWith('HT-'));
    expect(contract.quoteId, quote.id);
    expect(contract.totalAmount, closeTo(8000, 0.001));
    final items = await repo.contractItems(contract.id);
    expect(items, hasLength(1));
    expect(items.first.productName, '实施服务');

    // 幂等：再次转换返回同一合同
    final again = await repo.quoteToContract(quote.id);
    expect(again.id, contract.id);

    // 非 accepted 报价不可转
    final draft = await repo.createQuote(LocalQuote(id: '', status: 'draft'));
    await expectLater(
      repo.quoteToContract(draft.id),
      throwsA(isA<StateError>()),
    );
  });
}
