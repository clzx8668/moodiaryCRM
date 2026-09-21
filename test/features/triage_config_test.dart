import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/triage/triage_config.dart';
import 'package:moodiary/features/ai/triage/triage_types.dart';

void main() {
  group('TriageQuota（额度）', () {
    test('不限制（0）时不算耗尽，剩余为 -1', () {
      const q = TriageQuota();
      expect(q.unlimited, isTrue);
      expect(q.exhausted, isFalse);
      expect(q.remaining, -1);
      expect(q.usage, 0);
    });

    test('有上限时：用量达到上限即耗尽', () {
      const q = TriageQuota(monthlyLimit: 100, usedThisMonth: 99);
      expect(q.remaining, 1);
      expect(q.exhausted, isFalse);
      expect(q.usage, closeTo(0.99, 1e-9));
      expect(q.copyWith(usedThisMonth: 100).exhausted, isTrue);
    });

    test('用量超过上限也不会算出负数剩余', () {
      const q = TriageQuota(monthlyLimit: 50, usedThisMonth: 80);
      expect(q.remaining, 0);
      expect(q.exhausted, isTrue);
    });
  });

  group('TriageConfig（序列化与开关）', () {
    test('默认值：平衡档、不允许敏感上云、展示说明', () {
      const cfg = TriageConfig();
      expect(cfg.level, TriageLevel.balanced);
      expect(cfg.allowSensitiveToCloud, isFalse);
      expect(cfg.showExplanations, isTrue);
      expect(cfg.disabledOperations, isEmpty);
      for (final op in TriageOperation.values) {
        expect(cfg.isEnabled(op), isTrue);
      }
    });

    test('JSON 往返保持全部字段', () {
      const cfg = TriageConfig(
        level: TriageLevel.conservative,
        allowSensitiveToCloud: true,
        disabledOperations: {
          TriageOperation.autoSummary,
          TriageOperation.autoClassify,
        },
        quota: TriageQuota(monthlyLimit: 200, usedThisMonth: 7, month: '2026-09'),
        showExplanations: false,
      );
      final round = TriageConfig.fromJson(cfg.toJson());
      expect(round.level, TriageLevel.conservative);
      expect(round.allowSensitiveToCloud, isTrue);
      expect(round.disabledOperations, cfg.disabledOperations);
      expect(round.quota.monthlyLimit, 200);
      expect(round.quota.usedThisMonth, 7);
      expect(round.quota.month, '2026-09');
      expect(round.showExplanations, isFalse);
    });

    test('JSON 里出现未知操作名时安全忽略', () {
      final cfg = TriageConfig.fromJson({
        'level': 'balanced',
        'disabledOperations': ['autoSummary', 'not_a_real_op', 42],
      });
      expect(cfg.disabledOperations, {TriageOperation.autoSummary});
    });

    test('JSON 损坏/字段缺失时回退默认值', () {
      final cfg = TriageConfig.fromJson({'level': 'nonsense'});
      expect(cfg.level, TriageLevel.balanced);
      expect(cfg.allowSensitiveToCloud, isFalse);
      expect(cfg.quota.unlimited, isTrue);
    });

    test('copyWith 只改指定字段', () {
      const base = TriageConfig();
      final next = base.copyWith(level: TriageLevel.aggressive);
      expect(next.level, TriageLevel.aggressive);
      expect(next.allowSensitiveToCloud, base.allowSensitiveToCloud);
      expect(next.showExplanations, base.showExplanations);
    });
  });

  group('档位文案', () {
    test('三档都有中文标签与说明（设置页要展示）', () {
      for (final level in TriageLevel.values) {
        expect(level.label.trim(), isNotEmpty);
        expect(level.description.trim(), isNotEmpty);
      }
      expect(TriageLevel.balanced.label, contains('平衡'));
    });
  });

  group('月份标记', () {
    test('currentMonth 补零', () {
      expect(TriageConfigStore.currentMonth(DateTime(2026, 9, 21)), '2026-09');
      expect(TriageConfigStore.currentMonth(DateTime(2026, 12, 1)), '2026-12');
    });
  });
}
