@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

/// 真实 Twenty 环境集成测试（需内网可达 + config/twenty.local.json）：
///   flutter test --tags integration test/integration/twenty_integration_test.dart
void main() {
  late AppDatabase db;

  setUpAll(() {
    db = openTestDb();
  });

  tearDownAll(() {
    closeTestDb(db);
  });

  test('连接测试 + 全量拉取 + 本地搜索 + 建删闭环', () async {
    final config = await TwentyConfig.loadLocal();
    expect(config.isConfigured, isTrue,
        reason: '请先配置 config/twenty.local.json');

    final service = CrmSyncService.fromConfig(config);

    final connection = await service.testConnection();
    expect(connection.ok, isTrue, reason: connection.message);

    final result = await service.fullPull();
    expect(result.totalPulled, greaterThanOrEqualTo(0));
    expect(result.pulledByObject.keys, containsAll(['company', 'person']));

    // 本地缓存应有数据（测试环境至少预置了公司样例）
    final companies = await IsarUtil.getCrmEntitiesByType('company');
    expect(companies, isNotEmpty);
    // 全字段拉取：快照应包含 Twenty 默认展示字段（address/xLink 等），
    // 保证 CRM 表格展示完整（含域名/员工数/年收入/客户状态等关键字段）
    const criticalFields = {
      'domainName',
      'address',
      'employees',
      'linkedinLink',
      'xLink',
      'annualRecurringRevenue',
      'customerstatus',
    };
    final present = criticalFields
        .where(companies.first.data.containsKey)
        .toList();
    expect(
      present.length,
      greaterThanOrEqualTo(3),
      reason: '公司快照应包含关键 CRM 字段（实际：${companies.first.data.keys}）',
    );

    // 联系人/机会关键字段同样完整
    final people = await IsarUtil.getCrmEntitiesByType('person');
    if (people.isNotEmpty) {
      const personCritical = {'jobTitle', 'city', 'wechat', 'emails', 'phones'};
      final personPresent = personCritical
          .where(people.first.data.containsKey)
          .toList();
      expect(
        personPresent,
        isNotEmpty,
        reason: '联系人快照应包含关键字段（实际：${people.first.data.keys}）',
      );
    }
    final opportunities = await IsarUtil.getCrmEntitiesByType('opportunity');
    if (opportunities.isNotEmpty) {
      const oppCritical = {'amount', 'closeDate', 'stage'};
      final oppPresent = oppCritical
          .where(opportunities.first.data.containsKey)
          .toList();
      expect(
        oppPresent,
        isNotEmpty,
        reason: '机会快照应包含关键字段（实际：${opportunities.first.data.keys}）',
      );
    }

    // 对账：全量拉取后本地与远端应基本一致
    final reconcile = await service.reconcile();
    expect(reconcile.totalDiff, lessThanOrEqualTo(2),
        reason: '全量拉取后对账差异应很小：$reconcile');

    // 创建 → 搜索 → 删除 闭环
    final name =
        'Moodiary集成测试-${DateTime.now().millisecondsSinceEpoch}';
    final created = await service.createCompany(name: name);
    expect(created.id, isNotEmpty);

    final found = await service.searchLocal(name);
    expect(found.any((e) => e.twentyId == created.id), isTrue,
        reason: '新建公司应出现在本地缓存');

    await service.deleteCompany(created.id);
    final afterDelete = await IsarUtil.getCrmEntityByTwentyId(created.id);
    expect(afterDelete, isNull, reason: '删除后本地缓存应清理');
  });
}
