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

  test('公司 CRUD 与软删除', () async {
    final company = await repo.createCompany(
      LocalCompany(id: '', name: 'Notion', employees: 400),
    );
    expect(company.id, isNotEmpty);

    final list = await repo.listCompanies();
    expect(list, hasLength(1));
    expect(list.first.name, 'Notion');
    expect(list.first.employees, 400);

    company.name = 'Notion 中国';
    await repo.updateCompany(company);
    final updated = await repo.getCompany(company.id);
    expect(updated?.name, 'Notion 中国');

    await repo.deleteCompany(company.id);
    expect(await repo.listCompanies(), isEmpty);
    expect(await repo.countCompanies(), 0);
  });

  test('联系人关联公司与列表过滤', () async {
    final company = await repo.createCompany(LocalCompany(id: '', name: 'Acme'));
    await repo.createPerson(
      LocalPerson(id: '', firstName: '张', lastName: '三', companyId: company.id),
    );
    await repo.createPerson(
      LocalPerson(id: '', firstName: '李', lastName: '四'),
    );

    expect((await repo.listPeople()).length, 2);
    expect((await repo.peopleOfCompany(company.id)).length, 1);
    expect((await repo.listPeople(keyword: '张')).length, 1);
  });

  test('机会/合同 CRUD', () async {
    final opp = await repo.createOpportunity(
      LocalOpportunity(id: '', name: '新机会', amountMicros: 123000000),
    );
    expect(opp.amountMicros, 123000000);
    await repo.updateOpportunity(
      opp..stage = '赢单',
    );
    expect((await repo.getOpportunity(opp.id))?.stage, '赢单');

    final contract = await repo.createContract(
      LocalContract(id: '', name: '年度合同', amountMicros: 500000000),
    );
    expect((await repo.listContracts()).length, 1);
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
      entityType: 'company',
      entityId: 'c1',
      localType: 'diary',
      localId: 'd1',
      relation: 'followup',
    );
    await repo.linkEntity(
      entityType: 'company',
      entityId: 'c1',
      localType: 'block',
      localId: 'b1',
      relation: 'todo',
    );
    final links = await repo.linksForEntity('company', 'c1');
    expect(links, hasLength(2));

    await repo.unlinkEntity(
      entityType: 'company',
      entityId: 'c1',
      localType: 'diary',
      localId: 'd1',
    );
    expect((await repo.linksForEntity('company', 'c1')).length, 1);

    await repo.createCompany(LocalCompany(id: '', name: 'X'));
    final stats = await repo.stats();
    expect(stats['company'], 1);
    expect(stats['person'], 0);
  });
}
