import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/timeline/timeline_item.dart';
import 'package:moodiary/features/todo/todo_item.dart';

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

  // 时间轴 / 待办视图切换
  late RxBool showTodos = false.obs;

  late RxBool isFetchingTodos = false.obs;

  late RxBool isFetching = true.obs;

  late RxBool isControllerScrolling = false.obs;

  double velocityThreshold = 800;

  bool isUp = false;

  CalendarState();
}
