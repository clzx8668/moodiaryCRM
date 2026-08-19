import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/app_metadata.dart' as app_meta;
import 'package:moodiary/features/block/models/block.dart' as block_model;
import 'package:moodiary/persistence/migration.dart';

void main() {
  late Isar isar;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_test');
    isar = Isar.open(
      schemas: [
        DiarySchema,
        block_model.BlockSchema,
        app_meta.AppMetadataSchema,
      ],
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
    expect(b1.blockType, block_model.BlockType.text);
    expect(b1.content, '今天写代码');
    expect(b1.sortOrder, 0);
    expect(b1.createdAt, DateTime(2026, 1, 1, 12, 0));

    // db_version 已更新到当前版本
    expect(
      await MigrationService.getDbVersion(isar),
      MigrationService.currentDbVersion,
    );
    // 迁移历史已记录（v1→v2 与 v2→v3 两条）
    final history = await MigrationService.getMigrationHistory(isar);
    expect(history, hasLength(2));
    expect(history.first['from'], 1);
    expect(history.first['to'], 2);
    expect(history.last['from'], 2);
    expect(history.last['to'], 3);
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
        block_model.Block()
          ..id = 'existing'
          ..diaryId = 'd1'
          ..content = '已存在'
          ..blockType = block_model.BlockType.text,
      );
    });

    final result = await MigrationService.run(isar);

    expect(result.migratedDiaries, 0);
    expect(await isar.blocks.where().countAsync(), 1);
    expect(await MigrationService.getDbVersion(isar), MigrationService.currentDbVersion);
  });

  test('空 contentText 回退到 content', () async {
    isar.write((isar) {
      isar.diarys.put(makeOldDiary(id: 'd1', contentText: '', content: '原始'));
    });

    await MigrationService.run(isar);

    final block = await isar.blocks.where().diaryIdEqualTo('d1').findFirstAsync();
    expect(block!.content, '原始');
  });

  test('v2→v3：Delta 内容转换为 Markdown 并同步 Block', () async {
    await MigrationService.setDbVersion(isar, 2);
    final delta = jsonEncode([
      {'insert': '标题'},
      {'insert': '\n', 'attributes': {'header': 1}},
      {'insert': '重点', 'attributes': {'bold': true}},
      {'insert': '\n'},
      {'insert': {'image': 'image-abc.jpg'}},
      {'insert': '\n'},
    ]);
    isar.write((isar) {
      isar.diarys.put(
        makeOldDiary(id: 'd1', contentText: '', content: delta),
      );
    });
    isar.write((isar) {
      isar.blocks.put(
        block_model.Block()
          ..id = 'blk1'
          ..diaryId = 'd1'
          ..blockType = block_model.BlockType.text
          ..content = '旧内容'
          ..sortOrder = 0,
      );
    });

    final result = await MigrationService.run(isar);

    expect(result.migratedDiaries, 1);
    final diary = isar.diarys.get(fastHash('d1'));
    expect(diary!.type, 'markdown');
    expect(diary.content, contains('# 标题'));
    expect(diary.content, contains('**重点**'));
    expect(diary.content, contains('![](image-abc.jpg)'));

    final block = await isar.blocks.where().diaryIdEqualTo('d1').findFirstAsync();
    expect(block!.content, contains('# 标题'));
    expect(
      await MigrationService.getDbVersion(isar),
      MigrationService.currentDbVersion,
    );
  });

  test('v2→v3：已是 Markdown 的日记跳过', () async {
    await MigrationService.setDbVersion(isar, 2);
    isar.write((isar) {
      isar.diarys.put(
        makeOldDiary(id: 'd1', contentText: '纯文本', content: '# 已迁移'),
      );
    });
    // 直接标记为 markdown
    isar.write((isar) {
      final diary = isar.diarys.get(fastHash('d1'))!;
      diary.type = 'markdown';
      isar.diarys.put(diary);
    });

    final result = await MigrationService.run(isar);
    expect(result.migratedDiaries, 0);
    final diary = isar.diarys.get(fastHash('d1'));
    expect(diary!.content, '# 已迁移');
    expect(diary.type, 'markdown');
  });
}
