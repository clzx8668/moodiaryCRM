import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/nav/mobile_nav_config.dart';

/// 移动端底部导航（按钮可在设置中配置；默认 日记/日历/AI/设置）。
///
/// 快速收集保持右下角展开式 FAB（HomeFabComponent）。
class HomeNavigatorBar extends StatelessWidget {
  static const double defaultNavigatorBarHeight = 56.0;

  final Animation<double> animation;

  final RxInt navigatorIndex;

  /// 跳转 PageView 页面（参数为目的地 pageIndex）
  final Function(int) onTap;

  const HomeNavigatorBar({
    super.key,
    required this.animation,
    required this.navigatorIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    MobileNavConfig.ensureLoaded();
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final height = defaultNavigatorBarHeight + padding.bottom;

    return Visibility(
      visible: size.width < 600,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return SizedBox(
            height: height * animation.value,
            child: child,
          );
        },
        child: OverflowBox(
          maxHeight: height,
          alignment: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(
                  color: context.theme.colorScheme.outline.withValues(
                    alpha: 0.5,
                  ),
                  width: 0.5,
                ),
              ),
            ),
            child: Obx(() {
              final destinations = MobileNavConfig.items
                  .map(MobileNavConfig.byIndex)
                  .whereType<NavDestination>()
                  .toList();
              return Row(
                children: [
                  for (final d in destinations)
                    _slot(context, d),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, NavDestination destination) {
    final colorScheme = context.theme.colorScheme;
    final selected = navigatorIndex.value == destination.pageIndex;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(destination.pageIndex),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 24,
              color: selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: context.textTheme.labelSmall?.copyWith(
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
