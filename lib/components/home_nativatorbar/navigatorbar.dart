import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/l10n/l10n.dart';

/// 移动端 Get 式底部导航：首页/日历 + 中央记录键 + 媒体/更多。
///
/// 桌面端（≥600）不使用本组件，仍走左侧 NavigationRail。
class HomeNavigatorBar extends StatelessWidget {
  static const double defaultNavigatorBarHeight = 64.0;

  final Animation<double> animation;

  final RxInt navigatorIndex;

  /// 直接跳转 PageView 页面（首页/日历/媒体）
  final Function(int) onTap;

  /// 点击中央记录键（打开快速收集面板）
  final VoidCallback? onCapture;

  /// 点击“更多”（由 HomePage 打开底部面板：CRM/AI/设置等）
  final VoidCallback? onMore;

  /// 列表滚回顶部小按钮
  final RxBool isToTopShow;
  final VoidCallback? onToTop;

  const HomeNavigatorBar({
    super.key,
    required this.animation,
    required this.navigatorIndex,
    required this.onTap,
    this.onCapture,
    this.onMore,
    required this.isToTopShow,
    this.onToTop,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: _buildBar(context)),
                // 回顶按钮：出现在底栏上方右侧，避免依赖旧的展开式 FAB。
                Obx(() {
                  if (!isToTopShow.value || onToTop == null) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    right: 12,
                    bottom: height + 8,
                    child: Material(
                      color: context.theme.colorScheme.tertiaryContainer,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        tooltip: '回到顶部',
                        visualDensity: VisualDensity.compact,
                        onPressed: onToTop,
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          color:
                              context.theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final moreActive = navigatorIndex.value >= 3;

    Widget slot({
      required int index,
      required IconData icon,
      required IconData selectedIcon,
      required String label,
      required VoidCallback onPressed,
    }) {
      final selected = navigatorIndex.value == index;
      return Expanded(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 24,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                label,
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

    return Row(
      children: [
        slot(
          index: 0,
          icon: Icons.article_outlined,
          selectedIcon: Icons.article_rounded,
          label: context.l10n.homeNavigatorDiary,
          onPressed: () => onTap(0),
        ),
        slot(
          index: 1,
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          label: context.l10n.homeNavigatorCalendar,
          onPressed: () => onTap(1),
        ),
        Expanded(
          child: Center(
            child: Semantics(
              button: true,
              label: '快速记录',
              child: Material(
                color: colorScheme.primary,
                shape: const CircleBorder(),
                elevation: 3,
                shadowColor: colorScheme.shadow.withValues(alpha: 0.25),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onCapture,
                  onLongPress: onCapture,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(
                      Icons.mic_rounded,
                      color: colorScheme.onPrimary,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        slot(
          index: 2,
          icon: Icons.photo_library_outlined,
          selectedIcon: Icons.photo_library_rounded,
          label: context.l10n.homeNavigatorMedia,
          onPressed: () => onTap(2),
        ),
        Expanded(
          child: InkWell(
            onTap: onMore,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.more_horiz_rounded,
                  size: 24,
                  color: moreActive
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 3),
                Text(
                  '更多',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: moreActive
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: moreActive ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
