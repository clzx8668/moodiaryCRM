import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/activity/calendar_activity.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/timeline/timeline_item.dart';
import 'package:moodiary/features/todo/todo_aggregator.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/features/todo/todo_toggle_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'calendar_state.dart';

class CalendarLogic extends GetxController {
  final CalendarState state = CalendarState();

  late final ItemScrollController itemScrollController = ItemScrollController();
  late final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();
  late final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  late final ScrollOffsetListener scrollOffsetListener =
      ScrollOffsetListener.create();

  final ScheduleRepository _scheduleRepo = ScheduleRepository();
  final TodoToggleService _toggleService = TodoToggleService();

  @override
  void onReady() async {
    await getMonthDiary(state.currentMonth.value);
    super.onReady();
  }

  // 获取当前月份的日记
  Future<void> getMonthDiary(DateTime value) async {
    state.isFetching.value = true;
    state.currentMonth.value = value;
    state.currentMonthDiaryList.value = await IsarUtil.getAllDiariesSorted();
    // 计算每日活跃度（字数 + Block 数 + 心情）
    final blockCounts = await IsarUtil.getBlockCountsByDiary();
    state.dailyActivity.value = CalendarActivity.calculate(
      state.currentMonthDiaryList,
      blockCounts,
    );
    // 加载当前月日程（展开重复规则）
    await loadSchedules();
    // 时间轴：日记 + CRM 记录 + 日程按时间合并降序
    final crmEntities = await IsarUtil.getAllCrmEntities();
    final items = <TimelineItem>[
      for (final diary in state.currentMonthDiaryList)
        TimelineItem(time: diary.time, diary: diary),
      for (final crm in crmEntities)
        TimelineItem(time: crm.updatedAt, crm: crm),
      for (final schedule in state.schedules)
        TimelineItem(time: schedule.startTime, schedule: schedule),
    ]..sort((a, b) => b.time.compareTo(a.time));
    state.timelineItems.value = items;
    state.isFetching.value = false;
    await loadTodos(date: state.selectedDay.value);
  }

  /// 加载当前显示月份的日程（展开重复规则，供月历标记与时间轴用）。
  Future<void> loadSchedules() async {
    final month = state.currentMonth.value;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    state.schedules.value = await _scheduleRepo.byRange(start, end);
  }

  /// 选中某天（重置视图月份并刷新该日待办）。
  Future<void> selectDay(DateTime day) async {
    final d = DateTime(day.year, day.month, day.day);
    state.selectedDay.value = d;
    final month = state.currentMonth.value;
    if (d.year != month.year || d.month != month.month) {
      await getMonthDiary(DateTime(d.year, d.month, 1));
    } else {
      await loadTodos(date: d);
    }
  }

  /// 切换月视图 / 周视图（移动端上下滑动）。
  void toggleWeek(bool value) => state.showWeek.value = value;

  /// 设置每周起始日（1=周一 … 7=周日），持久化。
  void setWeekStart(int weekday) {
    state.weekStart.value = weekday;
    PrefUtil.setValue<int>('calendarWeekStart', weekday);
  }

  /// 月视图：上一月/下一月（保留选中日，月末自动钳制）。
  Future<void> navigateMonth(int delta) async {
    final m = state.currentMonth.value;
    final target = DateTime(m.year, m.month + delta, 1);
    final last = DateTime(target.year, target.month + 1, 0).day;
    final day = state.selectedDay.value.day >= last
        ? last
        : state.selectedDay.value.day;
    state.selectedDay.value = DateTime(target.year, target.month, day);
    await getMonthDiary(target);
  }

  /// 周视图：上一周/下一周。
  Future<void> navigateWeek(int delta) async {
    final sel = state.selectedDay.value;
    await selectDay(sel.add(Duration(days: delta * 7)));
  }

  /// 回到今天。
  Future<void> goToday() async {
    await selectDay(DateTime.now());
  }

  /// 快捷新建日程后刷新。
  Future<Schedule> quickAddSchedule(
    String title, {
    DateTime? startTime,
    DateTime? endTime,
    bool allDay = false,
    int? remindOffsetMin,
    RepeatType repeatType = RepeatType.none,
    SchedulePriority priority = SchedulePriority.none,
    String? tag,
    int? bgColor,
    String? notes,
  }) async {
    final created = await _scheduleRepo.create(
      Schedule()
        ..title = title
        ..startTime = startTime ?? DateTime.now()
        ..endTime = endTime
        ..allDay = allDay
        ..remindOffsetMin = remindOffsetMin
        ..repeatType = repeatType
        ..priority = priority
        ..tag = tag
        ..bgColor = bgColor
        ..notes = notes ?? '',
    );
    await reload();
    return created;
  }

  /// 保存/删除日程后刷新。
  Future<void> reload() async {
    await getMonthDiary(state.currentMonth.value);
  }

  /// 加载跨源待办（本地 Todo Block + Twenty task）
  Future<void> loadTodos({DateTime? date, bool includeDone = true}) async {
    state.isFetchingTodos.value = true;
    state.todoItems.value = await TodoAggregator.load(
      date: date,
      includeDone: includeDone,
    );
    state.isFetchingTodos.value = false;
  }

  /// 勾选/取消本地待办后刷新
  Future<void> toggleTodo(TodoItem item) async {
    await _toggleService.toggle(item);
    await loadTodos(date: state.selectedDay.value);
  }

  /// 日历快捷新建待办（Diary + todo Block），随后刷新日历与待办
  Future<void> quickAddTodo(String text, DateTime? dueDate) async {
    await TodoAggregator.quickAdd(text: text, dueDate: dueDate);
    await getMonthDiary(state.currentMonth.value);
  }

  int _pendingScrollOperations = 0;

  Future<void> animateToSelectedDateWithLock(DateTime value) async {
    final index = state.timelineItems.indexWhere(
      (element) =>
          element.time.year == value.year &&
          element.time.month == value.month &&
          element.time.day == value.day,
    );
    if (index < 0) return;
    _pendingScrollOperations++;
    state.isControllerScrolling.value = true;
    try {
      await itemScrollController.scrollTo(
        index: index,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOutQuart,
      );
    } finally {
      _pendingScrollOperations--;
      if (_pendingScrollOperations == 0) {
        state.isControllerScrolling.value = false;
      }
    }
  }

  void onVerticalDragEnd(DragEndDetails details) {
    final double velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity > state.velocityThreshold) {
      //open(state.isUp);
    }
  }

  // // 选中日期后重新获取日记
  // Future<void> updateDate(DateTime value) async {
  //   state.selectedDate.value = value;
  //   await getDiary();
  // }

  // void open(value) {
  //   if (value && !expansibleController.isExpanded) {
  //     expansibleController.expand();
  //   } else if (!value && expansibleController.isExpanded) {
  //     expansibleController.collapse();
  //   }
  // }

  DateTime? findLatestDateInMonth(List<DateTime> dates, int year, int month) {
    // 过滤出符合条件的日期
    final List<DateTime> filteredDates = dates.where((date) {
      return date.year == year && date.month == month;
    }).toList();

    // 如果没有符合条件的日期，返回 null
    if (filteredDates.isEmpty) {
      return null;
    }

    // 找到最晚的日期
    filteredDates.sort((a, b) => b.compareTo(a)); // 降序排序
    return filteredDates.first; // 返回第一个元素，即最晚的日期
  }
}
