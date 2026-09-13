import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/share/share_receiver.dart';

void main() {
  group('ShareReceiver.extractUrl', () {
    test('纯链接原样返回', () {
      expect(
        ShareReceiver.extractUrl('https://example.com/a'),
        'https://example.com/a',
      );
    });

    test('从分享文案中提取链接', () {
      expect(
        ShareReceiver.extractUrl('分享给你 https://b23.tv/abc 很好看'),
        'https://b23.tv/abc',
      );
    });

    test('去掉结尾标点', () {
      expect(
        ShareReceiver.extractUrl('看这个 https://a.com/x，。'),
        'https://a.com/x',
      );
      expect(
        ShareReceiver.extractUrl('(https://a.com/y)'),
        'https://a.com/y',
      );
    });

    test('无链接返回 null', () {
      expect(ShareReceiver.extractUrl('今天心情不错'), isNull);
      expect(ShareReceiver.extractUrl(''), isNull);
    });
  });
}
