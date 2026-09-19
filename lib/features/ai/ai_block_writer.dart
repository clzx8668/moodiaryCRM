import 'dart:math';

import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 同模板 AI 结果的写入策略（批次 96）。
///
/// 反馈背景：反复点「提取待办 / 点评 / 发芽 / 生成作品 / 模板处理」会在 AI 区
/// 堆出多张内容高度重复的卡片，干扰阅读。
///
/// 统一规则：**同一笔记内同一 aiTemplate 只保留最新一份**——新结果覆盖旧卡，
/// 更早的重复卡自动软删除（进回收站，可恢复）。AI 对话（role 非空）不受影响。
class AiBlockWriter {
  AiBlockWriter._();

  /// 写入（或覆盖）某模板的 AI 结果，返回保留的那张卡。
  static Future<Block> upsert({
    required String diaryId,
    required String template,
    required String content,
    BlockType blockType = BlockType.text,
    String title = '',
    String sourceContent = '',
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final same =
        blocks
            .where((b) => !b.isDeleted && b.meta.aiTemplate == template)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (same.isNotEmpty) {
      final target = same.last;
      target
        ..blockType = blockType
        ..content = content.trim()
        ..updatedAt = ts;
      if (title.trim().isNotEmpty) target.meta.title = title.trim();
      if (sourceContent.trim().isNotEmpty) {
        target.meta.sourceContent = sourceContent;
      }
      await IsarUtil.updateBlock(target);
      // 更早的重复卡软删除：AI 区保持一份，历史仍可在回收站找回
      for (final dup in same.take(same.length - 1)) {
        dup
          ..isDeleted = true
          ..updatedAt = ts;
        await IsarUtil.updateBlock(dup);
      }
      return target;
    }

    final sortOrder = blocks.isEmpty
        ? 0
        : blocks.map((b) => b.sortOrder).reduce(max) + 1;
    final block = Block()
      ..id = const Uuid().v7()
      ..diaryId = diaryId
      ..blockType = blockType
      ..content = content.trim()
      ..sortOrder = sortOrder
      ..createdAt = ts
      ..updatedAt = ts
      ..meta = BlockMeta(
        source: BlockMeta.sourceAi,
        aiTemplate: template,
        title: title,
        sourceContent: sourceContent,
      );
    await IsarUtil.insertBlock(block);
    return block;
  }

  /// 清理某模板的历史重复卡（保留最新一张），返回被软删的条数。
  static Future<int> dedupe({
    required String diaryId,
    required String template,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final same =
        blocks
            .where((b) => !b.isDeleted && b.meta.aiTemplate == template)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (same.length <= 1) return 0;
    var removed = 0;
    for (final dup in same.take(same.length - 1)) {
      dup
        ..isDeleted = true
        ..updatedAt = ts;
      await IsarUtil.updateBlock(dup);
      removed++;
    }
    return removed;
  }
}
