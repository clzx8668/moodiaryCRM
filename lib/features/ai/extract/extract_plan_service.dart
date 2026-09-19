import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_block_writer.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_meta.dart';
import 'package:flutter/foundation.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
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

  /// 对日记主文本块执行：抽取 → **只生成「待确认」清单，不写日程表** →
  /// 在 AI 生成区落一张待确认卡片。
  ///
  /// 落库原则（用户要求）：AI 只负责提取，**必须由用户在预填创建页确认**后
  /// 才写入日程/CRM 表，保证数据严谨、与详情页展示一致。
  static Future<ExtractPlanResult?> processDiary(String diaryId) async {
    final block = await _primaryTextBlock(diaryId);
    if (block == null) return null;
    final config = ExtractPlanConfig.load();
    try {
      final result = await extract(sourceTextOf(block), config: config);
      if (result == null) {
        _writeMeta(block, 'failed', 'AI 未返回可用结果（可能未配置或格式不符）');
        return null;
      }

      // 去重：同标题的待办/日程合并（模型可能把同一件事同时放进 actions 与 events）
      final deduped = dedupe(result);
      final plan = deduped.result;

      // 待确认清单（不落库）
      final pending = <ExtractPendingItem>[
        if (config.todo)
          for (final a in plan.actions)
            ExtractPendingItem(
              kind: 'todo',
              title: a.title,
              start: a.dueAt,
              floating: a.dueAt == null || a.dueAt!.trim().isEmpty,
              priority: a.priority,
              notes: a.note ?? '',
            ),
        if (config.schedule)
          for (final e in plan.events)
            ExtractPendingItem(
              kind: 'schedule',
              title: e.title,
              start: e.start,
              end: e.end,
              allDay: e.allDay,
              priority: deduped.eventActions[normalizeTitle(e.title)]?.priority ?? '',
              notes: deduped.eventActions[normalizeTitle(e.title)]?.note ?? '',
              remind: e.remind ?? '',
            ),
      ];

      final crmProposals = config.crm ? plan.crm : const <ExtractCrm>[];
      if (pending.isNotEmpty || crmProposals.isNotEmpty) {
        // 在 AI 生成区新建「AI 提取」块（source=ai，aiTemplate='extract'），源笔记块保持原样
        final aiBlock = await _createExtractBlock(
          diaryId: diaryId,
          originalContent: block.content,
          pending: pending,
          crm: crmProposals,
          summary: config.summary ? plan.summary : '',
        );
        if (aiBlock == null) {
          _writeMeta(block, 'failed', '无法创建 AI 提取块');
          return null;
        }
      }
      return plan;
    } catch (e) {
      _writeMeta(block, 'failed', '抽取异常：$e');
      rethrow;
    }
  }

  /// 抽取使用的源文本：优先「去口语化」保留的原文。
  ///
  /// de_colloquial 与 extract_plan 是同一个队列里的两条独立任务，先后顺序不定；
  /// 固定读原文可以保证抽取结果与顺序无关（清洗稿只影响正文展示）。
  @visibleForTesting
  static String sourceTextOf(Block block) {
    final original = DeColoquialMeta.read(block)?.original.trim() ?? '';
    return original.isNotEmpty ? original : block.content;
  }

  /// 标题归一化（去空白 + 小写），用于判重。
  static String normalizeTitle(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// 纯函数去重：
  /// - 待办 / 日程各自按标题去重（保留首个）；
  /// - 待办与日程同标题时保留日程（时间更具体），并通过 [eventActions] 返回被合并的待办，
  ///   供落库时继承其优先级与备注。
  @visibleForTesting
  static ({ExtractPlanResult result, Map<String, ExtractAction> eventActions})
  dedupe(ExtractPlanResult raw) {
    final actions = <ExtractAction>[];
    final actionSeen = <String>{};
    for (final a in raw.actions) {
      final key = normalizeTitle(a.title);
      if (key.isEmpty || !actionSeen.add(key)) continue;
      actions.add(a);
    }

    final events = <ExtractEvent>[];
    final eventSeen = <String>{};
    for (final e in raw.events) {
      final key = normalizeTitle(e.title);
      if (key.isEmpty || !eventSeen.add(key)) continue;
      events.add(e);
    }

    final eventKeys = events.map((e) => normalizeTitle(e.title)).toSet();
    final eventActions = <String, ExtractAction>{};
    final keptActions = <ExtractAction>[];
    for (final a in actions) {
      final key = normalizeTitle(a.title);
      if (eventKeys.contains(key)) {
        eventActions[key] = a;
      } else {
        keptActions.add(a);
      }
    }

    return (
      result: ExtractPlanResult(
        actions: keptActions,
        events: events,
        crm: raw.crm,
        summary: raw.summary,
      ),
      eventActions: eventActions,
    );
  }

  /// 用户确认创建一条待办/日程后回写 AI 提取块：记录已创建的日程 id，
  /// 全部确认完则把状态置为 ok（详情页据此展示「已创建」列表与双向关联）。
  static Future<void> recordCreatedSchedule({
    required String diaryId,
    required String scheduleId,
  }) async {
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final block = blocks
        .where((b) => !b.isDeleted && b.meta.aiTemplate == 'extract')
        .lastOrNull;
    if (block == null) return;
    final meta = AiExtractMeta.read(block);
    if (meta == null) return;
    final ids = {...meta.scheduleIds, scheduleId}.toList();
    final allDone = ids.length >= meta.pendingItems.length;
    AiExtractMeta.write(
      block,
      AiExtractMeta(
        summary: meta.summary,
        scheduleIds: ids,
        crmProposals: meta.crmProposals,
        pendingItems: meta.pendingItems,
        status: allDone ? 'ok' : 'pending',
      ),
    );
    await IsarUtil.updateBlock(block);
  }

  /// 把「待确认」条目转成**预填**的日程/待办对象（供用户确认后落库）。
  ///
  /// [id] 由调用方预先生成：预填页保存时按该 id 写入，调用方即可直接建立
  /// 「日记 ↔ 待办」双向关联。
  static Schedule scheduleFromPending(
    ExtractPendingItem item, {
    required String id,
    required String diaryId,
    String blockId = '',
  }) {
    final start = _date(item.start);
    final today = DateTime.now();
    final schedule = Schedule()
      ..id = id
      ..title = item.title
      ..notes = item.notes
      ..linkedDiaryId = diaryId
      ..linkedBlockId = blockId.isEmpty ? null : blockId;
    if (item.isTodo) {
      schedule
        ..startTime = start ?? DateTime(today.year, today.month, today.day)
        ..floating = item.floating || start == null
        ..priority = _priority(item.priority);
    } else {
      schedule
        ..startTime = start ?? today
        ..endTime = _date(item.end)
        ..allDay = item.allDay
        ..priority = _priority(item.priority);
    }
    // 提醒：日程沿用原始文本（如「提前 15 分钟」→ 15）
    final remind = _remind(item.remind);
    if (remind != null) schedule.remindOffsetMin = remind;
    return schedule;
  }

  static Future<Block?> _createExtractBlock({
    required String diaryId,
    required String originalContent,
    required List<ExtractPendingItem> pending,
    required List<ExtractCrm> crm,
    required String summary,
  }) async {
    final content = StringBuffer('**AI 提取**\n\n');
    if (pending.isNotEmpty) {
      content.writeln('待确认 ${pending.length} 条（在下方确认后才会写入待办/日程）：');
      for (final p in pending) {
        final mark = p.isTodo ? '📌' : '🗓';
        final when = (p.start ?? '').trim();
        content.writeln(
          '- $mark ${p.title}${when.isEmpty ? '' : '（$when）'}',
        );
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

    // 同一笔记反复「提取待办」只保留最新一份提取卡（旧卡软删），避免 AI 区重复
    final aiBlock = await AiBlockWriter.upsert(
      diaryId: diaryId,
      template: 'extract',
      content: content.toString().trim(),
      sourceContent: originalContent,
    );
    AiExtractMeta.write(
      aiBlock,
      AiExtractMeta(
        summary: summary,
        crmProposals: crm,
        pendingItems: pending,
        status: 'pending',
      ),
    );
    await IsarUtil.updateBlock(aiBlock);
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
