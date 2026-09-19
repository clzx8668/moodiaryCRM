import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/ai_block_writer.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  Future<Block> seedAi({
    required String diaryId,
    required String template,
    required String content,
    int sortOrder = 0,
    String role = '',
  }) async {
    final block = Block()
      ..id = const Uuid().v7()
      ..diaryId = diaryId
      ..blockType = BlockType.text
      ..content = content
      ..sortOrder = sortOrder
      ..createdAt = DateTime(2026, 9, 19)
      ..updatedAt = DateTime(2026, 9, 19)
      ..meta = BlockMeta(
        source: BlockMeta.sourceAi,
        aiTemplate: template,
        role: role,
      );
    await IsarUtil.insertBlock(block);
    return block;
  }

  Future<List<Block>> alive(String diaryId) async {
    final all = await IsarUtil.getBlocksByDiary(diaryId);
    return all.where((b) => !b.isDeleted).toList();
  }

  test('首次写入：新建一张 AI 卡', () async {
    final block = await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'extract',
      content: 'AI 提取结果',
    );
    expect(block.meta.aiTemplate, 'extract');
    expect((await alive('d1')).length, 1);
  });

  test('重复运行同一模板：覆盖最新一张，不新增卡片', () async {
    final first = await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'extract',
      content: '第一版提取',
    );
    final second = await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'extract',
      content: '第二版提取',
    );

    expect(second.id, first.id); // 复用同一张卡
    final blocks = await alive('d1');
    expect(blocks.length, 1);
    expect(blocks.single.content, '第二版提取');
  });

  test('历史重复卡：写入时自动软删，只留最新一份（可在回收站找回）', () async {
    await seedAi(
      diaryId: 'd1',
      template: 'comment',
      content: '旧点评 A',
      sortOrder: 1,
    );
    await seedAi(
      diaryId: 'd1',
      template: 'comment',
      content: '旧点评 B',
      sortOrder: 2,
    );

    await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'comment',
      content: '最新点评',
    );

    final visible = await alive('d1');
    expect(visible.length, 1);
    expect(visible.single.content, '最新点评');

    final all = await IsarUtil.getBlocksByDiary('d1', includeDeleted: true);
    // 最新的那张被复用改写，更早的 1 张进回收站（可恢复）
    expect(all.where((b) => b.isDeleted).length, 1);
  });

  test('不同模板互不影响；AI 对话块不受影响', () async {
    await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'extract',
      content: '提取',
    );
    await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'comment',
      content: '点评',
    );
    await seedAi(
      diaryId: 'd1',
      template: '',
      content: '对话回答',
      role: 'assistant',
      sortOrder: 9,
    );

    final visible = await alive('d1');
    expect(visible.length, 3);
    expect(
      visible.map((b) => b.meta.aiTemplate),
      containsAll(['extract', 'comment', '']),
    );
  });

  test('跨笔记隔离：同模板在不同笔记各自保留一份', () async {
    await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'work',
      content: 'A 的草稿',
    );
    await AiBlockWriter.upsert(
      diaryId: 'd2',
      template: 'work',
      content: 'B 的草稿',
    );
    expect((await alive('d1')).single.content, 'A 的草稿');
    expect((await alive('d2')).single.content, 'B 的草稿');
  });

  test('dedupe：存量重复卡一次清理，只留最新', () async {
    await seedAi(
      diaryId: 'd1',
      template: 'germinate',
      content: '一',
      sortOrder: 1,
    );
    await seedAi(
      diaryId: 'd1',
      template: 'germinate',
      content: '二',
      sortOrder: 2,
    );
    await seedAi(
      diaryId: 'd1',
      template: 'germinate',
      content: '三',
      sortOrder: 3,
    );

    expect(await AiBlockWriter.dedupe(diaryId: 'd1', template: 'germinate'), 2);
    final visible = await alive('d1');
    expect(visible.length, 1);
    expect(visible.single.content, '三');
    // 再来一次：已无重复
    expect(await AiBlockWriter.dedupe(diaryId: 'd1', template: 'germinate'), 0);
  });

  test('标题与源内容随写入更新（空值不覆盖）', () async {
    await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'polish',
      content: '正文',
      title: '润色',
      sourceContent: '原始内容',
    );
    final block = await AiBlockWriter.upsert(
      diaryId: 'd1',
      template: 'polish',
      content: '正文 v2',
    );
    expect(block.meta.title, '润色'); // 未传则不覆盖
    expect(block.meta.sourceContent, '原始内容');
  });
}
