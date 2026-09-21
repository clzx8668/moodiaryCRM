import 'package:flutter/material.dart';

import '../../schedule/models/schedule.dart';
import '../calendar_agenda.dart';
import '../ios_calendar_theme.dart';
import '../widgets/event_card.dart';

/// 列表视图：按天分组的日程清单（对齐 iOS「列表」与 Mac 日历的清单）：
/// 顶部吸顶日期头 + 事件卡 + 当天提醒事项。
class AgendaListView extends StatelessWidget {
  final List<DateTime> days;
  final Map<DateTime, List<Schedule>> eventsByDay;
  final Map<DateTime, List<String>> remindersByDay;
  final Color Function(Schedule) colorOf;
  final void Function(Schedule event) onTapEvent;
  final void Function(DateTime day) onTapDay;

  const AgendaListView({
    super.key,
    required this.days,
    required this.eventsByDay,
    required this.colorOf,
    required this.onTapEvent,
    required this.onTapDay,
    this.remindersByDay = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // 只保留有内容的日子（像 iOS 列表一样跳过空日）
    final groups = <(DateTime, List<Schedule>)>[];
    for (final day in days) {
      final events = eventsByDay[day] ?? const <Schedule>[];
      final reminders = remindersByDay[day] ?? const <String>[];
      if (events.isEmpty && reminders.isEmpty) continue;
      groups.add((day, events));
    }

    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text('这段时间没有日程', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '试试 ✨ 说人话建日程，或长按时间轴拖出时间段',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        for (final (day, events) in groups) ...[
          SliverToBoxAdapter(
            child: _DayGroupHeader(
              day: day,
              count: events.length + (remindersByDay[day]?.length ?? 0),
              onTap: () => onTapDay(day),
            ),
          ),
          SliverList.builder(
            itemCount: events.length + (remindersByDay[day]?.length ?? 0),
            itemBuilder: (context, index) {
              if (index < events.length) {
                final e = events[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
                  child: CalendarEventCard(
                    event: e,
                    color: colorOf(e),
                    onTap: () => onTapEvent(e),
                  ),
                );
              }
              final text = remindersByDay[day]![index - events.length];
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 2, 14, 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _DayGroupHeader extends StatelessWidget {
  final DateTime day;
  final int count;
  final VoidCallback onTap;

  const _DayGroupHeader({
    required this.day,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = isSameDay(day, DateTime.now());
    final relative = relativeDayLabel(day);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Row(
          children: [
            Text(
              dayLabel(day),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isToday ? IosCalendarTheme.today : scheme.onSurface,
              ),
            ),
            if (relative.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (isToday ? IosCalendarTheme.today : scheme.primary)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  relative,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isToday
                        ? IosCalendarTheme.today
                        : scheme.primary,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              '$count 项',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
