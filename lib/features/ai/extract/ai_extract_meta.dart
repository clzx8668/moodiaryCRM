import 'dart:convert';

import 'package:moodiary/features/ai/extract/extract_plan_types.dart';
import 'package:moodiary/features/block/models/block.dart';

/// AI 提取出的「待确认」条目（待办/日程草稿）：**未落库**，
/// 等用户在预填创建页里确认后才写入日程表。
class ExtractPendingItem {
  const ExtractPendingItem({
    required this.kind,
    required this.title,
    this.start,
    this.end,
    this.allDay = false,
    this.priority = '',
    this.notes = '',
    this.floating = false,
    this.remind = '',
  });

  /// 'todo' | 'schedule'
  final String kind;
  final String title;
  final String? start;
  final String? end;
  final bool allDay;
  final String priority;
  final String notes;

  /// 无明确时间的待办（浮动）
  final bool floating;

  /// 原始提醒文本（如「提前 15 分钟」），仅日程使用
  final String remind;

  bool get isTodo => kind == 'todo';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'title': title,
    'start': start,
    'end': end,
    'allDay': allDay,
    'priority': priority,
    'notes': notes,
    'floating': floating,
    'remind': remind,
  };

  static ExtractPendingItem fromJson(Map<String, dynamic> json) =>
      ExtractPendingItem(
        kind: json['kind']?.toString() ?? 'todo',
        title: json['title']?.toString() ?? '',
        start: json['start']?.toString(),
        end: json['end']?.toString(),
        allDay: json['allDay'] == true,
        priority: json['priority']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        floating: json['floating'] == true,
        remind: json['remind']?.toString() ?? '',
      );
}

/// 「AI 抽取」结果在 `Block.metaJson.aiExtract` 上的读写视图。
///
/// 记录已生成的日程 id 列表 + 待确认的 CRM 提案，供详情页审核（CRM 不自动写库）。
class AiExtractMeta {
  static const String key = 'aiExtract';

  final String summary;
  final List<String> scheduleIds;
  final List<ExtractCrm> crmProposals;
  /// 待确认条目（未落库；用户在预填创建页确认后才会写日程表）
  final List<ExtractPendingItem> pendingItems;
  final String status;
  final String message;

  const AiExtractMeta({
    this.summary = '',
    this.scheduleIds = const [],
    this.crmProposals = const [],
    this.pendingItems = const [],
    this.status = 'ok',
    this.message = '',
  });

  static AiExtractMeta? read(Block block) {
    final map = _mapOf(block);
    final raw = map[key];
    if (raw is! Map) return null;
    final crm = raw['crmProposals'];
    return AiExtractMeta(
      summary: raw['summary']?.toString() ?? '',
      scheduleIds: [
        for (final s in (raw['scheduleIds'] as List? ?? [])) s.toString(),
      ],
      crmProposals: [
        for (final c in (crm as List? ?? []))
          if (c is Map) ExtractCrm.fromJson(c.map((k, v) => MapEntry(k.toString(), v))),
      ],
      pendingItems: [
        for (final p in (raw['pendingItems'] as List? ?? []))
          if (p is Map)
            ExtractPendingItem.fromJson(p.map((k, v) => MapEntry(k.toString(), v))),
      ],
      status: raw['status']?.toString() ?? 'ok',
      message: raw['message']?.toString() ?? '',
    );
  }

  static bool has(Block block) => read(block) != null;

  static void write(Block block, AiExtractMeta meta) {
    final map = _mapOf(block);
    map[key] = {
      'summary': meta.summary,
      'scheduleIds': meta.scheduleIds,
      'crmProposals': [for (final c in meta.crmProposals) c.toJson()],
      'pendingItems': [for (final p in meta.pendingItems) p.toJson()],
      'status': meta.status,
      'message': meta.message,
    };
    block.metaJson = jsonEncode(map);
  }

  static Map<String, dynamic> _mapOf(Block block) {
    final raw = block.metaJson.trim();
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // 容错
    }
    return <String, dynamic>{};
  }
}
