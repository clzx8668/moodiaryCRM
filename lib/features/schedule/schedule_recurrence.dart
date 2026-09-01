import 'models/schedule.dart';

/// 重复规则展开（纯函数，便于单测）。
///
/// 以 [seed] 为首次发生时间，按 [RepeatType] 生成落在 `[from, to]` 的若干次
/// 发生时刻（含边界；单次日（daily/weekly/monthly/yearly）不含时间偏移，保持
/// seed 的时分不变）。[RepeatType.none] 只返回 seed 本身（若在范围内）。
List<DateTime> occurrences(
  RepeatType type,
  DateTime seed,
  DateTime from,
  DateTime to,
) {
  if (from.isAfter(to)) return const [];
  final base = _floorToMinute(seed);

  if (type == RepeatType.none) {
    return _inRange(base, from, to) ? [base] : const [];
  }

  final result = <DateTime>[];
  var guard = 0;
  const msPerDay = 24 * 3600 * 1000;
  final gapMs = from.difference(seed).inMilliseconds;

  for (var offset = _firstOffset(type, seed, gapMs, msPerDay);; offset++) {
    final cur = switch (type) {
      RepeatType.daily => base.add(Duration(days: offset)),
      RepeatType.weekly => base.add(Duration(days: offset * 7)),
      RepeatType.monthly => _monthAnchor(base, offset),
      RepeatType.yearly => _yearAnchor(base, offset),
      RepeatType.none => base,
    };
    if (cur.isAfter(to)) break;
    if (_inRange(cur, from, to)) result.add(cur);
    if (++guard > 100000) break;
  }
  return result;
}

int _firstOffset(
  RepeatType type,
  DateTime seed,
  int gapMs,
  int msPerDay,
) {
  if (gapMs <= 0) return 0;
  return switch (type) {
    RepeatType.daily => (gapMs / msPerDay).ceil(),
    RepeatType.weekly => (gapMs / (7 * msPerDay)).ceil(),
    RepeatType.monthly => (gapMs / (30 * msPerDay)).ceil(),
    RepeatType.yearly => (gapMs / (365 * msPerDay)).ceil(),
    RepeatType.none => 0,
  };
}

/// 把一组 [schedules] 展开为落在 `[from, to]` 的具体日程实例。
///
/// 每次发生都会复制 schedule 并把 [Schedule.startTime] 设为该次时刻；若原
/// 日程有 endTime，同样平移保持时长。
List<Schedule> expand(
  List<Schedule> schedules,
  DateTime from,
  DateTime to,
) {
  final result = <Schedule>[];
  for (final s in schedules) {
    final times = occurrences(s.repeatType, s.startTime, from, to);
    for (final t in times) {
      final copy = s.clone()..startTime = t;
      if (s.endTime != null) {
        final duration = s.endTime!.difference(s.startTime);
        copy.endTime = t.add(duration);
      }
      result.add(copy);
    }
  }
  result.sort((a, b) => a.startTime.compareTo(b.startTime));
  return result;
}

bool _inRange(DateTime t, DateTime from, DateTime to) =>
    !t.isBefore(from) && !t.isAfter(to);

DateTime _floorToMinute(DateTime d) =>
    DateTime(d.year, d.month, d.day, d.hour, d.minute);

/// 以 [anchor] 的「日」为锚定，返回其第 [months] 个月后的时间；目标日不足则
/// 钳制到当月最后一天（保持锚定日，避免 1/31 → 2/28 → 3/28 的偏移漂移）。
DateTime _monthAnchor(DateTime anchor, int months) {
  final base = anchor;
  final total = base.year * 12 + base.month - 1 + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  final day = base.day > lastDay ? lastDay : base.day;
  return DateTime(y, m, day, base.hour, base.minute);
}

DateTime _yearAnchor(DateTime anchor, int years) {
  final y = anchor.year + years;
  final lastDay = DateTime(y, anchor.month + 1, 0).day;
  final day = anchor.day > lastDay ? lastDay : anchor.day;
  return DateTime(y, anchor.month, day, anchor.hour, anchor.minute);
}
