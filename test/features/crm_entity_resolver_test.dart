import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/crm/resolve/crm_entity_resolver.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  test('精确名命中 → exact + id', () async {
    final repo = CrmLocalRepository();
    await repo.createAccount(LocalAccount(id: 'acc1', name: '星海科技'));
    final r = await CrmEntityResolver(repo).resolve(
      objectType: 'account',
      name: '星海科技',
    );
    expect(r.hasExact, isTrue);
    expect(r.best!.entityId, 'acc1');
    expect(r.best!.confidence, 1.0);
  });

  test('手机号唯一键命中（名字无匹配也能找到）', () async {
    final repo = CrmLocalRepository();
    await repo.createAccount(
      LocalAccount(id: 'acc1', name: '星海科技', phone: '13800000000'),
    );
    final r = await CrmEntityResolver(repo).resolve(
      objectType: 'account',
      name: '不存在的名字',
      phone: '13800000000',
    );
    expect(r.hasExact, isTrue);
    expect(r.best!.entityId, 'acc1');
  });

  test('包含关系 → fuzzy（高置信）、联系人可解析', () async {
    final repo = CrmLocalRepository();
    await repo.createAccount(LocalAccount(id: 'acc1', name: '星海科技'));
    await repo.createContact(
      LocalContact(id: 'ct1', name: '张伟', accountId: 'acc1'),
    );
    final ra = await CrmEntityResolver(repo).resolve(
      objectType: 'account',
      name: '星海',
    );
    expect(ra.hasExact, isFalse);
    expect(ra.best!.entityId, 'acc1');
    expect(ra.best!.level, CrmMatchLevel.fuzzy);

    final rc = await CrmEntityResolver(repo).resolve(
      objectType: 'contact',
      name: '张伟',
    );
    expect(rc.best!.entityId, 'ct1');
  });
}
