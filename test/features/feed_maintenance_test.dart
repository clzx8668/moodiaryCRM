import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/feed/feed_maintenance.dart';

void main() {
  group('FeedMaintenance.plan', () {
    test('同源同标题保留最新，其余回收', () {
      final entries = [
        FeedEntryRef(
          diaryId: 'old',
          sourceUrl: 'https://feed.example.com',
          title: '周刊第 408 期',
          time: DateTime(2026, 8, 28),
        ),
        FeedEntryRef(
          diaryId: 'new',
          sourceUrl: 'https://feed.example.com',
          title: '周刊第 408 期',
          time: DateTime(2026, 9, 4),
        ),
        FeedEntryRef(
          diaryId: 'other',
          sourceUrl: 'https://feed.example.com',
          title: '另一篇',
          time: DateTime(2026, 9, 1),
        ),
      ];
      final plan = FeedMaintenance.plan(entries);
      expect(plan.recycleDiaryIds, ['old']);
      expect(plan.duplicateGroups, 1);
    });

    test('不同来源不合并', () {
      final entries = [
        FeedEntryRef(
          diaryId: 'a',
          sourceUrl: 'https://a.com',
          title: '同标题',
          time: DateTime(2026, 9, 1),
        ),
        FeedEntryRef(
          diaryId: 'b',
          sourceUrl: 'https://b.com',
          title: '同标题',
          time: DateTime(2026, 9, 2),
        ),
      ];
      expect(FeedMaintenance.plan(entries).recycleDiaryIds, isEmpty);
    });

    test('标题不同但正文相同（同文重发）也判重', () {
      final entries = [
        FeedEntryRef(
          diaryId: 'a',
          sourceUrl: 'https://feed.example.com',
          title: '周刊（第 408 期）',
          content: '正文内容相同的一段很长的话…' * 3,
          time: DateTime(2026, 8, 28),
        ),
        FeedEntryRef(
          diaryId: 'b',
          sourceUrl: 'https://feed.example.com',
          title: '周刊 408：副标题不同',
          content: '正文内容相同的一段很长的话…' * 3,
          time: DateTime(2026, 9, 4),
        ),
      ];
      final plan = FeedMaintenance.plan(entries);
      expect(plan.recycleDiaryIds, ['a']);
      expect(plan.duplicateGroups, 1);
    });

    test('正文含不同标题/来源行时，仍按正文指纹判重', () {
      String body(String title) =>
          '# $title\n> 来源：阮一峰\n\n正文第一段内容\n\n🔗 https://feed.example.com/a';
      final entries = [
        FeedEntryRef(
          diaryId: 'a',
          sourceUrl: 'https://feed.example.com',
          title: '标题 A',
          content: body('标题 A'),
          time: DateTime(2026, 8, 28),
        ),
        FeedEntryRef(
          diaryId: 'b',
          sourceUrl: 'https://feed.example.com',
          title: '标题 B',
          content: body('标题 B'),
          time: DateTime(2026, 9, 4),
        ),
      ];
      final plan = FeedMaintenance.plan(entries);
      expect(plan.recycleDiaryIds, ['a']);
      expect(plan.duplicateGroups, 1);
    });
  });

  group('FeedMaintenance.normalizeTags', () {
    test('URL 标签换主机名并去重', () {
      final tags = FeedMaintenance.normalizeTags([
        '订阅',
        'https://www.ruanyifeng.com/blog/atom.xml',
        'www.ruanyifeng.com',
        '',
      ]);
      expect(tags, ['订阅', 'www.ruanyifeng.com']);
    });

    test('plan 收集标签变更', () {
      final entries = [
        FeedEntryRef(
          diaryId: 'a',
          sourceUrl: 'https://a.com',
          title: 't',
          time: DateTime(2026, 9, 1),
          tags: ['订阅', 'https://a.com/feed.xml'],
        ),
      ];
      final plan = FeedMaintenance.plan(entries);
      expect(plan.tagUpdates['a'], ['订阅', 'a.com']);
    });
  });
}
