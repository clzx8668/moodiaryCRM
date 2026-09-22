import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';

import 'calendar_repository.dart';
import 'models/calendar_list.dart';

/// 信息扩展订阅：中国节假日日历（含调休补班）。
///
/// - 数据随包内置（`assets/calendar/china_holidays_2026.json`，来源 timor.tech，2026 年）；
/// - 首次使用时创建「中国节假日」日历（来源标记 `china-holiday`，只读）并写入全天事件；
/// - 幂等：日历已存在、或事件 id 已存在都不重复写；用户可在「日历管理」里隐藏/删除它。
class HolidayCalendar {
  static const String calendarId = 'china-holiday';
  static const String assetPath = 'assets/calendar/china_holidays_2026.json';

  /// 返回本次写入的事件数（已订阅过则返回 0）。
  static Future<int> ensure({AssetBundle? bundle}) async {
    final calendars = CalendarRepository();
    final existing = await calendars.getById(calendarId);
    // 已订阅过（哪怕用户后来软删/隐藏）就不再自动装回来，尊重用户选择
    if (existing != null) return 0;

    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final days = (data['days'] as List).cast<Map<String, dynamic>>();

    if (existing == null) {
      await calendars.create(
        id: calendarId,
        name: '中国节假日',
        color: CalendarColors.orange,
        source: 'china-holiday',
      );
    }

    final repo = ScheduleRepository();
    final seeded = await repo.listActive();
    final seededIds = seeded.map((e) => e.id).toSet();

    var count = 0;
    for (final day in days) {
      final date = DateTime.parse(day['date'] as String);
      final isHoliday = day['holiday'] == true;
      final name = day['name'] as String;
      final id = 'cn-holiday-${day['date']}-$name';
      if (seededIds.contains(id)) continue;
      await repo.create(
        Schedule()
          ..id = id
          ..title = isHoliday ? name : '$name（补班）'
          ..allDay = true
          ..startTime = date
          ..calendarId = calendarId
          ..tag = isHoliday ? 'holiday' : 'workday'
          ..notes = '中国节假日订阅（含调休），来源 timor.tech',
      );
      count++;
    }
    return count;
  }
}
