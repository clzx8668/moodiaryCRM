import 'dart:ui';

import 'package:flutter/material.dart';

import '../ios_calendar_theme.dart';

/// 毛玻璃容器（顶栏 / 底部胶囊 / 悬浮面板统一用它）。
class FrostedPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double sigma;
  final Color? tint;
  final Border? border;
  final List<BoxShadow>? shadow;

  const FrostedPanel({
    super.key,
    required this.child,
    this.radius = IosCalendarTheme.panelRadius,
    this.padding,
    this.sigma = IosCalendarTheme.frostSigma,
    this.tint,
    this.border,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radiusValue = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radiusValue,
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: radiusValue,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? IosCalendarTheme.frostTint(scheme),
              borderRadius: radiusValue,
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 顶栏用的无圆角毛玻璃（贴在页面顶部整条铺满）。
class FrostedTopBar extends StatelessWidget {
  final Widget child;
  final double height;

  const FrostedTopBar({super.key, required this.child, this.height = 52});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: IosCalendarTheme.frostSigma,
          sigmaY: IosCalendarTheme.frostSigma,
        ),
        child: Container(
          height: height,
          color: IosCalendarTheme.frostTint(scheme),
          child: child,
        ),
      ),
    );
  }
}
