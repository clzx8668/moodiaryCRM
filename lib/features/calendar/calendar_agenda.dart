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

// ---------------------------------------------------------------- 时间轴布局

/// 一天里的第几分钟（0..1439）。
int minutesOfDay(DateTime t) => t.hour * 60 + t.minute;

/// 按 [step] 分钟吸附（就近取整，iOS 日历默认 15 分钟一档）。
int snapMinutes(int minutes, int step) {
  if (step <= 0) return minutes;
  // 用 double.round() 保证负数也对称（-30 → -30，而不是 -15）
  return (minutes / step).round() * step;
}

/// 把分钟数还原成当天的时刻（超出 0..1440 会自动进位/退位）。
DateTime dayAtMinutes(DateTime day, int minutes) => DateTime(
  day.year,
  day.month,
  day.day,
).add(Duration(minutes: minutes));

/// 时间轴里一个事件的位置（比例值，由视图乘以自身宽高）。
class TimelineEventLayout {
  final Schedule event;

  /// 距当天 0 点的比例（0..1）
  final double topRatio;

  /// 高度比例（0..1）
  final double heightRatio;

  /// 横向占比（重叠事件并排分栏）
  final int columnIndex;
  final int columnCount;

  const TimelineEventLayout({
    required this.event,
    required this.topRatio,
    required this.heightRatio,
    required this.columnIndex,
    required this.columnCount,
  });

  double get leftFactor => columnCount == 0 ? 0 : columnIndex / columnCount;

  double get widthFactor => columnCount == 0 ? 1 : 1 / columnCount;
}

/// 一天时间轴的布局：算出每个事件的上边距/高度/横向分栏。
///
/// - 全天与跨天事件不进时间轴（走「全天」行）；
/// - 同一时段重叠的事件按「贪心分栏」并排，宽度均分（对齐 iOS 观感）；
/// - 最小时长 [minMinutes]（默认 15 分钟），避免 1 分钟事件看不见。
List<TimelineEventLayout> layoutDayTimeline(
  List<Schedule> events, {
  int minMinutes = 15,
}) {
  final timed = events
      .where((e) => !e.draft && !e.deleted && !e.floating)
      .where((e) => !e.allDay && !e.isMultiDay)
      .toList()
    ..sort((a, b) {
      final byStart = minutesOfDay(a.startTime).compareTo(
        minutesOfDay(b.startTime),
      );
      if (byStart != 0) return byStart;
      // 长的先排，短的后叠，观感更稳
      return _endMinutes(b).compareTo(_endMinutes(a));
    });

  final result = <TimelineEventLayout>[];
  var cluster = <Schedule>[];
  var clusterEnd = -1;

  void flush() {
    if (cluster.isEmpty) return;
    // 贪心分栏
    final columnEnds = <int>[];
    final columnOf = <Schedule, int>{};
    for (final e in cluster) {
      final start = minutesOfDay(e.startTime);
      var placed = -1;
      for (var i = 0; i < columnEnds.length; i++) {
        if (columnEnds[i] <= start) {
          placed = i;
          break;
        }
      }
      if (placed == -1) {
        columnEnds.add(_endMinutes(e));
        placed = columnEnds.length - 1;
      } else {
        columnEnds[placed] = _endMinutes(e);
      }
      columnOf[e] = placed;
    }
    final columnCount = columnEnds.length;
    for (final e in cluster) {
      final start = minutesOfDay(e.startTime);
      final end = _endMinutes(e);
      final duration = (end - start).clamp(minMinutes, 24 * 60);
      result.add(
        TimelineEventLayout(
          event: e,
          topRatio: (start / (24 * 60)).clamp(0.0, 1.0),
          heightRatio: (duration / (24 * 60)).clamp(0.0, 1.0),
          columnIndex: columnOf[e] ?? 0,
          columnCount: columnCount,
        ),
      );
    }
    cluster = <Schedule>[];
    clusterEnd = -1;
  }

  for (final e in timed) {
    final start = minutesOfDay(e.startTime);
    if (cluster.isEmpty || start < clusterEnd) {
      cluster.add(e);
      clusterEnd = clusterEnd < _endMinutes(e) ? _endMinutes(e) : clusterEnd;
    } else {
      flush();
      cluster.add(e);
      clusterEnd = _endMinutes(e);
    }
  }
  flush();
  return result;
}

int _endMinutes(Schedule e) {
  final start = minutesOfDay(e.startTime);
  final end = e.endTime == null ? start + 60 : minutesOfDay(e.endTime!);
  return end > start ? end : start + 30;
}

/// 拖动创建：把「纵向像素区间」换算成吸附后的时间区间。
///
/// [startY]/[endY] 是相对时间轴顶部的像素值；[hourHeight] 是每小时的像素高度。
/// 结果保证 `end - start >= snapMin`。
(DateTime start, DateTime end) dragRangeToTimes({
  required DateTime day,
  required double startY,
  required double endY,
  required double hourHeight,
  int snapMin = 15,
}) {
  double toMinutes(double y) => y / hourHeight * 60;
  var a = snapMinutes(toMinutes(startY).round(), snapMin);
  var b = snapMinutes(toMinutes(endY).round(), snapMin);
  if (b < a) {
    final t = a;
    a = b;
    b = t;
  }
  if (b - a < snapMin) b = a + snapMin;
  a = a.clamp(0, 24 * 60);
  b = b.clamp(0, 24 * 60);
  return (dayAtMinutes(day, a), dayAtMinutes(day, b));
}

/// 拖动移动/改时长：把像素位移换算成吸附后的分钟增量。
int dragDeltaMinutes(double dy, double hourHeight, {int snapMin = 15}) =>
    snapMinutes((dy / hourHeight * 60).round(), snapMin);

// ---------------------------------------------------------------- 月视图几何

/// 月格里一个事件占的格子范围（行内 0..6 列）。
class MonthSpanBar {
  final Schedule event;

  /// 在本周内的起始/结束列（含端点）
  final int startCol;
  final int endCol;

  /// 第几条泳道（0 在最上面）
  final int lane;

  const MonthSpanBar({
    required this.event,
    required this.startCol,
    required this.endCol,
    required this.lane,
  });

  int get span => endCol - startCol + 1;
}

/// 计算某一周里「跨天/全天事件」的连续条：裁到本周范围 + 泳道分配。
///
/// - 只处理覆盖 ≥2 天的事件（单天事件仍画在日格内）；
/// - 事件跨周时，每周各裁一段（iOS 也是这么处理的）；
/// - [maxLanes] 满了两条之外的就不再画（调用方显示「+N」）。
List<MonthSpanBar> layoutWeekSpans({
  required List<DateTime> week,
  required List<Schedule> events,
  int maxLanes = 2,
}) {
  if (week.isEmpty) return const [];
  final weekStart = DateTime(week.first.year, week.first.month, week.first.day);
  final weekEnd = DateTime(week.last.year, week.last.month, week.last.day);

  final candidates = <Schedule>[];
  for (final e in events) {
    if (e.deleted || e.draft || e.floating) continue;
    if (!(e.allDay || e.isMultiDay)) continue;
    final start = e.day;
    final end = e.endDay;
    if (end.isBefore(weekStart) || start.isAfter(weekEnd)) continue;
    candidates.add(e);
  }
  candidates.sort((a, b) {
    final byStart = a.startTime.compareTo(b.startTime);
    if (byStart != 0) return byStart;
    return b.endDay.compareTo(a.endDay); // 长的优先占上面泳道
  });

  final laneEnds = <DateTime>[]; // 每条泳道已占用的最后一天
  final bars = <MonthSpanBar>[];
  for (final e in candidates) {
    final start = e.day.isBefore(weekStart) ? weekStart : e.day;
    final end = e.endDay.isAfter(weekEnd) ? weekEnd : e.endDay;
    final startCol = start.difference(weekStart).inDays;
    final endCol = end.difference(weekStart).inDays;

    var lane = -1;
    for (var i = 0; i < laneEnds.length; i++) {
      // 复用泳道的前提：上一条在这条开始之前就结束了（互不重叠）
      if (laneEnds[i].isBefore(start)) {
        lane = i;
        break;
      }
    }
    if (lane == -1) {
      if (laneEnds.length >= maxLanes) continue; // 泳道满了，交给「+N」
      laneEnds.add(end);
      lane = laneEnds.length - 1;
    } else {
      laneEnds[lane] = end;
    }
    bars.add(
      MonthSpanBar(
        event: e,
        startCol: startCol,
        endCol: endCol,
        lane: lane,
      ),
    );
  }
  return bars;
}

/// 指针落在月格的第几行第几列（0 起；越界返回 null）。
/// [gridTop] 是网格内容的顶部（已去掉星期表头）。
(int row, int col)? gridCellAt({
  required double dx,
  required double dy,
  required double cellWidth,
  required double cellHeight,
  required int rows,
  int cols = 7,
}) {
  if (cellWidth <= 0 || cellHeight <= 0) return null;
  final col = (dx / cellWidth).floor();
  final row = (dy / cellHeight).floor();
  if (col < 0 || col >= cols || row < 0 || row >= rows) return null;
  return (row, col);
}

/// 月格里「日格内第几条事件条」被按住（用于拖动时挑事件）。
/// [dyInCell] 是相对日格顶部的偏移；barsTop 是事件条起始 y；barHeight 单条高度。
int eventBarIndexAt({
  required double dyInCell,
  required double barsTop,
  required double barHeight,
  required int barCount,
}) {
  if (barCount <= 0) return -1;
  final index = ((dyInCell - barsTop) / barHeight).floor();
  if (index < 0 || index >= barCount) return -1;
  return index;
}

/// 跨天事件移动日期：保持时长与「当天时刻」。
Schedule moveScheduleToDay(Schedule e, DateTime targetDay, {int? keepHour}) {
  final target = DateTime(targetDay.year, targetDay.month, targetDay.day);
  final hour = keepHour ?? e.startTime.hour;
  final minute = e.startTime.minute;
  final newStart = DateTime(
    target.year,
    target.month,
    target.day,
    e.allDay ? 0 : hour,
    e.allDay ? 0 : minute,
  );
  final duration = e.endTime == null
      ? const Duration(hours: 1)
      : e.endTime!.difference(e.startTime);
  return e.clone()
    ..startTime = newStart
    ..endTime = e.allDay ? null : newStart.add(duration);
}
