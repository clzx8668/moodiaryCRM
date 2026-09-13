import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/feed/feed_models.dart';
import 'package:moodiary/features/feed/feed_parser.dart';

const _rss = '''
<rss version="2.0"><channel><title>示例源</title>
<item>
  <title><![CDATA[标题 &amp; 一]]></title>
  <link>https://example.com/a</link>
  <description><![CDATA[<p>摘要 <b>A</b></p>]]></description>
  <content:encoded><![CDATA[<p>正文 A</p>]]></content:encoded>
  <pubDate>Mon, 02 Sep 2026 10:00:00 GMT</pubDate>
  <guid isPermaLink="false">guid-a</guid>
</item>
<item>
  <title>标题二 &#x27;quoted&#x27;</title>
  <link>https://example.com/b</link>
  <description>摘要 B</description>
</item>
</channel></rss>
''';

const _atom = '''
<feed xmlns="http://www.w3.org/2005/Atom">
 <title>Atom 源</title>
 <entry>
   <title>Atom 条目</title>
   <link rel="alternate" href="https://example.com/atom-1"/>
   <summary>摘要 Atom</summary>
   <content type="html">&lt;p&gt;正文 Atom&lt;/p&gt;</content>
   <published>2026-09-02T10:00:00Z</published>
   <id>tag:example.com,2026:1</id>
   <author><name>作者A</name></author>
 </entry>
</feed>
''';

void main() {
  group('FeedParser RSS', () {
    test('解析字段、CDATA、实体与日期', () {
      final items = FeedParser.parse(_rss);
      expect(items.length, 2);
      final a = items.first;
      expect(a.title, '标题 & 一');
      expect(a.link, 'https://example.com/a');
      expect(a.summary, '摘要 A');
      expect(a.contentHtml, contains('正文 A'));
      expect(a.guid, 'guid-a');
      expect(a.publishedAt, DateTime.utc(2026, 9, 2, 10));

      final b = items[1];
      expect(b.title, "标题二 'quoted'");
      expect(b.guid, 'https://example.com/b');
      expect(b.publishedAt, isNull);
    });
  });

  group('FeedParser Atom', () {
    test('解析 href/id/name/ISO 时间', () {
      final items = FeedParser.parse(_atom);
      expect(items.length, 1);
      final e = items.first;
      expect(e.title, 'Atom 条目');
      expect(e.link, 'https://example.com/atom-1');
      expect(e.summary, '摘要 Atom');
      expect(e.contentHtml, contains('正文 Atom'));
      expect(e.author, '作者A');
      expect(e.guid, 'tag:example.com,2026:1');
      expect(e.publishedAt, DateTime.utc(2026, 9, 2, 10));
    });
  });

  group('FeedParser 去重与增量', () {
    test('itemKey 优先 guid 且稳定', () {
      const i1 = FeedItem(title: 't', link: 'https://a', guid: 'g1');
      const i2 = FeedItem(title: 't', link: 'https://a', guid: 'g1');
      const i3 = FeedItem(title: 't', link: 'https://a', guid: 'g2');
      expect(FeedParser.itemKey(i1), FeedParser.itemKey(i2));
      expect(FeedParser.itemKey(i1), isNot(FeedParser.itemKey(i3)));
      expect(FeedParser.stableHash('abc'), FeedParser.stableHash('abc'));
    });

    test('newItems 过滤已入库', () {
      final items = FeedParser.parse(_rss);
      final seen = <String>{FeedParser.itemKey(items.first)};
      final fresh = FeedParser.newItems(items: items, seenKeys: seen);
      expect(fresh.length, 1);
      expect(fresh.first.link, 'https://example.com/b');
    });
  });

  group('FeedParser 其它', () {
    test('maxItems 截断', () {
      expect(FeedParser.parse(_rss, maxItems: 1).length, 1);
    });

    test('parseDate 支持多种格式与非法输入', () {
      expect(FeedParser.parseDate('Mon, 02 Sep 2026 10:00:00 GMT'),
          DateTime.utc(2026, 9, 2, 10));
      expect(FeedParser.parseDate('2026-09-02T10:00:00Z'),
          DateTime.utc(2026, 9, 2, 10));
      expect(
        FeedParser.parseDate('Mon, 02 Sep 2026 18:00:00 +0800'),
        DateTime.utc(2026, 9, 2, 10),
      );
      expect(FeedParser.parseDate('not a date'), isNull);
      expect(FeedParser.parseDate(''), isNull);
    });

    test('空 XML / 无条目返回空列表', () {
      expect(FeedParser.parse(''), isEmpty);
      expect(FeedParser.parse('<rss><channel></channel></rss>'), isEmpty);
    });
  });
}
