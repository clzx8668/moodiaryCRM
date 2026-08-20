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

  CanvasState() {
    final args = Get.arguments;
    diary = args[0] as Diary;
    showAction = args[1] as bool? ?? true;
  }
}
