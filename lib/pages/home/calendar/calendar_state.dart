import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';

class CalendarState {
  late Rx<DateTime> currentMonth = DateTime.now().obs;

  //当前月份的日记
  late RxList<Diary> currentMonthDiaryList = <Diary>[].obs;

  // 每日活跃度（date -> 0~1，日历热力图着色用）
  late RxMap<DateTime, double> dailyActivity = <DateTime, double>{}.obs;

  late RxBool isFetching = true.obs;

  late RxBool isControllerScrolling = false.obs;

  double velocityThreshold = 800;

  bool isUp = false;

  CalendarState();
}
