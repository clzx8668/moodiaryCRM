import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_recurrence.dart';
import 'package:moodiary/features/todo/todo_parser.dart';
import 'package:moodiary/features/todo/todo_item.dart';

void main() {
  group('Schedule occurrences', () {
    final from = DateTime(2026, 8, 1);
    final to = DateTime(2026, 8, 31, 23, 59);

    test('none 只返回 seed（在范围内时）', () {
      final seed = DateTime(2026, 8, 15, 9);
      final times = occurrences(RepeatType.none, seed, from, to);
      expect(times, [seed]);
    });

    test('none 在范围内不返回', () {
      final times = occurrences(
        RepeatType.none,
        DateTime(2026, 9, 1),
        from,
        to,
      );
      expect(times, isEmpty);
    });

    test('daily 展开每天', () {
      final times = occurrences(
        RepeatType.daily,
        DateTime(2026, 8, 10, 8, 30),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 14, 23, 59),
      );
      expect(times, hasLength(3));
      expect(times.first, DateTime(2026, 8, 12, 8, 30));
      expect(times.last, DateTime(2026, 8, 14, 8, 30));
    });

    test('weekly 每 7 天', () {
      final times = occurrences(
        RepeatType.weekly,
        DateTime(2026, 8, 3, 10),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 31, 23, 59),
      );
      expect(times, hasLength(5));
      expect(times.every((t) => t.weekday == DateTime.monday), isTrue);
    });

    test('monthly 不越界（31 日自动钳制到月末）', () {
      final times = occurrences(
        RepeatType.monthly,
        DateTime(2026, 1, 31, 9),
        DateTime(2026, 2, 1),
        DateTime(2026, 4, 30, 23, 59),
      );
      // Feb->28, Mar->31, Apr->30
      expect(times.first, DateTime(2026, 2, 28, 9));
      expect(times[1], DateTime(2026, 3, 31, 9));
      expect(times[2], DateTime(2026, 4, 30, 9));
    });

    test('yearly 每年同月同日', () {
      final times = occurrences(
        RepeatType.yearly,
        DateTime(2024, 6, 15, 12),
        DateTime(2026, 1, 1),
        DateTime(2028, 12, 31),
      );
      expect(times, [DateTime(2026, 6, 15, 12), DateTime(2027, 6, 15, 12), DateTime(2028, 6, 15, 12)]);
    });
  });

  group('Schedule.expand', () {
    test('复制并平移 endTime 保持时长', () {
      final s = Schedule()
        ..title = '例会'
        ..startTime = DateTime(2026, 8, 3, 9)
        ..endTime = DateTime(2026, 8, 3, 10)
        ..repeatType = RepeatType.weekly;
      final expanded = expand(
        [s],
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 31, 23, 59),
      );
      expect(expanded, hasLength(5));
      expect(
        expanded.first.endTime!.difference(expanded.first.startTime),
        const Duration(hours: 1),
      );
      // 原对象未被改动
      expect(s.startTime, DateTime(2026, 8, 3, 9));
    });
  });

  group('TodoParser.fromSchedule', () {
    test('投影为 schedule 待办条目', () {
      final s = Schedule()
        ..id = 'sch_1'
        ..title = '和客户对方案'
        ..startTime = DateTime(2026, 8, 20, 10)
        ..repeatType = RepeatType.weekly;
      final item = TodoParser.fromSchedule(s);
      expect(item.source, TodoSource.schedule);
      expect(item.isSchedule, isTrue);
      expect(item.scheduleId, 'sch_1');
      expect(item.text, '和客户对方案');
      expect(item.effectiveDate, DateTime(2026, 8, 20, 10));
    });
  });
}
