import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/feed/feed_models.dart';
import 'package:moodiary/features/feed/feed_saver.dart';
import 'package:moodiary/features/feed/feed_service.dart';

void main() {
  group('FeedSource 模型', () {
    test('JSON 往返一致', () {
      final s = FeedSource(
        id: 'id1',
        url: 'https://example.com/feed.xml',
        title: '示例源',
        enabled: false,
        lastFetchedAt: 123,
        lastItemKeys: ['k1', 'k2'],
      );
      final decoded = FeedSource.fromJson(s.toJson());
      expect(decoded.id, 'id1');
      expect(decoded.url, 'https://example.com/feed.xml');
      expect(decoded.title, '示例源');
      expect(decoded.enabled, isFalse);
      expect(decoded.lastFetchedAt, 123);
      expect(decoded.lastItemKeys, ['k1', 'k2']);
    });

    test('displayTitle 空标题回退 url', () {
      expect(
        FeedSource(id: 'x', url: 'https://a.com').displayTitle,
        'https://a.com',
      );
    });

    test('displayName 优先标题，其次主机名', () {
      expect(
        FeedSource(id: 'x', url: 'https://a.com/feed.xml', title: '示例源')
            .displayName,
        '示例源',
      );
      expect(
        FeedSource(id: 'x', url: 'https://a.com/feed.xml').displayName,
        'a.com',
      );
    });
  });

  group('FeedService 纯函数', () {
    test('needsBody：摘要短且有链接才补正文', () {
      expect(
        FeedService.needsBody(
          const FeedItem(title: 't', link: 'https://a', summary: '短'),
        ),
        isTrue,
      );
      expect(
        FeedService.needsBody(
          FeedItem(title: 't', link: 'https://a', summary: '长' * 300),
        ),
        isFalse,
      );
      expect(
        FeedService.needsBody(
          const FeedItem(title: 't', link: '', summary: '短'),
        ),
        isFalse,
      );
    });

    test('updatedKeys：新键在前、去重、按上限截断', () {
      expect(
        FeedService.updatedKeys(['a', 'b'], ['c', 'a'], cap: 3),
        ['c', 'a', 'b'],
      );
      expect(
        FeedService.updatedKeys(['a', 'b', 'c'], ['d'], cap: 2),
        ['d', 'a'],
      );
      expect(FeedService.updatedKeys(const [], const []), isEmpty);
    });
  });

  group('FeedSaver.buildContent', () {
    test('包含标题/来源/正文/链接', () {
      final source = FeedSource(
        id: 's1',
        url: 'https://feed.example.com',
        title: '示例源',
      );
      final item = FeedItem(
        title: '条目标题',
        link: 'https://example.com/post/1',
        author: '作者A',
        publishedAt: DateTime.utc(2026, 9, 2, 10),
      );
      final md = FeedSaver.buildContent(source, item, '正文内容');
      expect(md, contains('# 条目标题'));
      expect(md, contains('来源：作者A'));
      expect(md, contains('2026-09-02'));
      expect(md, contains('示例源'));
      expect(md, contains('正文内容'));
      expect(md, contains('https://example.com/post/1'));
    });
  });
}
