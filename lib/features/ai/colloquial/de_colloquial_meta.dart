import 'dart:convert';

import 'package:moodiary/features/block/models/block.dart';

/// 「去口语化」结果在 `Block.metaJson` 上的读写视图。
///
/// 以独立 `deColoquial` 键存储（不动 BlockMeta 原有字段），原文始终保留在
/// `original`，清洗稿在 `cleaned`，UI 可切换/一键还原。
class DeColoquialMeta {
  static const String key = 'deColoquial';

  final String original;
  final String cleaned;
  final String reason;
  final int ts;
  final bool changed;

  const DeColoquialMeta({
    required this.original,
    required this.cleaned,
    this.reason = '',
    this.ts = 0,
    this.changed = true,
  });

  static DeColoquialMeta? read(Block block) {
    final map = _mapOf(block);
    final raw = map[key];
    if (raw is! Map) return null;
    return DeColoquialMeta(
      original: raw['original']?.toString() ?? '',
      cleaned: raw['cleaned']?.toString() ?? '',
      reason: raw['reason']?.toString() ?? '',
      ts: (raw['ts'] as num?)?.toInt() ?? 0,
      changed: raw['changed'] as bool? ?? true,
    );
  }

  static bool has(Block block) => read(block) != null;

  static void write(Block block, DeColoquialMeta meta) {
    final map = _mapOf(block);
    map[key] = {
      'original': meta.original,
      'cleaned': meta.cleaned,
      'reason': meta.reason,
      'ts': meta.ts,
      'changed': meta.changed,
    };
    block.metaJson = jsonEncode(map);
  }

  static void clear(Block block) {
    final map = _mapOf(block);
    map.remove(key);
    block.metaJson = jsonEncode(map);
  }

  static Map<String, dynamic> _mapOf(Block block) {
    final raw = block.metaJson.trim();
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // 容错：损坏的 metaJson 当作空 map
    }
    return <String, dynamic>{};
  }
}
