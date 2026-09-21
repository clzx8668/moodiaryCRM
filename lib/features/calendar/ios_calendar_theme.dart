import 'package:flutter/material.dart';

import 'models/calendar_list.dart';

/// iOS 18 观感的视觉 token（贴在项目主题之上，不改项目主题）。
class IosCalendarTheme {
  /// 卡片圆角
  static const double cardRadius = 12;

  /// 容器圆角（月网格、面板）
  static const double panelRadius = 16;

  /// 胶囊分段控件圆角
  static const double pillRadius = 22;

  /// 事件卡底色：日历色 12% 叠在表面色上。
  static Color eventFill(Color calendarColor, Color surface) =>
      Color.alphaBlend(calendarColor.withValues(alpha: 0.14), surface);

  /// 事件卡描边（只有标题档才画）。
  static Color eventBorder(Color calendarColor) =>
      calendarColor.withValues(alpha: 0.34);

  /// 轻微投影（iOS 观感：几乎看不见，但有分层）。
  static List<BoxShadow> softShadow(ColorScheme scheme) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: scheme.brightness == Brightness.dark ? 0.32 : 0.06),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  /// 今天（iOS 红）
  static const Color today = Color(CalendarColors.today);

  /// 毛玻璃底：表面色 70% + sigma 24。
  static Color frostTint(ColorScheme scheme) =>
      scheme.surface.withValues(alpha: 0.72);

  static const double frostSigma = 24;

  /// 未知日历的兜底色
  static Color fallbackEventColor(ColorScheme scheme) =>
      const Color(CalendarColors.blue);

  /// 给定日历 id 取颜色（找不到 → 兜底蓝）。
  static Color colorOf(String? calendarId, Map<String, int> colorMap, ColorScheme scheme) {
    final id = calendarId;
    if (id != null && colorMap[id] != null) return Color(colorMap[id]!);
    final first = colorMap.values.isEmpty ? null : colorMap.values.first;
    return first == null ? fallbackEventColor(scheme) : Color(first);
  }
}
