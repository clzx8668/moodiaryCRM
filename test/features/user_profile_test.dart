import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/profile/user_profile.dart';
import 'package:moodiary/features/ai/skills/ai_skill.dart';
import 'package:moodiary/features/ai/skills/works_service.dart';

void main() {
  group('UserProfile', () {
    test('空画像 promptSection 为空', () {
      expect(const UserProfile().isEmpty, isTrue);
      expect(const UserProfile().toPromptSection(), '');
    });

    test('encode/decode 往返一致', () {
      const p = UserProfile(
        vocabulary: ['膜池', 'MBR'],
        phrases: ['落地方案'],
        preference: '简洁、先结论',
      );
      final decoded = UserProfile.decode(p.encode());
      expect(decoded.vocabulary, ['膜池', 'MBR']);
      expect(decoded.phrases, ['落地方案']);
      expect(decoded.preference, '简洁、先结论');
    });

    test('坏数据回退空画像', () {
      expect(UserProfile.decode('{bad json').isEmpty, isTrue);
      expect(UserProfile.decode('').isEmpty, isTrue);
    });

    test('promptSection 含词库/表达/偏好', () {
      const p = UserProfile(
        vocabulary: ['膜池'],
        phrases: ['闭环'],
        preference: '先结论',
      );
      final s = p.toPromptSection();
      expect(s, contains('膜池'));
      expect(s, contains('闭环'));
      expect(s, contains('先结论'));
    });

    test('画像注入技能与作品 Prompt', () {
      final profile = const UserProfile(vocabulary: ['膜池']).toPromptSection();
      final skill = AiSkillPrompts.build(
        AiSkillType.sprout,
        '内容',
        profileSection: profile,
      );
      expect(skill, contains('膜池'));
      final works = WorksPrompts.build(
        sourceTexts: const ['素材'],
        format: WorksFormat.report,
        profileSection: profile,
      );
      expect(works, contains('膜池'));
    });
  });
}
