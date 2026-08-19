@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/isar.dart';

/// 真实 Twenty 环境集成测试（需内网可达 + config/twenty.local.json）：
///   flutter test --tags integration test/integration/twenty_integration_test.dart
void main() {
  late Isar isar;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('twenty_integration');
    isar = Isar.open(
      schemas: [CrmEntityCacheSchema],
      directory: tempDir.path,
    );
    IsarUtil.overrideIsarForTest(isar);
  });

  tearDownAll(() async {
    IsarUtil.restoreIsarForTest();
    isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
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
