import 'dart:convert';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/isar.dart';

import 'colloquial_detector.dart';
import 'de_colloquial_meta.dart';
import 'info_preservation.dart';

/// 去口语化结果。
class DeColoquialResult {
  final String cleaned;
  final String reason;

  const DeColoquialResult({required this.cleaned, this.reason = ''});
}

/// 去口语化服务（P0）：检测 → 轻量模型 → 信息保全校验 → 写回。
///
/// 仅处理"短 + 口语明显"的简单内容；改写结果存到 `Block.metaJson.deColoquial`，
/// 原文保留，可一键还原。异常安全：AI 失败/格式错/校验不过一律返回 null（放弃处理）。
class DeColoquialService {
  static const int maxLen = 200;

  static const String _system =
      '你是文字整理助手。你只做"去口语化"：去掉口头禅/语气词、补全标点、理顺语序，'
      '使句子书面、可读。绝不改变原意：不得增删信息，不得改动人名、时间、数字、单位、'
      '专有名词。只输出 JSON，不要输出其它任何内容。';

  /// 对一段文本执行；返回清洗结果（null = 不处理 / 处理失败）。
  static Future<DeColoquialResult?> apply(String text) async {
    final report = ColloquialDetector.analyze(text);
    if (!report.shouldClean) return null;
    final t = text.trim();
    if (t.isEmpty || t.length > maxLen) return null;

    final provider = await AiProviderFactory.loadLight();
    if (!provider.isConfigured) return null;

    final completion = await provider.completeChat([
      const AiChatMessage(role: 'system', content: _system),
      AiChatMessage(role: 'user', content: _buildPrompt(t)),
    ]);
    final parsed = _parseJson(completion.content);
    if (parsed == null) return null;

    final rewritten = (parsed['rewritten']?.toString() ?? '').trim();
    if (rewritten.isEmpty || rewritten == t) return null;
    if (parsed['changed'] != true) return null;

    // 信息保全校验：关键信息丢失则丢弃本次改写
    final check = InfoPreservation.verify(t, rewritten);
    if (!check.ok) return null;

    return DeColoquialResult(
      cleaned: rewritten,
      reason: parsed['reason']?.toString() ?? '',
    );
  }

  /// 对日记的「主文本块」执行并写回（后台队列用）。
  static Future<bool> processDiary(String diaryId) async {
    final block = await _primaryTextBlock(diaryId);
    if (block == null) return false;
    return cleanBlock(block);
  }

  /// 对单个块执行并写回（详情页手动「去口语化」）。
  static Future<bool> cleanBlock(Block block) async {
    if (block.blockType != BlockType.text) return false;
    final result = await apply(block.content);
    if (result == null) return false;
    DeColoquialMeta.write(
      block,
      DeColoquialMeta(
        original: block.content,
        cleaned: result.cleaned,
        reason: result.reason,
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await IsarUtil.updateBlock(block);
    return true;
  }

  /// 清除某块的去口语化结果（还原原文）。
  static Future<void> restoreBlock(Block block) async {
    DeColoquialMeta.clear(block);
    await IsarUtil.updateBlock(block);
  }

  static Future<Block?> _primaryTextBlock(String diaryId) async {
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final texts = blocks
        .where((b) => b.blockType == BlockType.text && !b.isDeleted)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return texts.isEmpty ? null : texts.first;
  }

  static String _buildPrompt(String text) => '''
请把下面的口语化内容改写为书面表达。
要求：
- 只去掉冗余口头禅、补全标点、整理语序，不增删信息；
- 数字、日期、时间、电话、金额、人名、单位必须原样保留；
- 若内容已经很书面、几乎无需改动，返回 changed=false（rewritten 仍填原文）。

内容：
"""$text"""

返回 JSON：
{"rewritten":"...","changed":true|false,"reason":"..."}
''';

  static Map<String, dynamic>? _parseJson(String raw) {
    if (raw.trim().isEmpty) return null;
    var s = raw.trim();
    // 去掉 ```json ... ``` 代码围栏
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // 容错
    }
    return null;
  }
}
