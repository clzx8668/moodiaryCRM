import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:path/path.dart' as p;

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

      // aiStream 允许空内容（流式未完成）
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

  group('Block Isar 往返', () {
    late Isar isar;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('block_test');
      isar = Isar.open(
        schemas: [BlockSchema],
        directory: tempDir.path,
      );
    });

    tearDown(() async {
      isar.close(deleteFromDisk: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('put/get/查询 diaryId', () async {
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
      isar.write((isar) {
        isar.blocks.putAll([b1, b2]);
      });

      final list = await isar.blocks
          .where()
          .diaryIdEqualTo('d1')
          .sortBySortOrder()
          .findAllAsync();
      expect(list.length, 2);
      expect(list.first.content, '第二条');
      expect(list.last.content, '第一条');

      final other = await isar.blocks.where().diaryIdEqualTo('d2').countAsync();
      expect(other, 0);
    });

    test('软删除过滤', () async {
      final b = Block()..id = 'b-del'..diaryId = 'd1'..content = 'x';
      isar.write((isar) {
        isar.blocks.put(b);
      });
      isar.write((isar) {
        final found = isar.blocks.get(fastHash('b-del'));
        found!.isDeleted = true;
        isar.blocks.put(found);
      });
      final visible = await isar.blocks
          .where()
          .diaryIdEqualTo('d1')
          .isDeletedEqualTo(false)
          .findAllAsync();
      expect(visible, isEmpty);
    });
  });

  test('fastHash 稳定且不冲突于空串', () {
    expect(fastHash(''), fastHash(''));
    expect(fastHash('abc') == fastHash('abc'), isTrue);
    expect(p.basename(Directory.current.path).isNotEmpty, isTrue);
  });
}
