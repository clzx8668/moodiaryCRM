import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
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
    List<Schedule> schedules = const [],
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
    for (final schedule in schedules) {
      items.add(TodoParser.fromSchedule(schedule));
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
    final isToday = date != null && _sameDay(date, DateTime.now());
    final blocks = await IsarUtil.getBlocksByType(BlockType.todo);
    final tasks = await IsarUtil.getCrmEntitiesByType('task');
    final scheduleRepo = ScheduleRepository();

    List<Schedule> schedules;
    if (isToday) {
      // 今日收件箱：全部未完成（浮动无论日期 + 所有日期未完成）
      schedules = await scheduleRepo.listActive();
    } else {
      schedules = date == null
          ? await scheduleRepo.listActive()
          : await scheduleRepo.byDay(date);
      // 非今日：浮动待办只在"今日"收件箱出现
      if (date != null) schedules.removeWhere((s) => s.floating);
    }

    final items = merge(
      todoBlocks: blocks,
      tasks: tasks,
      schedules: schedules,
      date: isToday ? null : date,
      includeDone: isToday ? false : includeDone,
    );
    if (isToday) {
      items.addAll(await _loadCrmEvents(date: null, includeDone: false));
    } else {
      items.addAll(await _loadCrmEvents(date: date, includeDone: includeDone));
    }
    _sortForView(items, isToday: isToday);
    return items;
  }

  static void _sortForView(List<TodoItem> items, {required bool isToday}) {
    items.sort((a, b) {
      if (isToday) {
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      } else {
        if (a.done != b.done) return a.done ? 1 : -1;
      }
      final byDate = a.effectiveDate.compareTo(b.effectiveDate);
      if (byDate != 0) return byDate;
      return a.text.compareTo(b.text);
    });
  }

  static Future<List<TodoItem>> _loadCrmEvents({
    DateTime? date,
    bool includeDone = true,
  }) async {
    final repo = CrmLocalRepository();
    final events = <TodoItem>[];
    for (final reminder in await repo.listReminders(includeCompleted: false)) {
      events.add(
        TodoItem(
          id: 'reminder:${reminder.id}',
          source: TodoSource.crmEvent,
          text: '🔔 ${reminder.title}',
          done: false,
          dueDate: reminder.remindAt,
          time: reminder.createdAt,
          title: 'CRM 提醒',
        ),
      );
    }
    for (final activity in await repo.listActivities()) {
      final at = activity.scheduledAt;
      if (at == null) continue;
      events.add(
        TodoItem(
          id: 'activity:${activity.id}',
          source: TodoSource.crmEvent,
          text: '📅 ${activity.subject}',
          done: activity.status == 'completed',
          dueDate: at,
          time: activity.createdAt,
          title: 'CRM 跟进',
        ),
      );
    }
    for (final plan in await repo.listPaymentPlans()) {
      if (plan.status == 'completed') continue;
      events.add(
        TodoItem(
          id: 'plan:${plan.id}',
          source: TodoSource.crmEvent,
          text: '💴 ${plan.planName} ¥${plan.planAmount.toStringAsFixed(2)}',
          done: false,
          dueDate: plan.planDate,
          time: plan.planDate,
          title: '回款计划',
        ),
      );
    }
    for (final due in await repo.dueReminders()) {
      events.add(
        TodoItem(
          id: 'due:${due.type}:${due.entityId}:${due.at.millisecondsSinceEpoch}',
          source: TodoSource.crmEvent,
          text: '⏰ ${due.title}',
          done: false,
          dueDate: due.at,
          time: due.at,
          title: 'CRM 到期',
        ),
      );
    }
    if (!includeDone) events.removeWhere((e) => e.done);
    if (date != null) {
      events.removeWhere((e) => !_sameDay(e.effectiveDate, date));
    }
    return events;
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
