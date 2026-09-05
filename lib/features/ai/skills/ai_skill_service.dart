import 'dart:convert';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/skills/ai_skill.dart';

/// AI 技能结果（技能执行的可回看文本）。
class AiSkillResult {
  final AiSkillType type;
  final String text;

  const AiSkillResult({required this.type, required this.text});
}

/// AI 技能执行器：跑一次技能并返回结果文本。
class AiSkillService {
  AiSkillService._();

  /// 运行技能；失败返回 null（UI 提示重试，不静默失败）。
  static Future<AiSkillResult?> run(AiSkillType type, String content) async {
    final t = content.trim();
    if (t.isEmpty) return null;

    final provider = await AiProviderFactory.loadLight();
    if (!provider.isConfigured) return null;

    final completion = await provider.completeChat([
      const AiChatMessage(role: 'system', content: AiSkillPrompts.system),
      AiChatMessage(role: 'user', content: AiSkillPrompts.build(type, t)),
    ]);
    final text = _extractText(completion.content, type);
    if (text.trim().isEmpty) return null;
    return AiSkillResult(type: type, text: text.trim());
  }

  static String _extractText(String raw, AiSkillType type) {
    if (raw.trim().isEmpty) return '';
    var s = raw.trim();
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) {
        final text = decoded['text']?.toString() ?? '';
        if (text.trim().isNotEmpty) return text.trim();
        if (type == AiSkillType.sprout) {
          final items = (decoded['items'] as List?)?.map((e) => e.toString());
          if (items != null) {
            return items.map((e) => '· $e').join('\n');
          }
        }
        if (type == AiSkillType.interrogate) {
          final qs = (decoded['questions'] as List?)?.map((e) => e.toString());
          if (qs != null) {
            return qs.map((e) => 'Q: $e').join('\n');
          }
        }
      }
    } catch (_) {
      // 容错：非 JSON 时按纯文本返回
    }
    return s;
  }
}
