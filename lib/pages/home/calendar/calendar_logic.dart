import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/activity/calendar_activity.dart';
import 'package:moodiary/features/timeline/timeline_item.dart';
import 'package:moodiary/features/todo/todo_aggregator.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/persistence/isar.dart';
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

  @override
  void onReady() async {
    await getMonthDiary(state.currentMonth.value);
    super.onReady();
  }

  // 获取当前月份的日记
  Future<void> getMonthDiary(DateTime value) async {
    state.isFetching.value = true;
    state.currentMonth.value = value;
    // state.currentMonthDiaryList.value =
    //     await IsarUtil.getDiaryByMonth(value.year, value.month);
    state.currentMonthDiaryList.value = await IsarUtil.getAllDiariesSorted();
    // 计算每日活跃度（字数 + Block 数 + 心情）
    final blockCounts = await IsarUtil.getBlockCountsByDiary();
    state.dailyActivity.value = CalendarActivity.calculate(
      state.currentMonthDiaryList,
      blockCounts,
    );
    // 时间轴：日记 + CRM 记录按时间合并降序
    final crmEntities = await IsarUtil.getAllCrmEntities();
    final items = <TimelineItem>[
      for (final diary in state.currentMonthDiaryList)
        TimelineItem(time: diary.time, diary: diary),
      for (final crm in crmEntities)
        TimelineItem(time: crm.updatedAt, crm: crm),
    ]..sort((a, b) => b.time.compareTo(a.time));
    state.timelineItems.value = items;
    state.isFetching.value = false;
    await loadTodos();
  }

  /// 加载跨源待办（本地 Todo Block + Twenty task）
  Future<void> loadTodos({bool includeDone = true}) async {
    state.isFetchingTodos.value = true;
    state.todoItems.value = await TodoAggregator.load(
      includeDone: includeDone,
    );
    state.isFetchingTodos.value = false;
  }

  /// 勾选/取消本地待办后刷新
  Future<void> toggleTodo(TodoItem item) async {
    await TodoAggregator.toggleLocal(item);
    await loadTodos();
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
