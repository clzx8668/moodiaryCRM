import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/link_capture/link_platform.dart';

void main() {
  group('LinkRecognizer', () {
    test('公众号', () {
      expect(
        LinkRecognizer.recognize('https://mp.weixin.qq.com/s/abc123'),
        LinkPlatform.wechat,
      );
    });
    test('B站（含短链 b23.tv）', () {
      expect(
        LinkRecognizer.recognize('https://www.bilibili.com/video/BV1xx411c7mD'),
        LinkPlatform.bilibili,
      );
      expect(
        LinkRecognizer.recognize('https://b23.tv/abcdef'),
        LinkPlatform.bilibili,
      );
    });
    test('抖音短链', () {
      expect(
        LinkRecognizer.recognize('https://v.douyin.com/xxxx/'),
        LinkPlatform.douyin,
      );
    });
    test('通用网页', () {
      expect(
        LinkRecognizer.recognize('https://blog.example.com/post/1'),
        LinkPlatform.generalWeb,
      );
    });
    test('无法识别', () {
      expect(LinkRecognizer.recognize('not a url'), LinkPlatform.unknown);
    });
  });
}
