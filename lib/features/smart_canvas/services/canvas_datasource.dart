import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 智能卡片数据访问层：把 Block/Diary 的读写收敛到这里，
/// 页面与逻辑不直接触碰 IsarUtil（便于测试注入与后续切换实现）。
class CanvasDatasource {
  Future<Diary?> loadDiary(String id) => IsarUtil.getDiaryById(id);

  Future<List<Block>> loadBlocks(String diaryId) =>
      IsarUtil.getBlocksByDiary(diaryId);

  Future<Block?> loadBlock(String blockId) => IsarUtil.getBlockById(blockId);

  Future<void> saveBlock(Block block) => IsarUtil.updateBlock(block);

  Future<void> softDeleteBlock(String blockId) =>
      IsarUtil.softDeleteBlock(blockId).then((_) {
        // 同步清除过期向量索引（P3.3 增量策略：改删后重建）
        return IsarUtil.deleteBlockEmbeddings(blockId);
      });

  /// 双模态聚合投影刷新：Blocks → diary.content/contentText
  Future<String> refreshDiaryProjection(Diary diary) =>
      IsarUtil.refreshDiaryProjection(diary);

  /// 初始卡兜底（幂等）：详情页打开时若无任何 Block，
  /// 把 diary.content 物化为 source=initial 的 text 卡。
  ///
  /// 返回是否创建了初始卡。
  Future<bool> ensureInitialBlock(Diary diary) async {
    final blocks = await loadBlocks(diary.id);
    if (blocks.isNotEmpty) return false;
    final now = DateTime.now();
    final block = Block()
      ..id = const Uuid().v7()
      ..diaryId = diary.id
      ..blockType = BlockType.text
      ..content = diary.content.isEmpty ? diary.contentText : diary.content
      ..sortOrder = 0
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(source: BlockMeta.sourceInitial);
    await IsarUtil.insertBlock(block);
    return true;
  }

  /// 追加笔记：新增 source=appended 的 text 卡，并刷新聚合投影。
  Future<Block> appendNote({
    required Diary diary,
    required String text,
    String template = '',
  }) async {
    final blocks = await loadBlocks(diary.id);
    final sortOrder = blocks.isEmpty
        ? 0
        : blocks.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final now = DateTime.now();
    final block = Block()
      ..id = const Uuid().v7()
      ..diaryId = diary.id
      ..blockType = BlockType.text
      ..content = text.trim()
      ..sortOrder = sortOrder
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceAppended,
        syncStatus: BlockMeta.syncPending,
        aiTemplate: template,
      );
    await IsarUtil.insertBlock(block);
    await refreshDiaryProjection(diary);
    return block;
  }

  /// 更新卡片内容（Markdown 编辑器保存后），并刷新聚合投影。
  Future<void> updateBlockContent(Block block, String content) async {
    block
      ..content = content.trim()
      ..updatedAt = DateTime.now();
    _markPending(block);
    await saveBlock(block);
    await IsarUtil.deleteBlockEmbeddings(block.id);
    final diary = await loadDiary(block.diaryId);
    if (diary != null) {
      await refreshDiaryProjection(diary);
    }
  }

  /// 待办勾选：content 前缀 `[x]`/`[ ]` 切换。
  Future<void> toggleTodo(Block block) async {
    final text = block.content.replaceFirst(RegExp(r'^\[[ xX]\]\s*'), '').trim();
    final done = block.content.trim().startsWith('[x]');
    block
      ..content = '[${done ? ' ' : 'x'}] $text'
      ..updatedAt = DateTime.now();
    _markPending(block);
    await saveBlock(block);
    await IsarUtil.deleteBlockEmbeddings(block.id);
    final diary = await loadDiary(block.diaryId);
    if (diary != null) {
      await refreshDiaryProjection(diary);
    }
  }

  /// 创建 AI 流式卡片（source=ai），返回新 Block。
  Future<Block> createAiStreamBlock({
    required Diary diary,
    required String template,
    required String sourceContent,
  }) async {
    final blocks = await loadBlocks(diary.id);
    final sortOrder = blocks.isEmpty
        ? 0
        : blocks.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final now = DateTime.now();
    final block = Block()
      ..id = const Uuid().v7()
      ..diaryId = diary.id
      ..blockType = BlockType.aiStream
      ..content = ''
      ..sortOrder = sortOrder
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceAi,
        syncStatus: BlockMeta.syncPending,
        aiTemplate: template,
        title: template,
        sourceContent: sourceContent,
      );
    await IsarUtil.insertBlock(block);
    await refreshDiaryProjection(diary);
    return block;
  }

  /// 流式中途持久化（断点恢复，每 ~50 token 调用一次）
  Future<void> persistStreamBuffer(Block block, String buffer) async {
    block
      ..streamBuffer = buffer
      ..streamComplete = false
      ..updatedAt = DateTime.now();
    await saveBlock(block);
  }

  /// AI 卡片转正：aiStream → 目标类型（text/todo/smartEntity 等），
  /// 保留 block id 与 meta（source=ai、aiTemplate）。
  Future<Block> promoteAiBlock({
    required Block block,
    required BlockType targetType,
    required String content,
  }) async {
    block
      ..blockType = targetType
      ..content = content.trim()
      ..streamBuffer = ''
      ..streamComplete = true
      ..updatedAt = DateTime.now();
    _markPending(block);
    await saveBlock(block);
    await IsarUtil.deleteBlockEmbeddings(block.id);
    final diary = await loadDiary(block.diaryId);
    if (diary != null) {
      await refreshDiaryProjection(diary);
    }
    return block;
  }

  Block _markPending(Block block) {
    final meta = block.meta.clone()..syncStatus = BlockMeta.syncPending;
    block.meta = meta;
    return block;
  }
}
