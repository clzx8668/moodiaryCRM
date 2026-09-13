import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/persistence/pref.dart';

/// 一个可放入移动端底部导航的目的地。
class NavDestination {
  /// 对应 HomePage PageView 的下标
  final int pageIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const NavDestination({
    required this.pageIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// 移动端底部导航配置：用户可在设置中选择显示哪些按钮。
///
/// 默认：日记 / 日历 / AI / 设置。存储走 PrefUtil（key = `mobileNavItems`）。
class MobileNavConfig {
  MobileNavConfig._();

  static const String prefKey = 'mobileNavItems';

  /// 全部可选目的地（顺序即设置页展示顺序）。
  static const List<NavDestination> all = [
    NavDestination(
      pageIndex: 0,
      label: '日记',
      icon: Icons.article_outlined,
      selectedIcon: Icons.article_rounded,
    ),
    NavDestination(
      pageIndex: 1,
      label: '日历',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    NavDestination(
      pageIndex: 2,
      label: '媒体',
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library_rounded,
    ),
    NavDestination(
      pageIndex: 3,
      label: 'CRM',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business_rounded,
    ),
    NavDestination(
      pageIndex: 4,
      label: 'AI',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
    ),
    NavDestination(
      pageIndex: 5,
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  /// 默认展示的四项（用户偏好）。
  static const List<int> defaultItems = [0, 1, 4, 5];

  static const int minItems = 2;
  static const int maxItems = 5;

  /// 当前生效的导航项（pageIndex 列表，RxList 便于 UI 即时刷新）。
  static final RxList<int> items = defaultItems.obs;

  static bool _loaded = false;

  static NavDestination? byIndex(int pageIndex) {
    for (final d in all) {
      if (d.pageIndex == pageIndex) return d;
    }
    return null;
  }

  /// 清洗配置：去除非法/重复项，保持 all 的顺序，约束数量上下限。
  static List<int> sanitize(List<int> raw) {
    final valid = all.map((e) => e.pageIndex).toSet();
    final picked = raw.where(valid.contains).toSet();
    final ordered = all
        .map((e) => e.pageIndex)
        .where(picked.contains)
        .toList();
    if (ordered.length < minItems) return List<int>.from(defaultItems);
    if (ordered.length > maxItems) return ordered.take(maxItems).toList();
    return ordered;
  }

  /// 首次读取（幂等）。
  static void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    items.assignAll(loadFromPref());
  }

  static List<int> loadFromPref() {
    try {
      final raw = PrefUtil.getValue<String>(prefKey) ?? '';
      if (raw.trim().isEmpty) return List<int>.from(defaultItems);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return sanitize(decoded.map((e) => int.tryParse('$e') ?? -1).toList());
      }
    } catch (_) {
      // 容错：坏配置回退默认
    }
    return List<int>.from(defaultItems);
  }

  static Future<void> save(List<int> raw) async {
    final clean = sanitize(raw);
    items.assignAll(clean);
    await PrefUtil.setValue(prefKey, jsonEncode(clean));
  }

  static bool contains(int pageIndex) => items.contains(pageIndex);
}
