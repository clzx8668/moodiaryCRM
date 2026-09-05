import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/skills/works_service.dart';

void main() {
  group('WorksPrompts', () {
    test('包含素材与格式', () {
      final p = WorksPrompts.build(
        sourceTexts: ['素材一', '素材二'],
        format: WorksFormat.xiaohongshu,
        topic: '高效阅读',
      );
      expect(p, contains('素材一'));
      expect(p, contains('素材二'));
      expect(p, contains('小红书笔记'));
      expect(p, contains('高效阅读'));
      expect(p, contains('成品正文'));
    });
    test('无素材时以主题兜底', () {
      final p = WorksPrompts.build(
        sourceTexts: const [],
        format: WorksFormat.report,
      );
      expect(p, contains('无素材'));
      expect(p, contains('工作汇报'));
    });
  });
}
