import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';

/// 会话态：当前日记与页面级上下文（架构文档 6.2 分层之一）。
///
/// 只承载"这一页在编辑哪条记录"，不参与 Block 列表 / 流式等业务状态。
class CanvasState {
  /// 当前日记（路由参数 [Diary, bool]）
  late Diary diary;

  /// 是否展示操作菜单（日历等入口传入 false）
  late bool showAction;

  /// 是否正在滚动（AppBar 折叠联动）
  RxBool isScrolling = false.obs;

  /// 可观察标题（AppBar Obx 依赖；整篇编辑返回后刷新）
  RxString diaryTitle = ''.obs;

  CanvasState() {
    final args = Get.arguments;
    diary = args[0] as Diary;
    showAction = args[1] as bool? ?? true;
    diaryTitle.value = diary.title;
  }
}
