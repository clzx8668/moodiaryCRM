import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/vision/vision_capture_service.dart';

void main() {
  group('VisionCaptureService', () {
    test('parseResult 解析 JSON（含代码围栏）', () {
      final r = VisionCaptureService.parseResult(
        '```json\n{"title":"读书笔记","markdown":"# 要点\\n- A"}\n```',
      );
      expect(r, isNotNull);
      expect(r!.title, '读书笔记');
      expect(r.markdown, contains('要点'));
    });

    test('parseResult 非 JSON 时按纯文本兜底', () {
      final r = VisionCaptureService.parseResult('纯文本识别结果');
      expect(r, isNotNull);
      expect(r!.title, '');
      expect(r.markdown, '纯文本识别结果');
    });

    test('parseResult 空字符串返回 null', () {
      expect(VisionCaptureService.parseResult('   '), isNull);
    });

    test('mimeFor 常见扩展名', () {
      expect(VisionCaptureService.mimeFor('a.png'), 'image/png');
      expect(VisionCaptureService.mimeFor('a.webp'), 'image/webp');
      expect(VisionCaptureService.mimeFor('a.jpg'), 'image/jpeg');
      expect(VisionCaptureService.mimeFor('a.unknown'), 'image/jpeg');
    });
  });
}
