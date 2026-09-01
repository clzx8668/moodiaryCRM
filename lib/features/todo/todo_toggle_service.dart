import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/features/todo/todo_parser.dart';
import 'package:moodiary/persistence/isar.dart';

/// 待办/日程/CRM 状态中枢（P1）。
///
/// 统一勾选入口，按来源分派到"权威源"写入，避免 UI 各存一份布尔漂移：
/// - schedule → `Schedules.done`；
/// - localBlock → 改写 Block 任务行 + 刷新日记投影；
/// - crmTask / crmEvent → 只读（对接按配置走 CRM 写工具 + 确认）。
class TodoToggleService {
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  Future<bool> toggle(TodoItem item) async {
    switch (item.source) {
      case TodoSource.schedule:
        await _scheduleRepo.toggleDone(item.scheduleId);
        return true;
      case TodoSource.localBlock:
        return _toggleBlock(item);
      case TodoSource.crmTask:
      case TodoSource.crmEvent:
        return false;
    }
  }

  Future<bool> _toggleBlock(TodoItem item) async {
    final block = await IsarUtil.getBlockById(item.blockId);
    if (block == null) return false;
    try {
      block.content = TodoParser.toggleLine(
        block.content,
        item.lineIndex,
        done: !item.done,
      );
      block.updatedAt = DateTime.now();
      await IsarUtil.updateBlock(block);
      await IsarUtil.deleteBlockEmbeddings(block.id);
      final diary = await IsarUtil.getDiaryById(block.diaryId);
      if (diary != null) {
        await IsarUtil.refreshDiaryProjection(diary);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
