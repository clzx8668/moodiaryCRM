import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/skills/ai_skill.dart';

void main() {
  group('AiSkillPrompts', () {
    test('包含记录内容与技能指令', () {
      final p = AiSkillPrompts.build(AiSkillType.sprout, '关于时间管理的想法');
      expect(p, contains('关于时间管理的想法'));
      expect(p, contains('延伸出 3-5 个新认知'));
      expect(p, contains('返回 JSON'));
    });
    test('各技能指令不同', () {
      final c = AiSkillPrompts.build(AiSkillType.comment, 'x');
      final i = AiSkillPrompts.build(AiSkillType.interrogate, 'x');
      expect(c, contains('亮点'));
      expect(i, contains('尖锐追问'));
      expect(c, isNot(contains('尖锐追问')));
    });
    test('技能元数据', () {
      expect(AiSkillType.polish.label, '打磨成稿');
      expect(AiSkillType.comment.icon, '💬');
    });
  });
}
