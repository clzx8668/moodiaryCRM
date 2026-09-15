import 'package:get/get.dart';
import 'package:moodiary/features/quick_capture/quick_capture_view.dart';
import 'package:moodiary/pages/home/home_logic.dart';

/// 全局快速收集入口（供全局快捷键、托盘等「非首页」路径调用）。
///
/// 复用首页 FAB 的同一套 `QuickCaptureSheet`，不新建第二套编辑器；
/// 保存后同样刷新首页列表。
class GlobalCapture {
  GlobalCapture._();

  /// 是否已打开收集面板（避免快捷键连按叠加多层）。
  static bool get isOpen => Get.isBottomSheetOpen == true;

  static Future<void> open() async {
    if (isOpen) return;
    final context = Get.context;
    if (context == null) return;

    await QuickCaptureSheet.show(context);
    _refreshHome();
  }

  static void _refreshHome() {
    if (!Get.isRegistered<HomeLogic>()) return;
    // 面板关闭（保存或失焦）后统一刷新首页各视图，与首页 FAB 行为一致
    Get.find<HomeLogic>().refreshDiaryLists();
  }
}

/// 供测试与解析使用的快捷键文案。
const String globalShortcutLabel = 'Ctrl + Alt + M';
