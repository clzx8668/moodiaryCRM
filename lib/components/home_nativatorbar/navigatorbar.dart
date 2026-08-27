import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/modal.dart';
import 'package:moodiary/l10n/l10n.dart';

class HomeNavigatorBar extends StatelessWidget {
  static const double defaultNavigatorBarHeight = 56.0;

  final Animation<double> animation;

  final RxInt navigatorIndex;

  final Function(int) onTap;

  final Modal modal;

  const HomeNavigatorBar({
    super.key,
    required this.animation,
    required this.navigatorIndex,
    required this.onTap,
    required this.modal,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);

    final navigatorBarHeight = defaultNavigatorBarHeight + padding.bottom;
    return Visibility(
      visible: size.width < 600,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return SizedBox(
            height: (navigatorBarHeight) * animation.value,
            child: child,
          );
        },
        child: OverflowBox(
          maxHeight: navigatorBarHeight,
          alignment: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.theme.colorScheme.outline.withValues(
                    alpha: 0.5,
                  ),
                  width: 0.5,
                ),
              ),
            ),
            child: Stack(
              children: [
                Obx(() {
                  return NavigationBar(
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.article_outlined),
                        label: context.l10n.homeNavigatorDiary,
                        selectedIcon: const Icon(Icons.article),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: context.l10n.homeNavigatorCalendar,
                        selectedIcon: const Icon(Icons.calendar_month_rounded),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.photo_library_outlined),
                        label: context.l10n.homeNavigatorMedia,
                        selectedIcon: const Icon(Icons.photo_library_rounded),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.business_outlined),
                        label: context.l10n.homeNavigatorCrm,
                        selectedIcon: const Icon(Icons.business_rounded),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: context.l10n.homeNavigatorAi,
                        selectedIcon: const Icon(Icons.auto_awesome_rounded),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.settings_outlined),
                        label: context.l10n.homeNavigatorSetting,
                        selectedIcon: const Icon(Icons.settings_rounded),
                      ),
                    ],
                    selectedIndex: navigatorIndex.value,
                    height: navigatorBarHeight,
                    onDestinationSelected: onTap,
                    backgroundColor: context.theme.colorScheme.surfaceContainer,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysHide,
                  );
                }),
                modal,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
