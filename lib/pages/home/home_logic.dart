import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/components/frosted_glass_overlay/frosted_glass_overlay_logic.dart';
import 'package:moodiary/pages/home/calendar/calendar_logic.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';

class HomeLogic extends GetxController with GetTickerProviderStateMixin {
  RxBool isFabExpanded = false.obs;

  RxBool isToTopShow = false.obs;

  RxBool shouldShow = true.obs;

  RxInt navigatorIndex = 0.obs;

  late final GlobalKey bodyKey = GlobalKey();
  late final AnimationController _fabAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late Animation<double> fabAnimation = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
  );

  late final AnimationController _barAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late Animation<double> barAnimation = Tween(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(parent: _barAnimationController, curve: Curves.easeInOut),
  );

  late final PageController pageController = PageController();

  late final FrostedGlassOverlayLogic frostedGlassOverlayLogic =
      Bind.find<FrostedGlassOverlayLogic>();

  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  late final AppLifecycleListener _appLifecycleListener;

  @override
  void onReady() async {
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.inactive) {
          _privacyMode(isEnable: true);
          _lockPage();
        }
        if (state == AppLifecycleState.resumed) {
          _privacyMode(isEnable: false);
        }
      },
    );

    super.onReady();
  }

  @override
  void onClose() {
    _fabAnimationController.dispose();
    _barAnimationController.dispose();
    pageController.dispose();
    _appLifecycleListener.dispose();
    super.onClose();
  }

  void _lockPage() {
    if (PrefUtil.getValue<bool>('lock') == true &&
        PrefUtil.getValue<bool>('lockNow') == true) {
      if (Get.currentRoute != AppRoutes.editPage &&
          Get.currentRoute != AppRoutes.sharePage) {
        Get.toNamed(AppRoutes.lockPage, arguments: 'pause');
      }
    }
  }

  void _privacyMode({required bool isEnable}) {
    if (PrefUtil.getValue<bool>('backendPrivacy') == true) {
      isEnable
          ? frostedGlassOverlayLogic.enable()
          : frostedGlassOverlayLogic.disable();
    }
  }

  Future<void> openFab() async {
    await HapticFeedback.vibrate();
    isFabExpanded.value = true;
    await _fabAnimationController.forward();
  }

  Future<void> closeFab() async {
    await HapticFeedback.selectionClick();
    await _fabAnimationController.reverse();
    isFabExpanded.value = false;
  }

  Future<void> toTop() async {
    await diaryLogic.toTop();
  }

  /// 快速收集保存后刷新首页各视图（列表/网格/日历；块视图由 FutureBuilder 自动刷新）
  Future<void> refreshDiaryLists() async {
    // 复用编辑保存后证明有效的刷新链路（默认列表 + 各分类列表）
    try {
      await diaryLogic.refreshAll();
    } catch (_) {
      // 日记页尚未挂载时跳过，日历仍刷新
    }
    try {
      if (Bind.isRegistered<CalendarLogic>()) {
        final calendar = Bind.find<CalendarLogic>();
        await calendar.getMonthDiary(calendar.state.currentMonth.value);
      }
    } catch (_) {
      // 忽略日历刷新失败
    }
  }

  void changeNavigator(int index) {
    navigatorIndex.value = index;
    shouldShow.value = index == 0;
    pageController.jumpToPage(index);
  }

  Future<void> hideNavigatorBar() async {
    await _barAnimationController.forward();
  }

  Future<void> showNavigatorBar() async {
    await _barAnimationController.reverse();
  }

  void resetNavigatorBar() {
    _barAnimationController.reset();
  }

  Future<void> toEditPage({required DiaryType type}) async {
    HapticFeedback.selectionClick();
    String? categoryId;
    if (diaryLogic.tabController.index == 0) {
      categoryId = null;
    } else {
      categoryId =
          diaryLogic.state.categoryList[diaryLogic.tabController.index - 1].id;
    }

    /// 需要注意，返回值为 '' 时才是没有选择分类，而返回值为 null 时，是没有进行操作直接返回
    final res = await Get.toNamed(
      AppRoutes.editPage,
      arguments: [type, categoryId],
    );
    _fabAnimationController.reset();
    isFabExpanded.value = false;
    if (res != null) {
      if (res == '') {
        await diaryLogic.updateDiary(null);
      } else {
        await diaryLogic.updateDiary(res);
      }
    }
  }
}
