import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/components/desktop_wrapper/background.dart';
import 'package:moodiary/components/home_fab/home_fab_view.dart';
import 'package:moodiary/components/home_nativatorbar/navigatorbar.dart';
import 'package:moodiary/features/ai/ai_home_page.dart';
import 'package:moodiary/features/crm/crm_home_page.dart';
import 'package:moodiary/features/quick_capture/quick_capture_view.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/pages/home/calendar/calendar_view.dart';
import 'package:moodiary/pages/home/diary/diary_view.dart';
import 'package:moodiary/pages/home/media/media_view.dart';
import 'package:moodiary/pages/home/setting/setting_view.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';

import 'home_logic.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeLogic logic = Get.put(HomeLogic());

    return Scaffold(
      body: AdaptiveLayout(
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
                        destinations: [
                          NavigationDestination(
                            icon: const Icon(Icons.article_outlined),
                            label: context.l10n.homeNavigatorDiary,
                            selectedIcon: const Icon(Icons.article),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: context.l10n.homeNavigatorCalendar,
                            selectedIcon: const Icon(
                              Icons.calendar_month_rounded,
                            ),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.photo_library_outlined),
                            label: context.l10n.homeNavigatorMedia,
                            selectedIcon: const Icon(
                              Icons.photo_library_rounded,
                            ),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.business_outlined),
                            label: context.l10n.homeNavigatorCrm,
                            selectedIcon: const Icon(Icons.business_rounded),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: context.l10n.homeNavigatorAi,
                            selectedIcon: const Icon(
                              Icons.auto_awesome_rounded,
                            ),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.settings_outlined),
                            label: context.l10n.homeNavigatorSetting,
                            selectedIcon: const Icon(Icons.settings_rounded),
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
      bottomNavigationBar: HomeNavigatorBar(
        animation: logic.barAnimation,
        navigatorIndex: logic.navigatorIndex,
        onTap: logic.changeNavigator,
        onCapture: () => _openQuickCapture(context, logic),
        onMore: () => _showMoreSheet(context, logic),
        isToTopShow: logic.isToTopShow,
        onToTop: logic.toTop,
      ),
    );
  }

  Future<void> _openQuickCapture(
    BuildContext context,
    HomeLogic logic,
  ) async {
    await QuickCaptureSheet.show(
      context,
      onCreate: (type) async {
        if (Get.isBottomSheetOpen == true) Get.back();
        await logic.toEditPage(type: type);
      },
    );
    // 面板关闭（保存或失焦）后统一刷新首页各视图
    await logic.refreshDiaryLists();
  }

  void _showMoreSheet(BuildContext context, HomeLogic logic) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '更多',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              if (PrefUtil.getValue<bool>('moduleCrm') != false)
                ListTile(
                  leading: Icon(Icons.business_outlined, color: colorScheme.primary),
                  title: const Text('CRM'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Get.back();
                    logic.changeNavigator(3);
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.auto_awesome_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('AI 助手'),
                subtitle: const Text('与全部笔记/知识库对话'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Get.back();
                  logic.changeNavigator(4);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.mic_none_rounded,
                  color: colorScheme.primary,
                ),
                title: const Text('语音记录'),
                subtitle: const Text('录音转写 / 去口语化'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Get.back();
                  Get.toNamed(AppRoutes.voiceRecordPage);
                },
              ),
              ListTile(
                leading: Icon(Icons.settings_outlined, color: colorScheme.primary),
                title: const Text('设置'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Get.back();
                  logic.changeNavigator(5);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
