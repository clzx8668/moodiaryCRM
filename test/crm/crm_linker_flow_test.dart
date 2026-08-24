import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/local/crm_entity_creator.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
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

  test('CrmEntityLinker：客户→联系人 / 联系人→客户 双向关联落库', () async {
    final account = await repo.createAccount(LocalAccount(id: '', name: 'Acme'));
    final contact = await repo.createContact(LocalContact(id: '', name: '张三'));

    // 客户侧挂联系人（父侧）
    await CrmEntityLinker.link(
      repo: repo,
      parentType: 'account',
      parentId: account.id,
      targetType: 'contact',
      targetId: contact.id,
    );
    expect((await repo.getContact(contact.id))?.accountId, account.id);

    // 联系人侧改挂另一客户（子侧覆盖）
    final account2 = await repo.createAccount(LocalAccount(id: '', name: 'Beta'));
    await CrmEntityLinker.link(
      repo: repo,
      parentType: 'account',
      parentId: account2.id,
      targetType: 'contact',
      targetId: contact.id,
    );
    expect((await repo.getContact(contact.id))?.accountId, account2.id);

    // 解除关联
    await CrmEntityLinker.link(
      repo: repo,
      parentType: 'account',
      parentId: '',
      targetType: 'contact',
      targetId: contact.id,
    );
    expect((await repo.getContact(contact.id))?.accountId, isNull);
  });

  test('CrmEntityLinker：机会↔报价/合同、合同↔回款/发票/质保', () async {
    final account = await repo.createAccount(LocalAccount(id: '', name: 'Acme'));
    final opp = await repo.createOpportunity(
      LocalOpportunity(id: '', name: '大单', accountId: account.id),
    );
    final quote = await repo.createQuote(LocalQuote(id: '', accountId: account.id));
    await CrmEntityLinker.link(
      repo: repo,
      parentType: 'opportunity',
      parentId: opp.id,
      targetType: 'quote',
      targetId: quote.id,
    );
    expect((await repo.getQuote(quote.id))?.opportunityId, opp.id);

    final contract = await repo.createContract(
      LocalContract(id: '', name: '合同A', accountId: account.id, opportunityId: opp.id),
    );
    final payment = await repo.createPayment(
      LocalPayment(id: '', contractId: contract.id, amount: 100),
    );
    await CrmEntityLinker.link(
      repo: repo,
      parentType: 'paymentPlan',
      parentId: 'plan-1',
      targetType: 'payment',
      targetId: payment.id,
    );
    expect((await repo.getPayment(payment.id))?.planId, 'plan-1');
  });

  test('createCrmEntity：新增记录直接带外键（新增表单保存链路）', () async {
    final account = await repo.createAccount(LocalAccount(id: '', name: 'Acme'));
    final contactId = await createCrmEntity(
      repo: repo,
      objectType: 'contact',
      data: {'name': '李四', 'accountId': account.id},
    );
    expect(contactId, isNotNull);
    expect((await repo.getContact(contactId!))?.accountId, account.id);

    final oppId = await createCrmEntity(
      repo: repo,
      objectType: 'opportunity',
      data: {'name': '机会B', 'accountId': account.id, 'stage': 'proposal'},
    );
    expect((await repo.getOpportunity(oppId!))?.accountId, account.id);
    expect((await repo.getOpportunity(oppId))?.stage, 'proposal');
  });

  test('CrmEntityFieldUpdater：外键字段写入（详情字段编辑链路）', () async {
    final account = await repo.createAccount(LocalAccount(id: '', name: 'Acme'));
    final contact = await repo.createContact(LocalContact(id: '', name: '王五'));
    await CrmEntityFieldUpdater.update(
      objectType: 'contact',
      id: contact.id,
      field: 'accountId',
      value: account.id,
    );
    expect((await repo.getContact(contact.id))?.accountId, account.id);
    await CrmEntityFieldUpdater.update(
      objectType: 'contact',
      id: contact.id,
      field: 'accountId',
      value: '',
    );
    expect((await repo.getContact(contact.id))?.accountId, isNull);
  });
}
