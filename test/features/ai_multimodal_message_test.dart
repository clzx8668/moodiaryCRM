import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/ai_provider.dart';

void main() {
  group('AiChatMessage 多模态', () {
    test('无图片时 content 为字符串', () {
      const msg = AiChatMessage(role: 'user', content: '你好');
      final json = msg.toJson();
      expect(json['content'], '你好');
      expect(msg.hasImages, isFalse);
    });

    test('有图片时 content 为 parts 数组（text + image_url）', () {
      const msg = AiChatMessage(
        role: 'user',
        content: '识别这张图',
        images: ['data:image/png;base64,AAA'],
      );
      final json = msg.toJson();
      expect(msg.hasImages, isTrue);
      final parts = json['content'] as List;
      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[0]['text'], '识别这张图');
      expect(parts[1]['type'], 'image_url');
      expect(parts[1]['image_url']['url'], 'data:image/png;base64,AAA');
    });

    test('空文本 + 图片时只输出图片 part', () {
      const msg = AiChatMessage(
        role: 'user',
        content: '',
        images: ['data:image/jpeg;base64,BBB'],
      );
      final parts = msg.toJson()['content'] as List;
      expect(parts.length, 1);
      expect(parts[0]['type'], 'image_url');
    });
  });
}
