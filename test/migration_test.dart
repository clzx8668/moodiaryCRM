import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/app_metadata.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/migration.dart';

void main() {
  late Isar isar;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_test');
    isar = Isar.open(
      schemas: [DiarySchema, BlockSchema, AppMetadataSchema],
      directory: tempDir.path,
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Diary makeOldDiary({
    required String id,
    required String contentText,
    required String content,
  }) {
    return Diary()
      ..id = id
      ..content = content
      ..contentText = contentText
      ..time = DateTime(2026, 1, 1, 12, 0)
      ..lastModified = DateTime(2026, 1, 1, 12, 0)
      ..type = 'richText';
  }

  test('v1 库迁移：每条旧日记生成一条 text Block', () async {
    isar.write((isar) {
      isar.diarys.putAll([
        makeOldDiary(id: 'd1', contentText: '今天写代码', content: '{"op":"old"}'),
        makeOldDiary(id: 'd2', contentText: '周末爬山', content: '{"op":"old2"}'),
      ]);
    });

    final result = await MigrationService.run(isar);

    expect(result.noop, isFalse);
    expect(result.migratedDiaries, 2);

    final blocks = await isar.blocks.where().findAllAsync();
    expect(blocks.length, 2);

    final b1 = blocks.firstWhere((b) => b.diaryId == 'd1');
    expect(b1.blockType, BlockType.text);
    expect(b1.content, '今天写代码');
    expect(b1.sortOrder, 0);
    expect(b1.createdAt, DateTime(2026, 1, 1, 12, 0));

    // db_version 已更新
    expect(await MigrationService.getDbVersion(isar), 2);
    // 迁移历史已记录
    final history = await MigrationService.getMigrationHistory(isar);
    expect(history, hasLength(1));
    expect(history.first['from'], 1);
    expect(history.first['to'], 2);
  });

  test('迁移幂等：重复运行不产生重复 Block', () async {
    isar.write((isar) {
      isar.diarys.put(makeOldDiary(id: 'd1', contentText: '内容', content: 'x'));
    });

    final first = await MigrationService.run(isar);
    final second = await MigrationService.run(isar);

    expect(first.migratedDiaries, 1);
    // 第二次是 noop，不重复迁移
    expect(second.noop, isTrue);
    expect(await isar.blocks.where().countAsync(), 1);
  });

  test('已存在 Block 的日记在迁移时被跳过', () async {
    isar.write((isar) {
      isar.diarys.put(makeOldDiary(id: 'd1', contentText: '旧', content: 'x'));
    });
    // 模拟部分迁移过的状态：d1 已有 Block，但 db_version 仍为 1
    isar.write((isar) {
      isar.blocks.put(
        Block()
          ..id = 'existing'
          ..diaryId = 'd1'
          ..content = '已存在'
          ..blockType = BlockType.text,
      );
    });

    final result = await MigrationService.run(isar);

    expect(result.migratedDiaries, 0);
    expect(await isar.blocks.where().countAsync(), 1);
    expect(await MigrationService.getDbVersion(isar), 2);
  });

  test('空 contentText 回退到 content', () async {
    isar.write((isar) {
      isar.diarys.put(makeOldDiary(id: 'd1', contentText: '', content: '原始'));
    });

    await MigrationService.run(isar);

    final block = await isar.blocks.where().diaryIdEqualTo('d1').findFirstAsync();
    expect(block!.content, '原始');
  });
}
