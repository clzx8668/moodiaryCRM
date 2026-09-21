import 'package:moodiary/features/ai/ai_block_writer.dart';
import 'package:moodiary/features/ai/memory/prompt_context.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/isar.dart';

/// 快速收集「模板」的 AI 处理：把日记主文本按模板（扩写/润色/会议/翻译/打卡）处理后，
/// 在 AI 生成区新建 `source=ai, aiTemplate=<模板>` 的文本块（原文保留）。
class TemplateProcessService {
  TemplateProcessService._();

  static Future<bool> processDiary(String diaryId, String templateId) async {
    if (templateId.trim().isEmpty) return false;
    final block = await _primaryTextBlock(diaryId);
    if (block == null || block.content.trim().isEmpty) return false;

    final provider = await AiProviderFactory.load();
    if (!provider.isConfigured) return false;

    // 全局分层记忆：模板处理（翻译/摘要/待办/去口语化…）也要遵守用户的
    // 词库与风格偏好——否则同一个人的两种场景会得到不一致的措辞。
    // 统一走 PromptContext，保证与对话入口用的是同一份记忆。
    final system = PromptContext.build(
      persona: '你是笔记整理助手，用中文输出。',
      memorySection: await PromptContext.loadMemorySection(
        query: block.content,
      ),
    );
    final completion = await provider.completeChat([
      AiChatMessage(role: 'system', content: system),
      AiChatMessage(
        role: 'user',
        content: AiTemplates.build(templateId, block.content),
      ),
    ]);
    final text = completion.content.trim();
    if (text.isEmpty) return false;

    // 同一模板重复运行只保留最新一份（避免 AI 区堆重复卡）
    await AiBlockWriter.upsert(
      diaryId: diaryId,
      template: templateId,
      content: text,
      title: AiTemplates.label(templateId),
      sourceContent: block.content,
    );
    return true;
  }

  static Future<Block?> _primaryTextBlock(String diaryId) async {
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final texts = blocks
        .where((b) => b.blockType == BlockType.text && !b.isDeleted)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return texts.isEmpty ? null : texts.first;
  }
}
