import 'package:moodiary/features/ai/ai_provider.dart';

/// 作品输出格式（对标得到大脑「小步」：记录变成可发布内容）。
enum WorksFormat {
  article('公众号文章', '结构完整约 2000 字，适合公众号'),
  xiaohongshu('小红书笔记', '短小精悍、带 emoji、钩子开头'),
  report('工作汇报', '结构化、突出成果与下一步'),
  email('邮件草稿', '正式、简洁、带称呼与落款');

  final String label;
  final String hint;

  const WorksFormat(this.label, this.hint);
}

/// 作品生成 Prompt 构建（纯函数，可单测）。
class WorksPrompts {
  WorksPrompts._();

  static const String system =
      '你是一个资深内容创作者，用中文输出可直接发布的成品文本。不要输出任何说明或代码块。';

  static String build({
    required List<String> sourceTexts,
    required WorksFormat format,
    String topic = '',
  }) {
    final sources = sourceTexts
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final srcBlock = sources.isEmpty
        ? '（无素材，请根据主题合理发挥）'
        : sources.map((s) => '---\n$s').join('\n');
    final topicLine = topic.trim().isEmpty ? '' : '\n主题方向：$topic';
    return '''
$system

请基于以下素材，输出一篇「${format.label}」：${format.hint}。
要求：
- 忠于素材事实，不编造；可适度补充过渡与衔接；
- 直接输出成品正文（标题用 # 号）。
$topicLine

素材：
$srcBlock
''';
  }
}

/// 作品生成服务：利用素材生成成品草稿。
class WorksService {
  WorksService._();

  static Future<String?> generate({
    required List<String> sourceTexts,
    required WorksFormat format,
    String topic = '',
  }) async {
    final provider = await AiProviderFactory.loadLight();
    if (!provider.isConfigured) return null;
    final completion = await provider.completeChat([
      const AiChatMessage(role: 'system', content: WorksPrompts.system),
      AiChatMessage(
        role: 'user',
        content: WorksPrompts.build(
          sourceTexts: sourceTexts,
          format: format,
          topic: topic,
        ),
      ),
    ]);
    final text = completion.content.trim();
    return text.isEmpty ? null : text;
  }
}
