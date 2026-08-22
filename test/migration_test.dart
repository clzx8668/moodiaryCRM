import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/block/models/block.dart' as block_model;
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/migration.dart';

import 'helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDb();
  });

  tearDown(() {
    closeTestDb(db);
  });

  Future<void> insertDiary({
    required String id,
    required String content,
    String contentText = '',
    String type = 'richText',
  }) async {
    final now = DateTime(2026, 1, 1, 12, 0);
    await db.into(db.diaries).insert(
      DiariesCompanion.insert(
        id: id,
        content: Value(content),
        contentText: Value(contentText),
        type: Value(type),
        time: now,
        lastModified: now,
      ),
    );
  }

  test('v1 库迁移：每条旧日记生成一条 text Block', () async {
    await insertDiary(id: 'd1', contentText: '今天写代码', content: '{"op":"old"}');
    await insertDiary(id: 'd2', contentText: '周末爬山', content: '{"op":"old2"}');

    final result = await MigrationService.run(db);

    expect(result.noop, isFalse);
    expect(result.migratedDiaries, 2);

    final blocks = await db.select(db.blocks).get();
    expect(blocks.length, 2);

    final b1 = blocks.firstWhere((b) => b.diaryId == 'd1');
    expect(b1.blockType, block_model.BlockType.text.value);
    expect(b1.content, '今天写代码');
    expect(b1.sortOrder, 0);

    expect(
      await MigrationService.getDbVersion(db),
      MigrationService.currentDbVersion,
    );
    final history = await MigrationService.getMigrationHistory(db);
    expect(history, hasLength(12));
    expect(history.first['from'], 1);
    expect(history.first['to'], 2);
    expect(history[1]['to'], 3);
    expect(history[2]['from'], 3);
    expect(history[2]['to'], 4);
    expect(history[3]['from'], 4);
    expect(history[3]['to'], 5);
    expect(history[4]['from'], 5);
    expect(history[4]['to'], 6);
    expect(history[5]['from'], 6);
    expect(history[5]['to'], 7);
    expect(history[6]['from'], 7);
    expect(history[6]['to'], 8);
    expect(history[7]['from'], 8);
    expect(history[7]['to'], 9);
    expect(history[8]['from'], 9);
    expect(history[8]['to'], 10);
    expect(history[9]['from'], 10);
    expect(history[9]['to'], 11);
    expect(history[10]['from'], 11);
    expect(history[10]['to'], 12);
    expect(history.last['from'], 12);
    expect(history.last['to'], 13);
  });

  test('迁移幂等：重复运行不产生重复 Block', () async {
    await insertDiary(id: 'd1', contentText: '内容', content: 'x');

    final first = await MigrationService.run(db);
    final second = await MigrationService.run(db);

    expect(first.migratedDiaries, 1);
    expect(second.noop, isTrue);
    expect(await db.select(db.blocks).get(), hasLength(1));
  });

  test('已存在 Block 的日记在迁移时被跳过', () async {
    await insertDiary(id: 'd1', contentText: '旧', content: 'x');
    await db.into(db.blocks).insert(
      BlocksCompanion.insert(
        id: 'existing',
        diaryId: 'd1',
        blockType: block_model.BlockType.text.value,
        content: const Value('已存在'),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    final result = await MigrationService.run(db);

    expect(result.migratedDiaries, 0);
    expect(await db.select(db.blocks).get(), hasLength(1));
    expect(
      await MigrationService.getDbVersion(db),
      MigrationService.currentDbVersion,
    );
  });

  test('v2→v3：Delta 内容转换为 Markdown 并同步 Block', () async {
    await MigrationService.setDbVersion(db, 2);
    final delta = jsonEncode([
      {'insert': '标题'},
      {'insert': '\n', 'attributes': {'header': 1}},
      {'insert': '重点', 'attributes': {'bold': true}},
      {'insert': '\n'},
      {'insert': {'image': 'image-abc.jpg'}},
      {'insert': '\n'},
    ]);
    await insertDiary(id: 'd1', contentText: '', content: delta);
    await db.into(db.blocks).insert(
      BlocksCompanion.insert(
        id: 'blk1',
        diaryId: 'd1',
        blockType: block_model.BlockType.text.value,
        content: const Value('旧内容'),
        sortOrder: const Value(0),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    final result = await MigrationService.run(db);

    expect(result.migratedDiaries, 1);
    final diary = await (db.select(db.diaries)..where((t) => t.id.equals('d1')))
        .getSingle();
    expect(diary.type, 'markdown');
    expect(diary.content, contains('# 标题'));
    expect(diary.content, contains('**重点**'));
    expect(diary.content, contains('![](image-abc.jpg)'));

    final block = await (db.select(db.blocks)..where((t) => t.id.equals('blk1')))
        .getSingle();
    expect(block.content, contains('# 标题'));
    expect(
      await MigrationService.getDbVersion(db),
      MigrationService.currentDbVersion,
    );
  });

  test('v2→v3：已是 Markdown 的日记跳过', () async {
    await MigrationService.setDbVersion(db, 2);
    await insertDiary(id: 'd1', contentText: '纯文本', content: '# 已迁移', type: 'markdown');

    final result = await MigrationService.run(db);
    expect(result.migratedDiaries, 0);
    final diary = await (db.select(db.diaries)..where((t) => t.id.equals('d1')))
        .getSingle();
    expect(diary.content, '# 已迁移');
    expect(diary.type, 'markdown');
  });

  test('v3→v4：历史 Block 回填 source=initial', () async {
    await MigrationService.setDbVersion(db, 3);
    await insertDiary(id: 'd1', contentText: '内容', content: 'x', type: 'markdown');
    await db.into(db.blocks).insert(
      BlocksCompanion.insert(
        id: 'blk-v3',
        diaryId: 'd1',
        blockType: block_model.BlockType.text.value,
        content: const Value('旧内容'),
        sortOrder: const Value(0),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    final result = await MigrationService.run(db);

    expect(result.noop, isFalse);
    final block = await (db.select(db.blocks)..where((t) => t.id.equals('blk-v3')))
        .getSingle();
    expect(block.metaJson, contains('initial'));
    expect(
      await MigrationService.getDbVersion(db),
      MigrationService.currentDbVersion,
    );
    final history = await MigrationService.getMigrationHistory(db);
    expect(history.first['from'], 3);
    expect(history.first['to'], 4);
    expect(history[1]['from'], 4);
    expect(history[1]['to'], 5);
    expect(history[2]['from'], 5);
    expect(history[2]['to'], 6);
    expect(history[3]['from'], 6);
    expect(history[3]['to'], 7);
    expect(history[4]['from'], 7);
    expect(history[4]['to'], 8);
    expect(history[5]['from'], 8);
    expect(history[5]['to'], 9);
    expect(history[6]['from'], 9);
    expect(history[6]['to'], 10);
    expect(history[7]['from'], 10);
    expect(history[7]['to'], 11);
    expect(history[8]['from'], 11);
    expect(history[8]['to'], 12);
    expect(history.last['from'], 12);
    expect(history.last['to'], 13);
  });

  test('v3→v4：已带 meta 的 Block 不被覆盖', () async {
    await MigrationService.setDbVersion(db, 3);
    await insertDiary(id: 'd1', contentText: '内容', content: 'x', type: 'markdown');
    await db.into(db.blocks).insert(
      BlocksCompanion.insert(
        id: 'blk-meta',
        diaryId: 'd1',
        blockType: block_model.BlockType.text.value,
        content: const Value('内容'),
        sortOrder: const Value(0),
        metaJson: const Value('{"source":"appended"}'),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    await MigrationService.run(db);

    final block = await (db.select(db.blocks)..where((t) => t.id.equals('blk-meta')))
        .getSingle();
    expect(block.metaJson, '{"source":"appended"}');
  });
}
