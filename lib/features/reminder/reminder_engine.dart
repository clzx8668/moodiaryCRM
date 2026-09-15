import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_recurrence.dart';

/// 到点提醒引擎（纯函数 + 纯数据，便于单测）。
///
/// 提醒来源两类：
/// - 本地日程/待办（`Schedule`）：设置了提醒提前量（`remindOffsetMin`）且未完成的，
///   提醒时刻 = 开始时间 − 提前量；重复日程按**每次发生**各提醒一次；
/// - CRM 提醒（`LocalReminder`）：提醒时刻 = `remindAt`。
///
/// 触发窗口为 `[dueAt, dueAt + grace]`：
/// - 到点即触发一次（同一发生时刻只提醒一次，记录在 [ReminderState.fired]）；
/// - 应用未运行期间错过的提醒**不补**（超过窗口即放弃），避免开机被一堆积压提醒轰炸；
///   过期/加急事项在日历「今日」收件箱已有标记，不需要提醒重复承担；
/// - 「稍后 10 分钟」写入 [ReminderState.snoozed]，延后期满后无条件补一次。
enum ReminderSource { schedule, crm }

/// 默认触发窗口（分钟）。
const int reminderGraceMinutes = 15;

/// 已提醒/延后记录的保留时长（小时），超过则清理，避免 Pref 无限增长。
const int reminderRetentionHours = 48;

/// 一条命中的提醒。
class ReminderHit {
  const ReminderHit({
    required this.key,
    required this.title,
    required this.dueAt,
    required this.at,
    required this.source,
    required this.refId,
    this.offsetMinutes,
  });

  /// 唯一键（重复日程含具体发生时刻），用于去重与延后。
  final String key;

  /// 标题（日程标题 / CRM 提醒标题）。
  final String title;

  /// 提醒触发时刻。
  final DateTime dueAt;

  /// 事件本身的时间（日程开始时间 / CRM 提醒时间）。
  final DateTime at;

  final ReminderSource source;

  /// 关联对象 id（日程 id / CRM 提醒 id）。
  final String refId;

  /// 提前量（分钟），仅日程来源有值。
  final int? offsetMinutes;

  /// 「15:00 开始 · 提前 15 分钟」这类副标题。
  String get subtitle {
    final time = formatClock(at);
    if (source == ReminderSource.crm) return 'CRM 提醒 · $time';
    final offset = offsetMinutes ?? 0;
    if (offset <= 0) return '$time 开始';
    return '$time 开始 · 提前 ${formatOffset(offset)}';
  }

  /// 日期 + 时间的完整描述（用于多条提醒同屏时区分）。
  String get fullTitle => '$title（${formatClock(at)}）';

  static String formatClock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String formatOffset(int minutes) {
    if (minutes >= 1440 && minutes % 1440 == 0) {
      return '${minutes ~/ 1440} 天';
    }
    if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60} 小时';
    return '$minutes 分钟';
  }
}

/// 已提醒 / 已延后记录（键 → 分钟时间戳）。
class ReminderState {
  ReminderState({Map<String, int>? fired, Map<String, int>? snoozed})
    : fired = {...?fired},
      snoozed = {...?snoozed};

  final Map<String, int> fired;
  final Map<String, int> snoozed;

  ReminderState copy() => ReminderState(fired: fired, snoozed: snoozed);

  Map<String, dynamic> toJson() => {'fired': fired, 'snoozed': snoozed};

  factory ReminderState.fromJson(Map<String, dynamic> json) => ReminderState(
    fired: _intMap(json['fired']),
    snoozed: _intMap(json['snoozed']),
  );

  bool hasFired(String key) => fired.containsKey(key);

  /// 是否仍处于延后期（[now] 之前不再打扰）。
  bool isSnoozed(String key, DateTime now) =>
      (snoozed[key] ?? 0) > _minuteStamp(now);

  /// 延后到 [until]。
  void snoozeUntil(String key, DateTime until) {
    // 延后即重新排期：清除「已提醒」记录，只保留延后目标。
    fired.remove(key);
    snoozed[key] = _minuteStamp(until);
  }
}

/// 一轮提醒计算的结果：命中的提醒 + 更新后的状态（需由调用方持久化）。
class ReminderPlan {
  const ReminderPlan({required this.hits, required this.state});

  final List<ReminderHit> hits;
  final ReminderState state;

  bool get isEmpty => hits.isEmpty;
}

/// 计算此刻应当发出的提醒。
ReminderPlan planReminders({
  required DateTime now,
  Iterable<Schedule> schedules = const [],
  Iterable<LocalReminder> crmReminders = const [],
  ReminderState? state,
  Duration grace = const Duration(minutes: reminderGraceMinutes),
}) {
  final updated = (state ?? ReminderState()).copy();
  final nowStamp = _minuteStamp(now);
  final scheduleById = <String, Schedule>{};
  final reminderById = <String, LocalReminder>{};
  final candidates = <String, ReminderHit>{};

  for (final schedule in schedules) {
    scheduleById[schedule.id] = schedule;
    if (schedule.deleted || schedule.done) continue;
    final offsetMinutes = schedule.remindOffsetMin;
    if (offsetMinutes == null) continue;
    final offset = Duration(minutes: offsetMinutes);
    // 展开出「提醒时刻落在窗口内」的发生：start ∈ [now - grace + offset, now + offset]
    final occurrences = expand(
      [schedule],
      now.subtract(grace).add(offset),
      now.add(offset),
    );
    for (final occurrence in occurrences) {
      final dueAt = occurrence.startTime.subtract(offset);
      if (dueAt.isAfter(now)) continue;
      if (now.difference(dueAt) > grace) continue;
      final key =
          'schedule:${schedule.id}@${_minuteStamp(occurrence.startTime)}';
      candidates[key] = ReminderHit(
        key: key,
        title: occurrence.title,
        dueAt: dueAt,
        at: occurrence.startTime,
        source: ReminderSource.schedule,
        refId: schedule.id,
        offsetMinutes: offsetMinutes,
      );
    }
  }

  for (final reminder in crmReminders) {
    reminderById[reminder.id] = reminder;
    if (reminder.isCompleted) continue;
    final dueAt = reminder.remindAt;
    if (dueAt.isAfter(now)) continue;
    if (now.difference(dueAt) > grace) continue;
    final key = 'crm:${reminder.id}';
    candidates[key] = ReminderHit(
      key: key,
      title: reminder.title,
      dueAt: dueAt,
      at: reminder.remindAt,
      source: ReminderSource.crm,
      refId: reminder.id,
    );
  }

  // 延后期满的条目无条件补提醒（不受触发窗口约束，也不依赖重复展开）。
  for (final entry in updated.snoozed.entries.toList()) {
    if (entry.value > nowStamp) continue; // 仍在延后期
    final hit = candidates[entry.key] ??
        _rebuildHit(entry.key, scheduleById, reminderById);
    if (hit == null) {
      updated.snoozed.remove(entry.key); // 来源已删除/已完成
      continue;
    }
    candidates[entry.key] = hit;
  }

  final hits = <ReminderHit>[];
  for (final hit in candidates.values) {
    final snoozeUntil = updated.snoozed[hit.key];
    if (snoozeUntil != null) {
      // 延后记录优先于已提醒记录：期满即补提醒（上一步已收集）。
      if (snoozeUntil > nowStamp) continue;
    } else if (updated.hasFired(hit.key)) {
      continue;
    }
    hits.add(hit);
    updated.fired[hit.key] = nowStamp;
    updated.snoozed.remove(hit.key);
  }

  hits.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  _prune(updated, now);
  return ReminderPlan(hits: hits, state: updated);
}

/// 由提醒键还原命中详情（用于「稍后提醒」延后期满后的补提醒）。
ReminderHit? _rebuildHit(
  String key,
  Map<String, Schedule> schedules,
  Map<String, LocalReminder> reminders,
) {
  if (key.startsWith('crm:')) {
    final reminder = reminders[key.substring('crm:'.length)];
    if (reminder == null || reminder.isCompleted) return null;
    return ReminderHit(
      key: key,
      title: reminder.title,
      dueAt: reminder.remindAt,
      at: reminder.remindAt,
      source: ReminderSource.crm,
      refId: reminder.id,
    );
  }
  if (!key.startsWith('schedule:')) return null;
  final rest = key.substring('schedule:'.length);
  final sep = rest.lastIndexOf('@');
  if (sep <= 0) return null;
  final schedule = schedules[rest.substring(0, sep)];
  final stamp = int.tryParse(rest.substring(sep + 1));
  final offsetMinutes = schedule?.remindOffsetMin;
  if (schedule == null ||
      schedule.deleted ||
      schedule.done ||
      offsetMinutes == null ||
      stamp == null) {
    return null;
  }
  final at = DateTime.fromMillisecondsSinceEpoch(stamp * 60000);
  return ReminderHit(
    key: key,
    title: schedule.title,
    dueAt: at.subtract(Duration(minutes: offsetMinutes)),
    at: at,
    source: ReminderSource.schedule,
    refId: schedule.id,
    offsetMinutes: offsetMinutes,
  );
}

/// 清理过期记录（保留窗口内与未来（延后中）的条目）。
void _prune(ReminderState state, DateTime now) {
  final cutoff = _minuteStamp(now) - reminderRetentionHours * 60;
  state.fired.removeWhere((_, value) => value < cutoff);
  state.snoozed.removeWhere((_, value) => value < cutoff);
}

int _minuteStamp(DateTime t) => t.millisecondsSinceEpoch ~/ 60000;

Map<String, int> _intMap(Object? raw) {
  if (raw is! Map) return {};
  final result = <String, int>{};
  raw.forEach((key, value) {
    if (key is String && value is num) result[key] = value.toInt();
  });
  return result;
}
