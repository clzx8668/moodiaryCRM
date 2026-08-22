import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

import 'todo_item.dart';
import 'todo_parser.dart';

/// 待办聚合服务（P2.2）：本地 Todo Block + Twenty task 缓存跨源合并。
///
/// [merge] 为纯函数便于测试；[load]/[toggleLocal]/[quickAdd] 走本地数据库。
class TodoAggregator {
  /// 合并两条来源并排序：未完成在前，其余按有效日期升序。
  static List<TodoItem> merge({
    required List<Block> todoBlocks,
    required List<CrmEntityCache> tasks,
    DateTime? date,
    bool includeDone = true,
  }) {
    final items = <TodoItem>[];
    for (final block in todoBlocks) {
      items.addAll(TodoParser.fromBlock(block));
    }
    for (final task in tasks) {
      final item = TodoParser.fromCrmTask(task);
      if (item != null) items.add(item);
    }
    if (!includeDone) items.removeWhere((item) => item.done);
    if (date != null) {
      items.removeWhere((item) => !_sameDay(item.effectiveDate, date));
    }
    items.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final byDate = a.effectiveDate.compareTo(b.effectiveDate);
      if (byDate != 0) return byDate;
      return a.text.compareTo(b.text);
    });
    return items;
  }

  /// 从本地数据库加载跨源待办。
  static Future<List<TodoItem>> load({
    DateTime? date,
    bool includeDone = true,
  }) async {
    final blocks = await IsarUtil.getBlocksByType(BlockType.todo);
    final tasks = await IsarUtil.getCrmEntitiesByType('task');
    return merge(
      todoBlocks: blocks,
      tasks: tasks,
      date: date,
      includeDone: includeDone,
    );
  }

  /// 勾选/取消本地待办：定位行号改写复选框并落库。
  static Future<Block> toggleLocal(TodoItem item) async {
    if (!item.isLocal) {
      throw ArgumentError('CRM 来源待办暂不支持本地勾选：${item.id}');
    }
    final block = await IsarUtil.getBlockById(item.blockId);
    if (block == null) {
      throw StateError('待办 Block 不存在：${item.blockId}');
    }
    block.content = TodoParser.toggleLine(
      block.content,
      item.lineIndex,
      done: !item.done,
    );
    await IsarUtil.updateBlock(block);
    return block;
  }

  /// 日历快捷新建（3 步内：入口 → 输入 → 保存）：生成 Diary + todo Block。
  static Future<Diary> quickAdd({
    required String text,
    DateTime? dueDate,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('待办内容不能为空');
    }
    final now = DateTime.now();
    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = _deriveTitle(trimmed)
      ..contentText = trimmed
      ..content = '- [ ] $trimmed'
      ..type = DiaryType.markdown.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    await IsarUtil.insertADiary(diary);

    final block = Block()
      ..diaryId = diary.id
      ..blockType = BlockType.todo
      ..content = '- [ ] $trimmed'
      ..sortOrder = 0
      ..createdAt = now
      ..updatedAt = now;
    if (dueDate != null) {
      block.meta = BlockMeta(
        source: BlockMeta.sourceAppended,
        dueDate: dueDate.toIso8601String(),
      );
    }
    await IsarUtil.insertBlock(block);
    return diary;
  }

  static String _deriveTitle(String text) {
    if (text.length <= 20) return text;
    return '${text.substring(0, 20)}…';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
