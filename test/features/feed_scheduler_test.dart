import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/feed/feed_models.dart';
import 'package:moodiary/features/feed/feed_scheduler.dart';

void main() {
  group('FeedScheduler.isDue', () {
    final now = DateTime(2026, 9, 14, 10);

    test('禁用源不刷新', () {
      final s = FeedSource(id: 'a', url: 'https://a', enabled: false);
      expect(FeedScheduler.isDue(s, now), isFalse);
    });

    test('从未刷新 → 到期', () {
      final s = FeedSource(id: 'a', url: 'https://a');
      expect(FeedScheduler.isDue(s, now), isTrue);
    });

    test('未到间隔 → 不到期；超过间隔 → 到期', () {
      final recent = FeedSource(id: 'a', url: 'https://a')
        ..lastFetchedAt = now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch;
      expect(FeedScheduler.isDue(recent, now), isFalse);

      final stale = FeedSource(id: 'a', url: 'https://a')
        ..lastFetchedAt = now
            .subtract(const Duration(hours: 7))
            .millisecondsSinceEpoch;
      expect(FeedScheduler.isDue(stale, now), isTrue);
    });

    test('自定义间隔', () {
      final s = FeedSource(id: 'a', url: 'https://a')
        ..lastFetchedAt = now
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch;
      expect(
        FeedScheduler.isDue(s, now, interval: const Duration(minutes: 20)),
        isTrue,
      );
    });
  });
}
