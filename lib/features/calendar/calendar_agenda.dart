import '../schedule/models/schedule.dart';
import '../todo/todo_item.dart';

/// 月视图缩放档位（技巧 01）：圆点 → 事件条 → 标题+时间。
enum CalendarZoom {
  /// 只画小圆点
  dots,
  /// 画连续色条
  bars,
  /// 色条 + 事件标题（含时间）
  titles,
}

/// 一天的时间轴议程（纯数据，便于单测）。
///
/// 分组规则：
/// - `allDay`：全天事件 + 跨天事件（时间轴顶部的「全天」行）；
/// - `byHour`：按**起始小时**落到 0..23 槽位（跨小时事件只在自己的起始槽出现）；
/// - `todosByHour`：带具体时刻的提醒（时间轴画空心圆，技巧 02）；
/// - `untimedTodos`：只有日期没有时刻的提醒（时间轴下方「提醒事项」区）。
class CalendarAgenda {
  final DateTime day;
  final List<Schedule> allDay;
  final Map<int, List<Schedule>> byHour;
  final Map<int, List<TodoItem>> todosByHour;
  final List<TodoItem> untimedTodos;

  CalendarAgenda({
    required this.day,
    required this.allDay,
    required this.byHour,
    required this.todosByHour,
    required this.untimedTodos,
  });

  bool get isEmpty =>
      allDay.isEmpty &&
      byHour.isEmpty &&
      todosByHour.isEmpty &&
      untimedTodos.isEmpty;

  /// 有内容的时刻（时间轴只在"忙碌时段"显示载体）。
  Set<int> get busyHours => {...byHour.keys, ...todosByHour.keys};

  List<Schedule> get timedEvents => [
    for (var h = 0; h < 24; h++) ...?byHour[h],
  ];
}

/// 组装某天的议程。
///
/// - 草案（[Schedule.draft]）不进日历，故本函数兜底过滤；
/// - [day] 会归一到零点后再比较。
CalendarAgenda buildAgenda({
  required DateTime day,
  required List<Schedule> events,
  required List<TodoItem> todos,
}) {
  final target = DateTime(day.year, day.month, day.day);
  final allDay = <Schedule>[];
  final byHour = <int, List<Schedule>>{};

  for (final e in events) {
    if (e.draft || e.deleted) continue;
    // 浮动待办（收件箱）不属于任何一天，交给提醒区展示
    if (e.floating) continue;
    if (!_touchesDay(e, target)) continue;
    if (e.allDay || e.isMultiDay) {
      allDay.add(e);
      continue;
    }
    byHour.putIfAbsent(e.startTime.hour.clamp(0, 23), () => []).add(e);
  }

  final todosByHour = <int, List<TodoItem>>{};
  final untimed = <TodoItem>[];
  for (final t in todos) {
    // 日程类待办已经以事件卡出现在时间轴上，避免一屏两份；
    // 但浮动待办没有卡片，保留成勾选项。
    if (t.source == TodoSource.schedule && !t.isFloating) continue;
    final due = t.dueDate;
    final hasClock = due != null && (due.hour != 0 || due.minute != 0);
    if (hasClock) {
      todosByHour.putIfAbsent(due.hour.clamp(0, 23), () => []).add(t);
    } else {
      untimed.add(t);
    }
  }

  for (final list in byHour.values) {
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  for (final list in todosByHour.values) {
    list.sort((a, b) => (a.dueDate ?? a.time).compareTo(b.dueDate ?? b.time));
  }
  allDay.sort((a, b) => a.startTime.compareTo(b.startTime));

  return CalendarAgenda(
    day: target,
    allDay: allDay,
    byHour: byHour,
    todosByHour: todosByHour,
    untimedTodos: untimed,
  );
}

/// 捏合手势 → 缩放档位（1.15 / 0.87 之间的抖动忽略）。
CalendarZoom zoomAfterPinch(CalendarZoom current, double scale) {
  const levels = CalendarZoom.values;
  var index = levels.indexOf(current);
  if (scale > 1.15) {
    index++;
  } else if (scale < 0.87) {
    index--;
  }
  return levels[index.clamp(0, levels.length - 1)];
}

/// 该事件是否落在 [day]（跨天事件算覆盖到每一天）。
bool _touchesDay(Schedule e, DateTime day) {
  final start = e.day;
  final end = e.endDay;
  return !day.isBefore(start) && !day.isAfter(end);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 「9月25日 星期五」
String dayLabel(DateTime day) => '${day.month}月${day.day}日 ${weekdayLabel(day)}';

String weekdayLabel(DateTime day) => switch (day.weekday) {
  DateTime.monday => '星期一',
  DateTime.tuesday => '星期二',
  DateTime.wednesday => '星期三',
  DateTime.thursday => '星期四',
  DateTime.friday => '星期五',
  DateTime.saturday => '星期六',
  _ => '星期日',
};

String shortWeekdayLabel(DateTime day) => switch (day.weekday) {
  DateTime.monday => '周一',
  DateTime.tuesday => '周二',
  DateTime.wednesday => '周三',
  DateTime.thursday => '周四',
  DateTime.friday => '周五',
  DateTime.saturday => '周六',
  _ => '周日',
};

/// 今天 / 明天 / 昨天 / 空串
String relativeDayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  return switch (d.difference(t).inDays) {
    0 => '今天',
    1 => '明天',
    -1 => '昨天',
    _ => '',
  };
}

/// 「09:00」/「09:00 – 10:30」/「全天」
String eventTimeLabel(Schedule e) {
  if (e.allDay || e.isMultiDay) return '全天';
  final start = fmtClock(e.startTime);
  final end = e.endTime;
  if (end == null || !end.isAfter(e.startTime)) return start;
  return '$start – ${fmtClock(end)}';
}

String fmtClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 月网格需要渲染的日子（整周对齐）。
List<DateTime> monthGridDays(int year, int month, {int weekStart = 1}) {
  final first = DateTime(year, month, 1);
  final offset = (first.weekday - weekStart + 7) % 7;
  final start = first.subtract(Duration(days: offset));
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final cells = ((offset + daysInMonth) / 7).ceil() * 7;
  return [for (var i = 0; i < cells; i++) start.add(Duration(days: i))];
}

/// 一周七天（含 [day]）。
List<DateTime> weekDays(DateTime day, {int weekStart = 1}) {
  final d = DateTime(day.year, day.month, day.day);
  final offset = (d.weekday - weekStart + 7) % 7;
  final start = d.subtract(Duration(days: offset));
  return [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
}
