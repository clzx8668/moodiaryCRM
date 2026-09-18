import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/components/base/modal.dart';
import 'package:moodiary/components/desktop_wrapper/background.dart';
import 'package:moodiary/components/home_fab/home_fab_view.dart';
import 'package:moodiary/components/home_nativatorbar/navigatorbar.dart';
import 'package:moodiary/features/ai/ai_home_page.dart';
import 'package:moodiary/features/crm/crm_home_page.dart';
import 'package:moodiary/features/quick_capture/fab_gesture.dart';
import 'package:moodiary/features/quick_capture/quick_capture_view.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/pages/home/calendar/calendar_view.dart';
import 'package:moodiary/pages/home/diary/diary_view.dart';
import 'package:moodiary/pages/home/media/media_view.dart';
import 'package:moodiary/pages/home/setting/setting_view.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'home_logic.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 复用同一个 HomeLogic：避免因多次 build / Get.put 产生重复实例，
    // 导致头部入口拿到的 pageController 与可见 PageView 不一致。
    final HomeLogic logic = Get.isRegistered<HomeLogic>()
        ? Get.find<HomeLogic>()
        : Get.put(HomeLogic());

    return Scaffold(
      body: Stack(
        children: [
          AdaptiveLayout(
            transitionDuration: const Duration(milliseconds: 200),
            primaryNavigation: SlotLayout(
              config: {
                Breakpoints.mediumAndUp: SlotLayout.from(
                  key: const ValueKey('navigation medium'),
                  builder: (_) {
                    return GestureDetector(
                      onPanStart: (details) {
                        appWindow.startDragging();
                      },
                      child: Obx(() {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          color: context.theme.colorScheme.surfaceContainer,
                          child: AdaptiveScaffold.standardNavigationRail(
                            destinations:
                                [
                                      NavigationDestination(
                                        icon: const Icon(
                                          Icons.article_outlined,
                                        ),
                                        label: context.l10n.homeNavigatorDiary,
                                        selectedIcon: const Icon(Icons.article),
                                      ),
                                      NavigationDestination(
                                        icon: const Icon(
                                          Icons.calendar_month_outlined,
                                        ),
                                        label:
                                            context.l10n.homeNavigatorCalendar,
                                        selectedIcon: const Icon(
                                          Icons.calendar_month_rounded,
                                        ),
                                      ),
                                      NavigationDestination(
                                        icon: const Icon(
                                          Icons.photo_library_outlined,
                                        ),
                                        label: context.l10n.homeNavigatorMedia,
                                        selectedIcon: const Icon(
                                          Icons.photo_library_rounded,
                                        ),
                                      ),
                                      NavigationDestination(
                                        icon: const Icon(
                                          Icons.business_outlined,
                                        ),
                                        label: context.l10n.homeNavigatorCrm,
                                        selectedIcon: const Icon(
                                          Icons.business_rounded,
                                        ),
                                      ),
                                      NavigationDestination(
                                        icon: const Icon(
                                          Icons.auto_awesome_outlined,
                                        ),
                                        label: context.l10n.homeNavigatorAi,
                                        selectedIcon: const Icon(
                                          Icons.auto_awesome_rounded,
                                        ),
                                      ),
                                      NavigationDestination(
                                        icon: const Icon(
                                          Icons.settings_outlined,
                                        ),
                                        label:
                                            context.l10n.homeNavigatorSetting,
                                        selectedIcon: const Icon(
                                          Icons.settings_rounded,
                                        ),
                                      ),
                                    ]
                                    .map(
                                      (destination) =>
                                          AdaptiveScaffold.toRailDestination(
                                            destination,
                                          ),
                                    )
                                    .toList(),
                            selectedIndex: logic.navigatorIndex.value,
                            backgroundColor:
                                context.theme.colorScheme.surfaceContainer,
                            labelType: NavigationRailLabelType.all,
                            padding: EdgeInsets.zero,
                            trailing: Expanded(
                              child: DesktopHomeFabComponent(
                                toQuickCapture: () async {
                                  await _openQuickCapture(context, logic);
                                },
                                isToTopShow: logic.isToTopShow,
                                toTop: logic.toTop,
                                toNewDiary: () async {
                                  await logic.toEditPage(
                                    type: DiaryType.markdown,
                                  );
                                },
                              ),
                            ),
                            onDestinationSelected: logic.changeNavigator,
                          ),
                        );
                      }),
                    );
                  },
                ),
              },
            ),
            body: SlotLayout(
              config: {
                Breakpoints.standard: SlotLayout.from(
                  key: const ValueKey('body'),
                  builder: (_) {
                    return AdaptiveBackground(
                      child: PageView(
                        key: logic.bodyKey,
                        controller: logic.pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          DiaryPage(),
                          CalendarPage(),
                          MediaPage(),
                          CrmHomePage(),
                          AiHomePage(),
                          SettingPage(),
                        ],
                      ),
                    );
                  },
                ),
              },
            ),
          ),
          Modal(onTap: logic.closeFab, animation: logic.fabAnimation),
        ],
      ),
      bottomNavigationBar: HomeNavigatorBar(
        animation: logic.barAnimation,
        navigatorIndex: logic.navigatorIndex,
        onTap: logic.changeNavigator,
      ),
      floatingActionButton: HomeFabComponent(
        animation: logic.fabAnimation,
        shouldShow: logic.shouldShow,
        isToTopShow: logic.isToTopShow,
        isExpanded: logic.isFabExpanded,
        showShadow: true,
        openFab: () => _openQuickCapture(context, logic),
        // 长按直达录音（批次 89）；菜单改由上滑展开
        onLongPressRecord: () => _longPressVoiceRecord(context, logic),
        onSwipeOpenMenu: logic.openFab,
        toTop: logic.toTop,
        toNewDiary: () async {
          await logic.toEditPage(type: DiaryType.markdown);
        },
        closeFab: logic.closeFab,
      ),
    );
  }

  /// 长按 FAB：直达语音记录页并自动开始录音（首次给出一次手势提示）。
  Future<void> _longPressVoiceRecord(
    BuildContext context,
    HomeLogic logic,
  ) async {
    await HapticFeedback.mediumImpact();
    if (FabGesturePolicy.shouldShowHint(
      PrefUtil.getValue<bool>(FabGesturePolicy.hintPrefKey),
    )) {
      await PrefUtil.setValue(FabGesturePolicy.hintPrefKey, true);
      toast.info(message: FabGesturePolicy.hintMessage);
    }
    if (!context.mounted) return;
    await Get.toNamed(
      AppRoutes.voiceRecordPage,
      arguments: {'autoStart': true},
    );
    await logic.refreshDiaryLists();
  }

  Future<void> _openQuickCapture(BuildContext context, HomeLogic logic) async {
    // 面板只做速记；「新建日记」等入口在首页 FAB 展开菜单里，避免重复入口
    await QuickCaptureSheet.show(context);
    // 面板关闭（保存或失焦）后统一刷新首页各视图
    await logic.refreshDiaryLists();
  }
}
