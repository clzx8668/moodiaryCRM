import 'dart:convert';

import 'package:moodiary/features/ai/extract/extract_plan_types.dart';
import 'package:moodiary/features/block/models/block.dart';

/// 「AI 抽取」结果在 `Block.metaJson.aiExtract` 上的读写视图。
///
/// 记录已生成的日程 id 列表 + 待确认的 CRM 提案，供详情页审核（CRM 不自动写库）。
class AiExtractMeta {
  static const String key = 'aiExtract';

  final String summary;
  final List<String> scheduleIds;
  final List<ExtractCrm> crmProposals;
  final String status;
  final String message;

  const AiExtractMeta({
    this.summary = '',
    this.scheduleIds = const [],
    this.crmProposals = const [],
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
