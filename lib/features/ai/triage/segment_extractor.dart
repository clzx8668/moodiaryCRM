import 'package:moodiary/features/ai/triage/time_signals.dart';
import 'package:moodiary/features/ai/triage/triage_rules.dart';

/// 第三级优化：**只送相关片段，不送全文**。
///
/// 命中分流后，把长笔记整篇发给 AI 有三个问题：贵（token 多）、
/// 隐私差（无关的私人内容也出门）、准确率反而更低（无关内容干扰）。
///
/// 做法：按句切分 → 标出"含触发信号"的句子 → **前后各留一句作上下文** →
/// 其余丢弃。只要保留的片段明显短于全文就采用（否则原文发送更稳）。
class SegmentExtractor {
  SegmentExtractor._();

  /// 句子分隔符（中英文标点 + 换行）
  static final RegExp _boundary = RegExp(r'[。！？；\n\r]+');

  /// 采用片段的最低"压缩收益"：片段长度必须小于全文的 [minSaving]
  static const double minSaving = 0.9;

  /// 单片段最大字符数（超过则按需截断，避免一段超长）
  static const int maxSegmentChars = 600;

  /// 提取结果
  static SegmentResult extract(String text) {
    final full = text.trim();
    if (full.isEmpty) {
      return const SegmentResult(relevant: '', matchedCount: 0, trimmed: false);
    }
    final sentences = splitSentences(full);
    if (sentences.length <= 1) {
      // 单句也可能是超长（语音转写常见），同样要限长
      final cut = full.length > maxSegmentChars
          ? '${full.substring(0, maxSegmentChars)}…'
          : full;
      return SegmentResult(
        relevant: cut,
        matchedCount: _isRelevant(full) ? 1 : 0,
        trimmed: cut.length < full.length,
      );
    }

    final indexes = <int>{};
    var matched = 0;
    for (var i = 0; i < sentences.length; i++) {
      if (!_isRelevant(sentences[i])) continue;
      matched++;
      // 前后各留一句作为上下文（保留指代/因果，避免断章取义）
      for (var j = i - 1; j <= i + 1; j++) {
        if (j >= 0 && j < sentences.length) indexes.add(j);
      }
    }

    // 没命中任何句子：说明信号在跨句/整篇层面（例如只有主题词），原文发送
    if (matched == 0) {
      return SegmentResult(
        relevant: full,
        matchedCount: 0,
        trimmed: false,
      );
    }

    final sorted = indexes.toList()..sort();
    final kept = <String>[];
    int? prev;
    for (final i in sorted) {
      if (prev != null && i > prev + 1) kept.add('…'); // 跳过的段落标记
      kept.add(sentences[i].trim());
      prev = i;
    }
    var segment = kept.where((s) => s.isNotEmpty).join('。');
    if (!segment.endsWith('。') && !segment.endsWith('？') &&
        !segment.endsWith('！')) {
      segment = '$segment。';
    }
    // 单段上限：超长先截断，再判断压缩收益（顺序很重要，否则超长片段会顶不住）
    if (segment.length > maxSegmentChars) {
      segment = '${segment.substring(0, maxSegmentChars)}…';
    }

    // 压缩收益不足时宁可用全文（例如原文本来就短）
    if (segment.length >= full.length * minSaving) {
      return SegmentResult(
        relevant: full,
        matchedCount: matched,
        trimmed: false,
      );
    }
    return SegmentResult(
      relevant: segment,
      matchedCount: matched,
      trimmed: true,
    );
  }

  /// 按句切分（保留句子内容，去掉纯空白）
  static List<String> splitSentences(String text) {
    return text
        .split(_boundary)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 该句是否含触发信号（时间 / 待办词 / 日程词 / 商机词）
  static bool _isRelevant(String sentence) {
    if (TimeSignals.has(sentence)) return true;
    for (final w in TriageRules.todoKeywords) {
      if (sentence.contains(w)) return true;
    }
    for (final w in TriageRules.scheduleKeywords) {
      if (sentence.contains(w)) return true;
    }
    for (final w in TriageRules.crmSignals) {
      if (sentence.contains(w)) return true;
    }
    return false;
  }

  /// 是否值得用片段替代全文（供调用方快速判断）
  static bool hasRelevantSegment(String text) => extract(text).trimmed;
}

/// 片段提取结果
class SegmentResult {
  /// 建议发送的相关片段（未截取时等于原文）
  final String relevant;

  /// 命中的句子数
  final int matchedCount;

  /// 是否真的做了截取（true 表示比原文短）
  final bool trimmed;

  const SegmentResult({
    required this.relevant,
    required this.matchedCount,
    required this.trimmed,
  });

  @override
  String toString() =>
      'SegmentResult(trimmed=$trimmed, matched=$matchedCount, len=${relevant.length})';
}
