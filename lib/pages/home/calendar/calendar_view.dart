import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/components/diary_card/calendar_diary_card_view.dart';
import 'package:moodiary/components/time_line/time_line_view.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/schedule/views/quick_add_schedule_sheet.dart';
import 'package:moodiary/features/schedule/views/schedule_detail_page.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'calendar_logic.dart';

const kCalAccent = Color(0xFFF57C00);
const _weekdayChars = ['一', '二', '三', '四', '五', '六', '日'];

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final CalendarLogic logic = Get.put(CalendarLogic());

  List<String> _weekLabels(int weekStart) => [
    for (var i = 0; i < 7; i++) _weekdayChars[(weekStart - 1 + i) % 7],
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;
    final column = Column(
      children: [
        Obx(() => _buildHeader(context)),
        const SizedBox(height: 4),
        Obx(() => _buildCalendarGrid(context)),
        Obx(() => _buildWeekToggle(context)),
        const SizedBox(height: 4),
        _buildModeSwitcher(context),
        const SizedBox(height: 4),
        Expanded(child: _buildContent(context)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(8),
      child: SafeArea(
        child: Stack(
          children: [
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildModeSwitcher(context),
                        const SizedBox(height: 4),
                        Expanded(child: _buildContent(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 380,
                    child: Column(
                      children: [
                        Obx(() => _buildHeader(context)),
                        const SizedBox(height: 4),
                        Obx(() => _buildCalendarGrid(context)),
                        Obx(() => _buildWeekToggle(context)),
                      ],
                    ),
                  ),
                ],
              )
            else
              column,
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton(
                backgroundColor: kCalAccent,
                foregroundColor: Colors.white,
                onPressed: () => _quickAdd(context),
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final state = logic.state;
    return Row(
      children: [
        IconButton(
          tooltip: state.showWeek.value ? '上一周' : '上一月',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            if (state.showWeek.value) {
              logic.navigateWeek(-1);
            } else {
              logic.navigateMonth(-1);
            }
          },
        ),
        Expanded(
          child: InkWell(
            onTap: () => _pickYearMonth(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_centerLabel(), style: theme.textTheme.titleMedium),
                  Text(
                    _subLabel(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: state.showWeek.value ? '下一周' : '下一月',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            if (state.showWeek.value) {
              logic.navigateWeek(1);
            } else {
              logic.navigateMonth(1);
            }
          },
        ),
        IconButton(
          tooltip: '回到今天',
          icon: const Icon(Icons.today_rounded),
          onPressed: () => logic.goToday(),
        ),
        PopupMenuButton<int>(
          tooltip: '日历设置',
          icon: const Icon(Icons.tune_rounded),
          onSelected: (v) {
            if (v == 1 || v == 7) logic.setWeekStart(v);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 1,
              child: Text(state.weekStart.value == 1 ? '周起始：周一 ✓' : '周起始：周一'),
            ),
            PopupMenuItem(
              value: 7,
              child: Text(state.weekStart.value == 7 ? '周起始：周日 ✓' : '周起始：周日'),
            ),
          ],
        ),
      ],
    );
  }

  String _centerLabel() {
    final state = logic.state;
    final m = state.currentMonth.value;
    if (!state.showWeek.value) return '${m.year}年${m.month}月';
    final sel = state.selectedDay.value;
    final week = _weekDays(sel, state.weekStart.value);
    return '${week.first.month}月${week.first.day}日';
  }

  String _subLabel() {
    final state = logic.state;
    if (!state.showWeek.value) {
      final d = state.selectedDay.value;
      return '${_weekName(d.weekday)} · ${d.month}月${d.day}日';
    }
    final week = _weekDays(state.selectedDay.value, state.weekStart.value);
    return '至 ${week.last.month}月${week.last.day}日';
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final theme = Theme.of(context);
    final state = logic.state;
    final month = state.currentMonth.value;
    final showWeek = state.showWeek.value;
    final selected = state.selectedDay.value;
    final weekStart = state.weekStart.value;

    final dates = showWeek ? _weekDays(selected, weekStart) : _monthDays(month.year, month.month, weekStart);
    final labels = _weekLabels(weekStart);

    final schedules = state.schedules.value;
    final scheduleCount = <DateTime, int>{};
    for (final s in schedules) {
      final d = s.day;
      scheduleCount[d] = (scheduleCount[d] ?? 0) + 1;
    }
    final diarySet = <DateTime>{};
    for (final diary in state.currentMonthDiaryList.value) {
      diarySet.add(DateTime(diary.time.year, diary.time.month, diary.time.day));
    }

    return GestureDetector(
      key: const ValueKey('calendar-grid'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        // 原手势：上滑收起成周、下滑展开回月
        if (v < -400 && !showWeek) logic.toggleWeek(true);
        if (v > 400 && showWeek) logic.toggleWeek(false);
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
            Row(
              children: [
                for (final w in labels)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var week = 0; week < dates.length ~/ 7; week++)
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _dayCell(
                        theme,
                        dates[week * 7 + i],
                        month,
                        selected,
                        scheduleCount[dates[week * 7 + i]] ?? 0,
                        diarySet.contains(dates[week * 7 + i]),
                        showWeek,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _dayCell(
    ThemeData theme,
    DateTime date,
    DateTime month,
    DateTime selected,
    int scheduleCount,
    bool hasDiary,
    bool showWeek,
  ) {
    final inMonth = date.month == month.month && date.year == month.year;
    final isToday = _sameDay(date, DateTime.now());
    final isSelected = _sameDay(date, selected);

    final Color bg;
    final Color fg;
    if (isToday) {
      bg = kCalAccent;
      fg = Colors.white;
    } else if (isSelected) {
      bg = theme.colorScheme.primary;
      fg = Colors.white;
    } else {
      bg = Colors.transparent;
      fg = inMonth
          ? theme.colorScheme.onSurface
          : theme.colorScheme.outline;
    }

    return InkWell(
      onTap: () => logic.selectDay(date),
      onLongPress: () => _quickAdd(context, initial: date),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
              ),
              child: Text(
                date.day.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scheduleCount > 0)
                  ...List.generate(
                    scheduleCount.clamp(0, 3),
                    (_) => const _Dot(color: kCalAccent),
                  ),
                if (hasDiary) const _Dot(color: Color(0xFF2EB872)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekToggle(BuildContext context) {
    final state = logic.state;
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.center,
      child: InkWell(
        onTap: () => logic.toggleWeek(!state.showWeek.value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: state.showWeek.value ? 0.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                state.showWeek.value ? '月视图' : '周视图',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitcher(BuildContext context) {
    final state = logic.state;
    return Obx(
      () => Row(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('待办'),
                icon: Icon(Icons.task_alt_rounded, size: 16),
              ),
              ButtonSegment(
                value: false,
                label: Text('时间轴'),
                icon: Icon(Icons.timeline_rounded, size: 16),
              ),
            ],
            selected: {state.showTodos.value},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: (selection) {
              state.showTodos.value = selection.first;
            },
          ),
          const Spacer(),
          if (state.showTodos.value) _dayLabel(context),
        ],
      ),
    );
  }

  Widget _dayLabel(BuildContext context) {
    final d = logic.state.selectedDay.value;
    final theme = Theme.of(context);
    return Text(
      '${d.month}月${d.day}日',
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final state = logic.state;
    return Obx(
      () => state.showTodos.value ? _buildTodoList(context) : _buildTimeline(context),
    );
  }

  Widget _buildTodoList(BuildContext context) {
    final state = logic.state;
    if (state.isFetchingTodos.value) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = state.todoItems.value;
    if (items.isEmpty) {
      return _empty(context, FontAwesomeIcons.listCheck, '这一天暂无待办');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _TodoCard(
          item: item,
          onToggle: () async {
            if (item.source == TodoSource.crmEvent) return;
            await logic.toggleTodo(item);
          },
          onTap: () => _openTodo(context, item),
        );
      },
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final state = logic.state;
    if (state.isFetching.value) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = state.timelineItems.value;
    if (items.isEmpty) {
      return _empty(context, FontAwesomeIcons.boxOpen, '还没有内容');
    }
    return ScrollablePositionedList.builder(
      itemBuilder: (context, index) {
        final item = items[index];
        final Color actionColor;
        final Widget child;
        if (item.isDiary) {
          actionColor =
              Color.lerp(
                AppColor.emoColorList.first,
                AppColor.emoColorList.last,
                item.diary!.mood,
              )!;
          child = CalendarDiaryCardComponent(diary: item.diary!);
        } else if (item.isSchedule) {
          actionColor = item.schedule!.bgColor == null
              ? kCalAccent
              : Color(item.schedule!.bgColor!);
          child = _ScheduleTimelineCard(schedule: item.schedule!);
        } else {
          actionColor = _crmColor(item.crm!.entityType);
          child = _CrmTimelineCard(crm: item.crm!);
        }
        return TimeLineComponent(
          actionColor: actionColor,
          child: Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : 4.0,
              bottom: index == items.length - 1 ? 0 : 4.0,
            ),
            child: child,
          ),
        );
      },
      itemScrollController: logic.itemScrollController,
      itemPositionsListener: logic.itemPositionsListener,
      scrollOffsetController: logic.scrollOffsetController,
      scrollOffsetListener: logic.scrollOffsetListener,
      itemCount: items.length,
    );
  }

  Widget _empty(BuildContext context, IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    );
  }

  Future<void> _pickYearMonth(BuildContext context) async {
    final m = logic.state.currentMonth.value;
    final picked = await Get.dialog<(int, int)>(
      _YearMonthPickerDialog(initialYear: m.year, initialMonth: m.month),
    );
    if (picked != null) {
      await logic.selectDay(DateTime(picked.$1, picked.$2, 1));
    }
  }

  Future<void> _quickAdd(BuildContext context, {DateTime? initial}) async {
    final created = await showQuickAddScheduleSheet(context, initial: initial);
    if (created != null && mounted) {
      await logic.reload();
    }
  }

  Future<void> _openTodo(BuildContext context, TodoItem item) async {
    if (item.isSchedule) {
      final schedule = await ScheduleRepository().getById(item.scheduleId);
      if (!mounted) return;
      if (schedule == null) {
        toast.info(message: '日程不存在');
        return;
      }
      final changed = await Get.to<bool>(
        () => ScheduleDetailPage(editable: schedule),
      );
      if (changed == true && mounted) await logic.reload();
      return;
    }
    if (item.isLocal) {
      final diary = await IsarUtil.getDiaryById(item.diaryId);
      if (!mounted) return;
      if (diary == null) {
        toast.info(message: '关联日记不存在');
        return;
      }
      Get.toNamed(AppRoutes.diaryPage, arguments: [diary, true]);
      return;
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Text(
          '来源：Twenty 任务\nTwenty ID：${item.twentyId}\n状态：${item.done ? '已完成' : '未完成'}',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('关闭')),
        ],
      ),
    );
  }
}

List<DateTime> _monthDays(int year, int month, int weekStart) {
  final first = DateTime(year, month, 1);
  final offset = (first.weekday - weekStart + 7) % 7;
  final start = first.subtract(Duration(days: offset));
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final cells = ((offset + daysInMonth) / 7).ceil() * 7;
  return [for (var i = 0; i < cells; i++) start.add(Duration(days: i))];
}

List<DateTime> _weekDays(DateTime day, int weekStart) {
  final offset = (day.weekday - weekStart + 7) % 7;
  final start = day.subtract(Duration(days: offset));
  return [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekName(int weekday) => switch (weekday) {
  DateTime.monday => '周一',
  DateTime.tuesday => '周二',
  DateTime.wednesday => '周三',
  DateTime.thursday => '周四',
  DateTime.friday => '周五',
  DateTime.saturday => '周六',
  _ => '周日',
};

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TodoCard({
    required this.item,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSchedule = item.isSchedule;
    final accent = isSchedule ? kCalAccent : theme.colorScheme.primary;
    return Card.outlined(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: ListTile(
        dense: true,
        leading: item.source == TodoSource.crmEvent
            ? Icon(
                item.done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: item.done ? accent : theme.colorScheme.outline,
              )
            : Checkbox(
                value: item.done,
                activeColor: accent,
                onChanged: (_) => onToggle(),
              ),
        title: Text(
          item.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: item.isOverdue && !item.done
              ? const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)
              : item.done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Row(
          children: [
            if (item.isOverdue) _badge(theme, '过期', Colors.red),
            if (item.isUrgent) ...[
              const SizedBox(width: 4),
              _badge(theme, '加急', const Color(0xFFFB8C00)),
            ],
            if (item.isFloating) ...[
              const SizedBox(width: 4),
              _badge(theme, '浮动', theme.colorScheme.onSurfaceVariant),
            ],
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${item.dueDate != null ? '${item.dueDate!.month}月${item.dueDate!.day}日 · ' : ''}'
                '${isSchedule ? '日程' : item.isLocal ? '日记待办' : item.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        trailing: Icon(
          isSchedule
              ? Icons.event_rounded
              : item.isLocal
              ? Icons.article_outlined
              : Icons.cloud_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _badge(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ScheduleTimelineCard extends StatelessWidget {
  final Schedule schedule;
  const _ScheduleTimelineCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = schedule.bgColor == null ? kCalAccent : Color(schedule.bgColor!);
    return Card(
      margin: EdgeInsets.zero,
      color: Color.lerp(accent, theme.colorScheme.surface, 0.82),
      child: ListTile(
        leading: Icon(Icons.event_rounded, color: accent),
        title: Text(schedule.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_fmtTime(schedule.startTime)} · ${schedule.repeatType.label}'),
        trailing: schedule.done
            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
            : null,
        onTap: () {},
      ),
    );
  }
}

class _CrmTimelineCard extends StatelessWidget {
  final CrmEntityCache crm;
  const _CrmTimelineCard({required this.crm});

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(Icons.business_rounded, color: _crmColor(crm.entityType)),
        title: Text(crm.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_crmTypeLabel(crm.entityType)),
        dense: true,
      ),
    );
  }
}

class _YearMonthPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  const _YearMonthPickerDialog({
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<_YearMonthPickerDialog> createState() => _YearMonthPickerDialogState();
}

class _YearMonthPickerDialogState extends State<_YearMonthPickerDialog> {
  late int _year = widget.initialYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    return AlertDialog(
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _year--),
          ),
          Expanded(
            child: Center(child: Text('$_year年', style: theme.textTheme.titleLarge)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setState(() => _year++),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            for (var m = 1; m <= 12; m++)
              _MonthCell(
                label: months[m - 1],
                selected: _year == widget.initialYear && m == widget.initialMonth,
                onTap: () => Get.back(result: (_year, m)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kCalAccent : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

Color _crmColor(String type) => switch (type) {
  'account' => const Color(0xFF1E88E5),
  'contact' => const Color(0xFF43A047),
  'opportunity' => const Color(0xFFFB8C00),
  'contract' => const Color(0xFF8E24AA),
  'product' => const Color(0xFF00897B),
  'quote' => const Color(0xFF6D4C41),
  _ => const Color(0xFF90A4AE),
};

String _crmTypeLabel(String type) => switch (type) {
  'account' => '客户',
  'contact' => '联系人',
  'opportunity' => '商机',
  'contract' => '合同',
  'product' => '产品',
  'quote' => '报价',
  _ => '记录',
};

String _fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
