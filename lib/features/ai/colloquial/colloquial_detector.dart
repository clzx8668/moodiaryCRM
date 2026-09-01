/// 口语化检测器（本地规则，0 token）。
///
/// 只有"口语特征明显且较短"的内容才判定需要去口语化（shouldClean），
/// 避免对"本来就是行动项 / 简洁记录 / 长文"误触发 AI 处理。
/// 规则可测、无外部依赖。
class ColloquialReport {
  /// 0~1 口语化程度
  final double score;

  /// 命中的口语标记（用于 UI 说明原因）
  final List<String> reasons;

  /// 是否值得交给小模型去口语化
  final bool shouldClean;

  const ColloquialReport({
    required this.score,
    required this.reasons,
    required this.shouldClean,
  });
}

class ColloquialDetector {
  /// 触发去口语化的最低分数
  static const double threshold = 0.5;

  /// 只处理"简单内容"：最短 / 最长长度
  static const int minLen = 8;
  static const int maxLen = 200;

  /// 口头禅 / 填充词
  static const Set<String> fillers = {
    '然后',
    '就是',
    '那个',
    '这个',
    '其实',
    '反正',
    '就是说',
    '怎么说',
    '你懂',
    '对吧',
    '嗯嗯',
    '哈哈哈',
    'emmm',
    '就是说啊',
  };

  /// 语气词
  static const Set<String> particles = {
    '啊',
    '呀',
    '吧',
    '呢',
    '嗯',
    '哦',
    '嘛',
    '哈',
    '哎',
    '唉',
    '噢',
    '啦',
    '哟',
    '嘞',
    '呗',
    '哒',
  };

  /// 口语化短语
  static const List<String> oralPhrases = [
    '我记得',
    '我今天',
    '我觉得',
    '感觉',
    '有点',
    '特别',
    '真的',
    '好像',
    '有点那个',
    '就是那种',
  ];

  /// 行动项/祈使开头（这类内容本来就是待办/日程，不是去口语化目标）
  static final RegExp _directiveStart = RegExp(
    r'^(提醒|记得|明天|后天|下周|下个|早上|下午|帮我|联系|给|预约|开个|开会|准备|提交|发|约|要记得|该)',
  );

  static final RegExp _punct = RegExp(r'[，。！？,.!?；;、]');

  static ColloquialReport analyze(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length < minLen || t.length > maxLen) {
      return const ColloquialReport(score: 0, reasons: [], shouldClean: false);
    }

    final reasons = <String>[];
    final fillerCount = _countAll(t, fillers);
    final particleCount = _countAll(t, particles);
    final oralHit = oralPhrases.where((p) => t.contains(p)).toList();
    final noPunct = !_punct.hasMatch(t);
    final hasEmoji = _containsEmoji(t);
    final isDirective = _directiveStart.hasMatch(t);

    double score = 0;
    if (fillerCount > 0) {
      score += 0.35;
      reasons.add('口头禅/填充词 ×$fillerCount');
    }
    if (particleCount > 0) {
      score += 0.25;
      reasons.add('语气词 ×$particleCount');
    }
    if (oralHit.isNotEmpty) {
      score += 0.15;
      reasons.add('口语化表达（${oralHit.first}）');
    }
    if (noPunct && t.length > 12) {
      score += 0.15;
      reasons.add('缺少标点');
    }
    if (hasEmoji) {
      score += 0.1;
      reasons.add('含表情');
    }
    if (isDirective) {
      // 行动项不是"去口语化"目标，压低
      score -= 0.4;
    }

    score = score.clamp(0.0, 1.0);
    final shouldClean = score >= threshold && (fillerCount > 0 || particleCount > 0);
    return ColloquialReport(
      score: score,
      reasons: reasons,
      shouldClean: shouldClean,
    );
  }

  static int _countAll(String text, Set<String> tokens) {
    var count = 0;
    for (final token in tokens) {
      count += _countOccurrences(text, token);
    }
    return count;
  }

  static int _countOccurrences(String text, String token) {
    if (token.isEmpty) return 0;
    var count = 0;
    var idx = 0;
    while (true) {
      final i = text.indexOf(token, idx);
      if (i < 0) break;
      count++;
      idx = i + token.length;
    }
    return count;
  }

  /// 按 Unicode rune 判断是否含 emoji（避免 Dart 正则 `\u{}` 乱序问题）。
  static bool _containsEmoji(String text) {
    for (final r in text.runes) {
      if ((r >= 0x1F300 && r <= 0x1FAFF) ||
          (r >= 0x2600 && r <= 0x27BF) ||
          r == 0xFE0F) {
        return true;
      }
    }
    return false;
  }
}
