import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/link_capture/link_html.dart';

void main() {
  group('LinkHtml', () {
    test('stripTags 删除 script/style 与标签', () {
      const html =
          '<html><head><style>.a{}</style><script>var x=1;</script></head>'
          '<body><p>你好</p><div>世界</div></body></html>';
      expect(LinkHtml.stripTags(html).contains('var x'), isFalse);
      expect(LinkHtml.stripTags(html).contains('你好'), isTrue);
      expect(LinkHtml.stripTags(html).contains('世界'), isTrue);
    });

    test('extractReadableText 折叠空白并截断', () {
      final text = LinkHtml.extractReadableText('<p>  A \n\n B  </p>');
      expect(text, 'A B');
      final long = LinkHtml.extractReadableText('<p>${'x' * 100}</p>', maxLen: 10);
      expect(long.length, 11); // 10 + 省略号
      expect(long.endsWith('…'), isTrue);
    });

    test('extractTitle 优先 title 标签，回退 og:title', () {
      expect(LinkHtml.extractTitle('<title> 文章标题 </title>'), '文章标题');
      expect(
        LinkHtml.extractTitle(
          '<meta property="og:title" content="OG标题" />',
        ),
        'OG标题',
      );
    });

    test('unescape 处理常见实体', () {
      expect(LinkHtml.unescape('A &amp; B &lt; C &#39;'), 'A & B < C \'');
    });

    test('innerTextById 提取指定元素内容', () {
      const html =
          '<div id="js_content"><p>第一段</p><p>第二段</p></div><div>其他</div>';
      final r = LinkHtml.innerTextById(html, 'js_content');
      expect(r, contains('第一段'));
      expect(r, contains('第二段'));
      expect(r, isNot(contains('其他')));
    });

    test('extractImages 去重并跳过 data URI', () {
      final html =
          '<img src="https://a/x.png"><img data-src="https://b/y.png">'
          '<img src="data:image/png;base64,abc"><img data-src="https://a/x.png">';
      final imgs = LinkHtml.extractImages(html);
      expect(imgs, contains('https://a/x.png'));
      expect(imgs, contains('https://b/y.png'));
      expect(imgs.length, 2);
    });
  });
}
