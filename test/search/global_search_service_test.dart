import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/search/global_search_service.dart';
import 'package:moodiary/persistence/isar.dart';

void main() {
  late Isar isar;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('global_search');
    isar = Isar.open(
      schemas: [DiarySchema, BlockSchema, CrmEntityCacheSchema],
      directory: tempDir.path,
    );
    IsarUtil.overrideIsarForTest(isar);
  });

  tearDown(() async {
    IsarUtil.restoreIsarForTest();
    isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('跨模块搜索：日记 + Block + CRM', () async {
    // 日记
    final diary = Diary()
      ..id = 'd1'
      ..title = '周报'
      ..contentText = '本周完成了 Twenty CRM 同步'
      ..type = 'text'
      ..time = DateTime(2026, 8, 19)
      ..show = true;
    // Block
    final block = Block()
      ..id = 'b1'
      ..diaryId = 'd1'
      ..blockType = BlockType.text
      ..content = '快速收集：Twenty CRM 集成'
      ..createdAt = DateTime(2026, 8, 19)
      ..updatedAt = DateTime(2026, 8, 19);
    // CRM 缓存
    final crm = CrmEntityCache()
      ..twentyId = 't1'
      ..entityType = 'company'
      ..name = 'Twenty 测试客户'
      ..setData({'id': 't1', 'name': 'Twenty 测试客户'})
      ..updatedAt = DateTime(2026, 8, 19);

    isar.write((isar) {
      isar.diarys.put(diary);
      isar.blocks.put(block);
      isar.crmEntityCaches.put(crm);
    });

    final results = await GlobalSearchService.search('Twenty');

    expect(results.length, greaterThanOrEqualTo(3));
    final types = results.map((r) => r.type).toSet();
    expect(types, containsAll(['diary', 'block', 'crm']));
    final crmResult = results.firstWhere((r) => r.type == 'crm');
    expect(crmResult.title, 'Twenty 测试客户');
    expect(crmResult.id, 't1');
  });

  test('空关键词返回空结果', () async {
    expect(await GlobalSearchService.search('   '), isEmpty);
  });
}
