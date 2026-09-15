import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/reminder/reminder_engine.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';

Schedule _schedule({
  String id = 's1',
  String title = '客户回访',
  required DateTime start,
  int? remindOffsetMin,
  RepeatType repeatType = RepeatType.none,
  bool done = false,
  bool deleted = false,
}) {
  return Schedule()
    ..id = id
    ..title = title
    ..startTime = start
    ..repeatType = repeatType
    ..remindOffsetMin = remindOffsetMin
    ..done = done
    ..deleted = deleted;
}

LocalReminder _reminder({
  String id = 'r1',
  String title = '合同回款',
  required DateTime remindAt,
  bool isCompleted = false,
}) {
  return LocalReminder(
    id: id,
    title: title,
    remindAt: remindAt,
    isCompleted: isCompleted,
  );
}

void main() {
  final now = DateTime(2026, 9, 15, 15, 0);

  group('planReminders 日程提醒', () {
    test('提前 15 分钟 → 15:00 提醒（15:15 开始）', () {
      final plan = planReminders(
        now: now,
        schedules: [
          _schedule(start: DateTime(2026, 9, 15, 15, 15), remindOffsetMin: 15),
        ],
      );
      expect(plan.hits, hasLength(1));
      final hit = plan.hits.first;
      expect(hit.title, '客户回访');
      expect(hit.source, ReminderSource.schedule);
      expect(hit.dueAt, DateTime(2026, 9, 15, 15, 0));
      expect(hit.at, DateTime(2026, 9, 15, 15, 15));
      expect(hit.subtitle, '15:15 开始 · 提前 15 分钟');
    });

    test('未到点不提醒', () {
      final plan = planReminders(
        now: now,
        schedules: [
          _schedule(start: DateTime(2026, 9, 15, 16, 0), remindOffsetMin: 15),
        ],
      );
      expect(plan.isEmpty, isTrue);
    });

    test('同一发生只提醒一次', () {
      final schedule = _schedule(
        start: DateTime(2026, 9, 15, 15, 10),
        remindOffsetMin: 15,
      );
      final first = planReminders(now: now, schedules: [schedule]);
      expect(first.hits, hasLength(1));
      final second = planReminders(
        now: now.add(const Duration(minutes: 1)),
        schedules: [schedule],
        state: first.state,
      );
      expect(second.isEmpty, isTrue);
    });

    test('超过触发窗口不补提醒（应用未运行期间错过）', () {
      final plan = planReminders(
        now: now,
        schedules: [
          _schedule(
            start: DateTime(2026, 9, 15, 9, 30),
            remindOffsetMin: 30,
          ),
        ],
      );
      expect(plan.isEmpty, isTrue);
    });

    test('窗口边界（正好 15 分钟）仍提醒，超过 1 分钟则跳过', () {
      final plan = planReminders(
        now: now,
        schedules: [
          _schedule(start: DateTime(2026, 9, 15, 14, 45), remindOffsetMin: 0),
        ],
      );
      expect(plan.hits, hasLength(1));
      final missed = planReminders(
        now: now,
        schedules: [
          _schedule(
            id: 's4',
            start: DateTime(2026, 9, 15, 14, 44),
            remindOffsetMin: 0,
          ),
        ],
      );
      expect(missed.isEmpty, isTrue);
    });

    test('未设置提醒 / 已完成 / 已删除不提醒', () {
      final plan = planReminders(
        now: now,
        schedules: [
          _schedule(start: DateTime(2026, 9, 15, 15, 0)),
          _schedule(
            id: 's2',
            start: DateTime(2026, 9, 15, 15, 0),
            remindOffsetMin: 0,
            done: true,
          ),
          _schedule(
            id: 's3',
            start: DateTime(2026, 9, 15, 15, 0),
            remindOffsetMin: 0,
            deleted: true,
          ),
        ],
      );
      expect(plan.isEmpty, isTrue);
    });

    test('重复日程按每次发生分别提醒（昨天已提醒，今天再提醒）', () {
      final schedule = _schedule(
        id: 'rep',
        start: DateTime(2026, 9, 14, 15, 0),
        remindOffsetMin: 0,
        repeatType: RepeatType.daily,
      );
      final yesterday = planReminders(
        now: DateTime(2026, 9, 14, 15, 0),
        schedules: [schedule],
      );
      expect(yesterday.hits, hasLength(1));
      final today = planReminders(
        now: now,
        schedules: [schedule],
        state: yesterday.state,
      );
      expect(today.hits, hasLength(1));
      expect(today.hits.first.key, isNot(yesterday.hits.first.key));
    });
  });

  group('planReminders CRM 提醒', () {
    test('到点提醒并输出副标题', () {
      final plan = planReminders(
        now: now,
        crmReminders: [_reminder(remindAt: DateTime(2026, 9, 15, 14, 55))],
      );
      expect(plan.hits, hasLength(1));
      expect(plan.hits.first.source, ReminderSource.crm);
      expect(plan.hits.first.subtitle, 'CRM 提醒 · 14:55');
    });

    test('已完成/未到点不提醒', () {
      final plan = planReminders(
        now: now,
        crmReminders: [
          _reminder(
            id: 'r2',
            remindAt: DateTime(2026, 9, 15, 14, 55),
            isCompleted: true,
          ),
          _reminder(id: 'r3', remindAt: DateTime(2026, 9, 15, 16, 0)),
        ],
      );
      expect(plan.isEmpty, isTrue);
    });
  });

  group('稍后提醒（延后）', () {
    test('延后期内静默，期满后补提醒一次', () {
      final schedule = _schedule(
        start: DateTime(2026, 9, 15, 15, 0),
        remindOffsetMin: 0,
      );
      final first = planReminders(now: now, schedules: [schedule]);
      expect(first.hits, hasLength(1));

      final key = first.hits.first.key;
      final snoozed = first.state.copy()
        ..snoozeUntil(key, now.add(const Duration(minutes: 10)));

      // 延后期内：静默
      final during = planReminders(
        now: now.add(const Duration(minutes: 5)),
        schedules: [schedule],
        state: snoozed,
      );
      expect(during.isEmpty, isTrue);

      // 延后期满：即便原始提醒时刻早已超出触发窗口，也要补一次
      final after = planReminders(
        now: now.add(const Duration(minutes: 11)),
        schedules: [schedule],
        state: snoozed,
      );
      expect(after.hits, hasLength(1));
      expect(after.hits.first.key, key);

      // 补提醒后不再重复
      final again = planReminders(
        now: now.add(const Duration(minutes: 12)),
        schedules: [schedule],
        state: after.state,
      );
      expect(again.isEmpty, isTrue);
    });

    test('延后条目对应的日程已删除 → 丢弃延后记录', () {
      final schedule = _schedule(
        start: DateTime(2026, 9, 15, 15, 0),
        remindOffsetMin: 0,
      );
      final plan = planReminders(now: now, schedules: [schedule]);
      final state = plan.state.copy()
        ..snoozeUntil(plan.hits.first.key, now);
      final removed = planReminders(
        now: now,
        schedules: [schedule..deleted = true],
        state: state,
      );
      expect(removed.isEmpty, isTrue);
      expect(removed.state.snoozed, isEmpty);
    });
  });

  group('ReminderState', () {
    test('JSON 往返一致', () {
      final state = ReminderState(
        fired: {'schedule:s1@100': 100},
        snoozed: {'crm:r1': 200},
      );
      final restored = ReminderState.fromJson(state.toJson());
      expect(restored.fired, {'schedule:s1@100': 100});
      expect(restored.snoozed, {'crm:r1': 200});
    });

    test('超过保留期的记录被清理', () {
      final stale = ReminderState(
        fired: {
          'schedule:old@1':
              now.subtract(const Duration(hours: 50)).millisecondsSinceEpoch ~/
              60000,
          'schedule:fresh@2': now.millisecondsSinceEpoch ~/ 60000,
        },
      );
      final plan = planReminders(now: now, state: stale);
      expect(plan.state.fired.keys, ['schedule:fresh@2']);
    });

    test('formatOffset 文案', () {
      expect(ReminderHit.formatOffset(5), '5 分钟');
      expect(ReminderHit.formatOffset(60), '1 小时');
      expect(ReminderHit.formatOffset(120), '2 小时');
      expect(ReminderHit.formatOffset(1440), '1 天');
    });
  });
}
