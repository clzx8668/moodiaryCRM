@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/crm_content_sync_service.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_content_link.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

/// 内容同步真实环境集成测试：
///   推送笔记/待办 → 客户时间线关联 → 通用表 → 认领 → 清理
/// 运行：flutter test --tags integration --run-skipped test/integration/twenty_content_integration_test.dart
void main() {
  late AppDatabase db;
  late CrmContentSyncService content;
  late CrmSyncService crm;
  final createdRemoteIds = <String>[];
  var companyId = '';

  setUpAll(() async {
    db = openTestDb();
    final config = await TwentyConfig.loadLocal();
    content = CrmContentSyncService.fromConfig(config);
    crm = CrmSyncService.fromConfig(config);

    // 建一家测试公司用于关联
    final name = 'Moodiary内容测试-${DateTime.now().millisecondsSinceEpoch}';
    final company = await crm.createCompany(name: name);
    companyId = company.id;
  });

  tearDownAll(() async {
    // 清理：删除全部远端 note/task/generic + 关联目标 + 测试公司
    try {
      for (final link in await IsarUtil.getCrmContentLinks()) {
        if (link.remoteId.isNotEmpty) {
          try {
            await content.deleteRemote(link);
          } catch (_) {}
        }
      }
      for (final entry in [
        ('noteTarget', 'noteId'),
        ('taskTarget', 'taskId'),
      ]) {
        try {
          final targets = await content.client.listAll(
            object: entry.$1,
            fields: ['id', entry.$2],
          );
          for (final t in targets) {
            if (createdRemoteIds.contains(t.data[entry.$2]?.toString())) {
              await content.client.delete(object: entry.$1, id: t.id);
            }
          }
        } catch (_) {}
      }
      if (companyId.isNotEmpty) {
        await crm.deleteCompany(companyId);
      }
    } finally {
      closeTestDb(db);
    }
  });

  test('笔记/待办推送 + 客户时间线关联 + 通用表认领 全链路', () async {
    // 1) 有客户关联的笔记 → note + noteTarget（客户时间线）
    final noteDiary = Diary()
      ..id = 'int-note-${DateTime.now().millisecondsSinceEpoch}'
      ..type = 'markdown'
      ..title = 'Moodiary 集成测试-关联笔记'
      ..contentText = '这是一条用于集成测试的笔记内容'
      ..time = DateTime.now()
      ..lastModified = DateTime.now();
    await IsarUtil.insertADiary(noteDiary);

    final noteLink = await content.pushDiary(
      noteDiary,
      targetEntityType: 'company',
      targetId: companyId,
    );
    expect(noteLink.remoteType, CrmContentLink.remoteTypeNote);
    expect(noteLink.isLinked, isTrue);
    expect(noteLink.targetId, companyId);
    createdRemoteIds.add(noteLink.remoteId);

    // 2) 有客户关联的待办 → task + taskTarget
    final todoDiary = Diary()
      ..id = 'int-todo-${DateTime.now().millisecondsSinceEpoch}'
      ..type = 'markdown'
      ..title = 'Moodiary 集成测试-关联待办'
      ..time = DateTime.now()
      ..lastModified = DateTime.now();
    await IsarUtil.insertADiary(todoDiary);
    final todoBlock = Block()
      ..id = 'int-block-${DateTime.now().millisecondsSinceEpoch}'
      ..diaryId = todoDiary.id
      ..blockType = BlockType.todo
      ..content = '- [ ] 集成测试待办项';
    await IsarUtil.insertBlock(todoBlock);

    final taskLink = await content.pushTodoBlock(
      todoBlock,
      targetEntityType: 'company',
      targetId: companyId,
    );
    expect(taskLink.remoteType, CrmContentLink.remoteTypeTask);
    expect(taskLink.isLinked, isTrue);
    createdRemoteIds.add(taskLink.remoteId);

    // 3) 无关联笔记 → 通用数据表 moodiaryGeneric
    final genericDiary = Diary()
      ..id = 'int-generic-${DateTime.now().millisecondsSinceEpoch}'
      ..type = 'markdown'
      ..title = 'Moodiary通用${DateTime.now().millisecondsSinceEpoch}'
      ..contentText = '未关联内容，应落入通用数据表'
      ..time = DateTime.now()
      ..lastModified = DateTime.now();
    await IsarUtil.insertADiary(genericDiary);

    final genericLink = await content.pushDiary(genericDiary);
    expect(genericLink.remoteType, CrmContentLink.remoteTypeGeneric);
    expect(genericLink.isGeneric, isTrue);

    // 4) 认领：通用记录 → 升级 note + target，通用记录被删除
    final claimed = await content.claimAssociation(
      genericLink,
      targetEntityType: 'company',
      targetId: companyId,
    );
    expect(claimed.remoteType, CrmContentLink.remoteTypeNote);
    expect(claimed.isLinked, isTrue);
    createdRemoteIds.add(claimed.remoteId);

    // 5) 远端可拉取到笔记（含刚推送/认领的）
    final notes = await content.client.listNotes();
    final remoteTitles = notes.map((n) => n.data['title']?.toString()).toSet();
    expect(remoteTitles, contains('Moodiary 集成测试-关联笔记'));
  });
}
