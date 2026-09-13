import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/link_capture/web_render_service.dart';

void main() {
  group('WebRenderService', () {
    test('shouldFallback：正文过短才兜底', () {
      expect(WebRenderService.shouldFallback(''), isTrue);
      expect(WebRenderService.shouldFallback('短文本'), isTrue);
      expect(
        WebRenderService.shouldFallback('长' * 300),
        isFalse,
      );
    });

    test('parseRenderResult：JSON 字符串', () {
      final r = WebRenderService.parseRenderResult(
        '{"title":"标题","text":"第一段\\n\\n第二段"}',
      );
      expect(r, isNotNull);
      expect(r!.title, '标题');
      expect(r.text, contains('第一段'));
      expect(r.text, contains('第二段'));
    });

    test('parseRenderResult：Map 输入', () {
      final r = WebRenderService.parseRenderResult({
        'title': 'T',
        'text': '正文内容',
      });
      expect(r?.title, 'T');
      expect(r?.text, '正文内容');
    });

    test('parseRenderResult：空/非法输入返回 null', () {
      expect(WebRenderService.parseRenderResult(null), isNull);
      expect(WebRenderService.parseRenderResult(''), isNull);
      expect(WebRenderService.parseRenderResult('not json'), isNull);
      expect(
        WebRenderService.parseRenderResult({'title': 'T', 'text': '  '}),
        isNull,
      );
    });
  });
}
