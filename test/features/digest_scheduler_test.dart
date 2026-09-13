import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/digest/digest_prompts.dart';
import 'package:moodiary/features/ai/digest/digest_scheduler.dart';
import 'package:moodiary/features/ai/digest/digest_service.dart';

void main() {
  group('DigestScheduler 触发判断', () {
    final monday = DateTime(2026, 9, 14, 21, 30); // 周一
    final tuesday = DateTime(2026, 9, 15, 21, 30);

    test('每日：未到触发时刻不生成', () {
      expect(
        DigestScheduler.shouldRunDaily(
          now: DateTime(2026, 9, 14, 20, 0),
          hour: 21,
          existingTitles: const [],
        ),
        isFalse,
      );
    });

    test('每日：到点且当天无回望 → 生成', () {
      expect(
        DigestScheduler.shouldRunDaily(
          now: monday,
          hour: 21,
          existingTitles: const [],
        ),
        isTrue,
      );
    });

    test('每日：当天已有回望 → 跳过', () {
      final title = '每日回望 ${DigestService.label(DigestPeriod.daily, monday)}';
      expect(
        DigestScheduler.shouldRunDaily(
          now: monday,
          hour: 21,
          existingTitles: [title],
        ),
        isFalse,
      );
    });

    test('每周：仅周一且到点生成', () {
      expect(
        DigestScheduler.shouldRunWeekly(
          now: monday,
          hour: 21,
          existingTitles: const [],
        ),
        isTrue,
      );
      expect(
        DigestScheduler.shouldRunWeekly(
          now: tuesday,
          hour: 21,
          existingTitles: const [],
        ),
        isFalse,
      );
      expect(
        DigestScheduler.shouldRunWeekly(
          now: DateTime(2026, 9, 14, 20, 0),
          hour: 21,
          existingTitles: const [],
        ),
        isFalse,
      );
    });
  });
}
