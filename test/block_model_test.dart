import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import 'helpers/db_test_helper.dart';

void main() {
  group('BlockType', () {
    test('value 映射稳定', () {
      expect(BlockType.text.value, 0);
      expect(BlockType.smartEntity.value, 1);
      expect(BlockType.todo.value, 2);
      expect(BlockType.chart.value, 3);
      expect(BlockType.aiStream.value, 4);
      expect(BlockType.image.value, 5);
      expect(BlockType.code.value, 6);
    });

    test('fromValue 未知值回退 text', () {
      expect(BlockType.fromValue(0), BlockType.text);
      expect(BlockType.fromValue(6), BlockType.code);
      expect(BlockType.fromValue(999), BlockType.text);
    });
  });

  group('Block 序列化', () {
    test('toJson/fromJson 往返一致', () {
      final block = Block()
        ..id = 'block-001'
        ..diaryId = 'diary-001'
        ..blockType = BlockType.todo
        ..content = '{"title":"买牛奶"}'
        ..sortOrder = 3
        ..isDeleted = false
        ..streamBuffer = ''
        ..streamComplete = false
        ..createdAt = DateTime(2026, 8, 19, 10, 30)
        ..updatedAt = DateTime(2026, 8, 19, 11, 0);

      final restored = Block.fromJson(block.toJson());

      expect(restored, block);
      expect(restored.id, 'block-001');
      expect(restored.blockType, BlockType.todo);
      expect(restored.sortOrder, 3);
      expect(restored.createdAt, DateTime(2026, 8, 19, 10, 30));
    });

    test('isValid 校验', () {
      final valid = Block()..diaryId = 'd1'..content = 'hello';
      expect(valid.isValid(), isTrue);

      final noDiary = Block()..content = 'hello';
      expect(noDiary.isValid(), isFalse);

      final noContent = Block()..diaryId = 'd1';
      expect(noContent.isValid(), isFalse);

      final streaming = Block()
        ..diaryId = 'd1'
        ..blockType = BlockType.aiStream;
      expect(streaming.isValid(), isTrue);
    });

    test('clone 深拷贝互不影响', () {
      final block = Block()..content = '原内容';
      final cloned = block.clone();
      cloned.content = '新内容';
      expect(block.content, '原内容');
      expect(cloned.content, '新内容');
      expect(cloned.id, block.id);
    });
  });

  group('Block Drift 往返', () {
    late AppDatabase db;

    setUp(() {
      db = openTestDb();
    });

    tearDown(() {
      closeTestDb(db);
    });

    test('插入/查询 diaryId 排序', () async {
      final b1 = Block()
        ..id = 'b1'
        ..diaryId = 'd1'
        ..content = '第一条'
        ..sortOrder = 1;
      final b2 = Block()
        ..id = 'b2'
        ..diaryId = 'd1'
        ..content = '第二条'
        ..sortOrder = 0;
      await IsarUtil.insertBlocks([b1, b2]);

      final list = await IsarUtil.getBlocksByDiary('d1');
      expect(list.length, 2);
      expect(list.first.content, '第二条');
      expect(list.last.content, '第一条');

      final other = await IsarUtil.getBlocksByDiary('d2');
      expect(other, isEmpty);
    });

    test('软删除过滤', () async {
      final b = Block()..id = 'b-del'..diaryId = 'd1'..content = 'x';
      await IsarUtil.insertBlock(b);
      await IsarUtil.softDeleteBlock('b-del');
      final visible = await IsarUtil.getBlocksByDiary('d1');
      expect(visible, isEmpty);
    });
  });
}
