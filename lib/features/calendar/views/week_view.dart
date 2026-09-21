import 'package:flutter/material.dart';

import '../../schedule/models/schedule.dart';
import '../calendar_agenda.dart';
import '../ios_calendar_theme.dart';

/// 多日视图（周）：7 列时间网格，横向可滚动，左侧时间栏固定。
///
/// 对齐 iPad/Mac「周」视图：全天行在最上，下面是 24 小时网格，
/// 今天整列高亮；点空白处按那天的时刻新建；点事件卡进详情。
class WeekView extends StatelessWidget {
  final List<DateTime> days;
  final Map<DateTime, List<Schedule>> eventsByDay;
  final Color Function(Schedule) colorOf;
  final DateTime? selectedDay;
  final double hourHeight;
  final double columnWidth;
  final void Function(Schedule event) onTapEvent;
  final void Function(DateTime day, DateTime start, DateTime end) onCreateRange;
  final void Function(DateTime day) onSelectDay;

  const WeekView({
    super.key,
    required this.days,
    required this.eventsByDay,
    required this.colorOf,
    required this.onTapEvent,
    required this.onCreateRange,
    required this.onSelectDay,
    this.selectedDay,
    this.hourHeight = 48,
    this.columnWidth = 108,
  });

  static const double _gutter = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalHeight = 24 * hourHeight;
    final today = DateTime.now();

    return Column(
      children: [
        // 表头：星期 + 日期（点表头 = 选中那天）
        Row(
          children: [
            const SizedBox(width: _gutter),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    for (final day in days)
                      SizedBox(
                        width: columnWidth,
                        child: _DayHeader(
                          day: day,
                          isToday: isSameDay(day, today),
                          selected: selectedDay != null &&
                              isSameDay(day, selectedDay!),
                          eventCount: (eventsByDay[day] ?? const []).length,
                          onTap: () => onSelectDay(day),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 固定时间栏
                SizedBox(
                  width: _gutter,
                  height: totalHeight,
                  child: Stack(
                    children: [
                      for (var h = 0; h <= 24; h++)
                        Positioned(
                          top: h * hourHeight,
                          right: 4,
                          child: Transform.translate(
                            offset: const Offset(0, -5),
                            child: Text(
                              h == 24
                                  ? ''
                                  : '${h.toString().padLeft(2, '0')}:00',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      height: totalHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final day in days)
                            SizedBox(
                              width: columnWidth,
                              child: _DayColumn(
                                day: day,
                                events: eventsByDay[day] ?? const [],
                                colorOf: colorOf,
                                hourHeight: hourHeight,
                                isToday: isSameDay(day, today),
                                onTapEvent: onTapEvent,
                                onCreateRange: onCreateRange,
                                columnWidth: columnWidth,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool selected;
  final int eventCount;
  final VoidCallback onTap;

  const _DayHeader({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.eventCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(
              shortWeekdayLabel(day),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isToday
                    ? IosCalendarTheme.today
                    : scheme.onSurfaceVariant,
                fontWeight: isToday ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? IosCalendarTheme.today
                    : selected
                    ? scheme.primaryContainer
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isToday
                      ? Colors.white
                      : selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontWeight: (isToday || selected) ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (eventCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$eventCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              const SizedBox(height: 13),
          ],
        ),
      ),
    );
  }
}

/// 单日列：小时线 + 事件卡（复用 `layoutDayTimeline` 的分栏结果）。
class _DayColumn extends StatelessWidget {
  final DateTime day;
  final List<Schedule> events;
  final Color Function(Schedule) colorOf;
  final double hourHeight;
  final bool isToday;
  final void Function(Schedule event) onTapEvent;
  final void Function(DateTime day, DateTime start, DateTime end) onCreateRange;
  final double columnWidth;

  const _DayColumn({
    required this.day,
    required this.events,
    required this.colorOf,
    required this.hourHeight,
    required this.isToday,
    required this.onTapEvent,
    required this.onCreateRange,
    required this.columnWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final layouts = layoutDayTimeline(events);
    final width = columnWidth;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) {
        final (start, end) = dragRangeToTimes(
          day: day,
          startY: d.localPosition.dy,
          endY: d.localPosition.dy + hourHeight,
          hourHeight: hourHeight,
        );
        onCreateRange(day, start, end);
      },
      child: Stack(
        children: [
          // 底色 / 今天高亮
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isToday
                    ? IosCalendarTheme.today.withValues(alpha: 0.05)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
          // 小时线
          for (var h = 0; h <= 24; h++)
            Positioned(
              top: h * hourHeight,
              left: 0,
              right: 0,
              height: 0.6,
              child: ColoredBox(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
          // 事件卡
          for (final l in layouts)
            Positioned(
              top: l.topRatio * 24 * hourHeight,
              height: (l.heightRatio * 24 * hourHeight).clamp(18.0, 24 * hourHeight),
              left: l.leftFactor * (width - 4) + 2,
              width: (width - 4) * l.widthFactor - 2,
              child: GestureDetector(
                onTap: () => onTapEvent(l.event),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  decoration: BoxDecoration(
                    color: IosCalendarTheme.eventFill(
                      colorOf(l.event),
                      scheme.surfaceContainerLow,
                    ),
                    borderRadius: BorderRadius.circular(5),
                    border: Border(
                      left: BorderSide(color: colorOf(l.event), width: 2.5),
                    ),
                  ),
                  child: Text(
                    l.event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          // 当前时间线
          if (isToday)
            Positioned(
              top: minutesOfDay(DateTime.now()) / 60 * hourHeight,
              left: 0,
              right: 0,
              height: 1,
              child: const ColoredBox(color: IosCalendarTheme.today),
            ),
        ],
      ),
    );
  }
}
