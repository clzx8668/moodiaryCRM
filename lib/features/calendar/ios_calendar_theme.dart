import 'package:flutter/material.dart';

import 'models/calendar_list.dart';

/// iOS 18 观感的视觉 token（贴在项目主题之上，不改项目主题）。
class IosCalendarTheme {
  // ---------------------------------------------------- 设计系统 Token（对齐需求文档 §6）

  /// 主色（选中态/按钮/标记）
  static const Color primaryLight = Color(0xFF007AFF);
  static const Color primaryDark = Color(0xFF0A84FF);

  /// 主背景 / 次级背景（卡片、侧边栏）
  static const Color bgPrimaryLight = Color(0xFFFFFFFF);
  static const Color bgPrimaryDark = Color(0xFF000000);
  static const Color bgSecondaryLight = Color(0xFFF2F2F7);
  static const Color bgSecondaryDark = Color(0xFF1C1C1E);

  /// 文字与分隔线
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color separatorLight = Color(0xFFC6C6C8);
  static const Color separatorDark = Color(0xFF38383A);
  static const Color completedTextDark = Color(0xFF636366);

  /// 事件块：底色 20% 透明 + 左侧实色边
  static const double eventFillAlpha = 0.20;

  /// 间距（8pt 网格）
  static const double spaceXxs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;

  /// 圆角
  static const double radiusCell = 3;
  static const double radiusEvent = 6;
  static const double radiusCard = 12;

  /// 关键尺寸（文档 §6.2）
  static const double navBarHeight = 44;
  static const double tabBarHeight = 49;
  static const double sidebarWidth = 240;
  static const double detailPanelWidth = 320;
  static const double hourHeightDefault = 60;
  static const double eventMinHeight = 24;

  /// 动画
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animDefault = Duration(milliseconds: 300);

  /// 给日历页套一层 iOS 色系（只影响这个页面，不动全局主题）
  static ThemeData scoped(ThemeData base) {
    final dark = base.brightness == Brightness.dark;
    final primary = dark ? primaryDark : primaryLight;
    final scheme = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      surface: dark ? bgPrimaryDark : bgPrimaryLight,
      surfaceContainerLow: dark ? bgSecondaryDark : bgSecondaryLight,
      outlineVariant: dark ? separatorDark : separatorLight,
      onSurfaceVariant: textSecondary,
    );
    return base.copyWith(
      colorScheme: scheme,
      dividerColor: dark ? separatorDark : separatorLight,
    );
  }

  /// 已完成提醒事项：文字弱化到 60%（文档 §3.4）
  static double get completedOpacity => 0.6;

  /// 事件块底色（20% 透明度）
  static Color eventFill20(Color calendarColor, Color surface) =>
      Color.alphaBlend(
        calendarColor.withValues(alpha: eventFillAlpha),
        surface,
      );

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
