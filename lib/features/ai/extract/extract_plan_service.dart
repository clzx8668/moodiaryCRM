import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/isar.dart';

import 'ai_extract_meta.dart';
import 'extract_plan_config.dart';
import 'extract_plan_types.dart';

/// extract_plan 结构化抽取（P1）。
///
/// 一次调用抽取待办 / CRM / 日程；待办与日程直接落库（可逆，本地），
/// CRM 生成"提案"（不写库），存入 `Block.metaJson.aiExtract`，由详情页审核确认。
class ExtractPlanService {
  static const String _system =
      '你是信息抽取助手。从一段口语/笔记里抽取行动项、日程和 CRM 相关信息，'
      '只抽取真实出现的信息，不得编造。只输出 JSON，不要输出其它内容。';

  static Future<ExtractPlanResult?> extract(
    String text, {
    ExtractPlanConfig? config,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return null;
    config ??= ExtractPlanConfig.load();
    final provider = await AiProviderFactory.load();
    if (!provider.isConfigured) return null;
    final completion = await provider.completeChat([
      const AiChatMessage(role: 'system', content: _system),
      AiChatMessage(role: 'user', content: _prompt(t, config)),
    ]);
    return ExtractPlanResult.tryParse(completion.content);
  }

  /// 对日记主文本块执行：抽取 → 日程入库 → 写 aiExtract meta。
  static Future<ExtractPlanResult?> processDiary(String diaryId) async {
    final block = await _primaryTextBlock(diaryId);
    if (block == null) return null;
    final config = ExtractPlanConfig.load();
    try {
      final result = await extract(block.content, config: config);
      if (result == null) {
        _writeMeta(block, 'failed', 'AI 未返回可用结果（可能未配置或格式不符）');
        return null;
      }

      final createdSchedules = <String>[];
      final createdTitles = <String>[];
      final scheduleRepo = ScheduleRepository();
      final today = DateTime.now();
      if (config.todo) {
        for (final a in result.actions) {
          final s = await scheduleRepo.create(
            Schedule()
              ..title = a.title
              ..startTime = _date(a.dueAt) ??
                  DateTime(today.year, today.month, today.day)
              ..floating = a.dueAt == null || a.dueAt!.trim().isEmpty
              ..priority = _priority(a.priority)
              ..notes = a.note ?? ''
              ..linkedDiaryId = diaryId
              ..linkedBlockId = block.id,
          );
          createdSchedules.add(s.id);
          createdTitles.add(a.title);
        }
      }
      if (config.schedule) {
        for (final e in result.events) {
          final start = _date(e.start);
          final s = await scheduleRepo.create(
            Schedule()
              ..title = e.title
              ..startTime = start ?? today
              ..endTime = e.end != null ? _date(e.end) : null
              ..allDay = e.allDay
              ..remindOffsetMin = _remind(e.remind)
              ..linkedDiaryId = diaryId
              ..linkedBlockId = block.id,
          );
          createdSchedules.add(s.id);
          createdTitles.add(e.title);
        }
      }

      final crmProposals = config.crm ? result.crm : const <ExtractCrm>[];
      if (createdSchedules.isNotEmpty || crmProposals.isNotEmpty) {
        // 在 AI 生成区新建「AI 提取」块（source=ai，aiTemplate='extract'），源笔记块保持原样
        final aiBlock = await _createExtractBlock(
          diaryId: diaryId,
          originalContent: block.content,
          titles: createdTitles,
          crm: crmProposals,
          summary: config.summary ? result.summary : '',
          scheduleIds: createdSchedules,
          crmProposalsMeta: crmProposals,
        );
        if (aiBlock == null) {
          _writeMeta(block, 'failed', '无法创建 AI 提取块');
          return null;
        }
      }
      return result;
    } catch (e) {
      _writeMeta(block, 'failed', '抽取异常：$e');
      rethrow;
    }
  }

  static Future<Block?> _createExtractBlock({
    required String diaryId,
    required String originalContent,
    required List<String> titles,
    required List<ExtractCrm> crm,
    required String summary,
    required List<String> scheduleIds,
    required List<ExtractCrm> crmProposalsMeta,
  }) async {
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final sortOrder = blocks.isEmpty
        ? 0
        : blocks.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final now = DateTime.now();
    final content = StringBuffer('**AI 提取**\n\n');
    if (titles.isNotEmpty) {
      content.writeln('生成 ${titles.length} 个待办/日程：');
      for (final t in titles) {
        content.writeln('- 📌 $t');
      }
    }
    if (crm.isNotEmpty) {
      content.writeln('CRM 建议 ${crm.length} 条：');
      for (final c in crm) {
        content.writeln('- 🏢 ${c.name}');
      }
    }
    if (summary.isNotEmpty) {
      content.writeln('\n摘要：$summary');
    }

    final aiBlock = Block()
      ..diaryId = diaryId
      ..blockType = BlockType.text
      ..content = content.toString().trim()
      ..sortOrder = sortOrder
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceAi,
        aiTemplate: 'extract',
        sourceContent: originalContent,
      );
    AiExtractMeta.write(
      aiBlock,
      AiExtractMeta(
        summary: summary,
        scheduleIds: scheduleIds,
        crmProposals: crmProposalsMeta,
        status: 'ok',
      ),
    );
    await IsarUtil.insertBlock(aiBlock);
    return aiBlock;
  }

  static Future<void> _writeMeta(
    Block block,
    String status,
    String message, {
    String summary = '',
    List<String> scheduleIds = const [],
    List<ExtractCrm> crmProposals = const [],
  }) async {
    AiExtractMeta.write(
      block,
      AiExtractMeta(
        summary: summary,
        scheduleIds: scheduleIds,
        crmProposals: crmProposals,
        status: status,
        message: message,
      ),
    );
    await IsarUtil.updateBlock(block);
  }

  static String _prompt(String text, ExtractPlanConfig config) {
    final parts = <String>[];
    if (config.todo) {
      parts.add('- actions：待办（标题 title、可选截止 dueAt、优先级 priority[低/中/高]、备注 note）；');
    }
    if (config.schedule) {
      parts.add('- events：日程（title、开始 start、可选结束 end、是否全天 allDay、提前提醒 remind[如"30分钟"/"明天"]）；');
    }
    if (config.crm) {
      parts.add('- crm：CRM 相关信息（type[account/contact/opportunity/contract]、name、以及 phone/email/industry/amount 等字段）；');
    }
    if (config.summary) {
      parts.add('- summary：一句话概括。');
    }
    final schema = <String>[];
    if (config.todo) schema.add('"actions":[{"title":"","dueAt":null,"priority":"","note":""}]');
    if (config.schedule) {
      schema.add('"events":[{"title":"","start":null,"end":null,"allDay":false,"remind":null}]');
    }
    if (config.crm) schema.add('"crm":[{"type":"","name":"","fields":{}}]');
    if (config.summary) schema.add('"summary":""');
    return '''
从下面的内容里抽取：
${parts.map((p) => '- $p').join('\n')}

内容：
"""$text"""

返回 JSON：
{${schema.join(',')}}
''';
  }

  static Future<Block?> _primaryTextBlock(String diaryId) async {
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final texts = blocks
        .where((b) => b.blockType == BlockType.text && !b.isDeleted)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return texts.isEmpty ? null : texts.first;
  }

  static SchedulePriority _priority(String? p) => switch ((p ?? '').trim()) {
    '高' => SchedulePriority.high,
    '中' => SchedulePriority.medium,
    '低' => SchedulePriority.low,
    _ => SchedulePriority.none,
  };

  static int? _remind(Object? remind) {
    if (remind == null) return null;
    final s = remind.toString().trim();
    if (s.isEmpty) return null;
    if (s == '准时') return 0;
    final m = RegExp(r'(\d+)\s*分').firstMatch(s);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  static DateTime? _date(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s == '今天') return DateTime.now();
    if (s == '明天') return DateTime.now().add(const Duration(days: 1));
    return DateTime.tryParse(s);
  }
}
