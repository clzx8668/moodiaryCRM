import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/timeline/timeline_item.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/persistence/pref.dart';

class CalendarState {
  late Rx<DateTime> currentMonth = DateTime.now().obs;

  //当前月份的日记
  late RxList<Diary> currentMonthDiaryList = <Diary>[].obs;

  // 每日活跃度（date -> 0~1，日历热力图着色用）
  late RxMap<DateTime, double> dailyActivity = <DateTime, double>{}.obs;

  // 时间轴条目（日记 + CRM 记录合并）
  late RxList<TimelineItem> timelineItems = <TimelineItem>[].obs;

  // 跨源待办（本地 Todo Block + Twenty task，P2.2）
  late RxList<TodoItem> todoItems = <TodoItem>[].obs;

  // 待办/日程（独立 Schedule 实体，批次 B；当前展开范围）
  late RxList<Schedule> schedules = <Schedule>[].obs;

  // 选中日期（默认今天；点击月历某天更新）
  late Rx<DateTime> selectedDay = DateTime.now().obs;

  // 日历模式：false=月视图，true=周视图（移动端上下滑动切换）
  late RxBool showWeek = false.obs;

  /// 每周起始日：1=周一 … 7=周日（默认周一；持久化到 prefs）
  late RxInt weekStart = (PrefUtil.getValue<int>('calendarWeekStart') ?? 1).obs;

  // 时间轴 / 待办视图切换
  late RxBool showTodos = true.obs;

  late RxBool isFetchingTodos = false.obs;

  late RxBool isFetching = true.obs;

  late RxBool isControllerScrolling = false.obs;

  double velocityThreshold = 800;

  bool isUp = false;

  CalendarState();
}
