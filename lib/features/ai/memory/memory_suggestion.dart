/// 自学习**建议**：AI 任务结束后，本地判断"这次产出里有没有值得记住的东西"。
///
/// 设计原则（批次 120，用户选定的"建议式"）：
/// - **纯本地启发式**：不额外调用模型，零 token、零延迟；
/// - **只建议不落盘**：生成一条候选，等用户点了"记住"才写进 `memory.md` / `skills/`；
/// - **给得出理由**：每条建议都附"为什么要记"，用户才好判断。
class MemorySuggestion {
  /// 建议保存的目标
  final MemorySuggestionKind kind;

  /// 建议的标题（技能手册用它当文件名；记忆用它做小标题）
  final String title;

  /// 要落盘的内容（Markdown）
  final String content;

  /// 一句话理由（给用户看）
  final String reason;

  /// 置信度 0..1（低于阈值不展示）
  final double confidence;

  const MemorySuggestion({
    required this.kind,
    required this.title,
    required this.content,
    required this.reason,
    required this.confidence,
  });

  @override
  String toString() =>
      'MemorySuggestion(${kind.name}, $title, ${(confidence * 100).toStringAsFixed(0)}%)';
}

enum MemorySuggestionKind {
  /// 长期事实/偏好 → 写 `memory.md`
  memory,

  /// 可复用流程 → 写 `skills/<标题>.md`
  skill,
}

/// 从一段 AI 产出里挑出值得记的东西（纯函数，可单测）。
class MemorySuggestionDetector {
  MemorySuggestionDetector._();

  /// 低于这个置信度不建议（避免"什么都要记"的骚扰）
  static const double threshold = 0.55;

  /// 长期事实/偏好的标记词（出现这些说明是"稳定信息"）
  static const List<String> _stableMarkers = [
    '我常',
    '我一直',
    '我习惯',
    '我偏好',
    '我喜欢',
    '我不喜欢',
    '我的客户',
    '我的工作',
    '我负责',
    '我在',
    '以后请',
    '以后都',
    '以后要',
    '下次请',
    '默认',
    '统一用',
    '记住',
  ];

  /// 流程/手册的标记词（有这些说明是"可复用的做法"）
  static const List<String> _procedureMarkers = [
    '步骤',
    '流程',
    '第一步',
    '然后',
    '接着',
    '最后',
    '做法',
    '模板',
    '话术',
    '以后遇到',
    '下次遇到',
  ];

  /// 否定标记：这些内容不值得进长期记忆
  static final RegExp _transient = RegExp(
    r'(今天|昨天|刚才|临时|这一次|这次会议|本次)',
  );

  /// 从 AI 产出里生成建议；没有可记的东西返回 null。
  ///
  /// [userAsk] 是用户当时的要求，用来给标题与理由提供上下文。
  static MemorySuggestion? detect({
    required String aiOutput,
    String userAsk = '',
  }) {
    final out = aiOutput.trim();
    // 太短的建议价值低，但也不能太苛刻——
    // 一条"我常驻上海，客户在制造业"本身就短，却是典型该记的内容。
    if (out.length < 30) return null;

    final memoryScore = _scoreMemory(out);
    final skillScore = _scoreSkill(out);
    if (memoryScore < threshold && skillScore < threshold) return null;

    // 取分高的那个；平手时优先"流程"（信息量更大）
    if (skillScore >= memoryScore) {
      return MemorySuggestion(
        kind: MemorySuggestionKind.skill,
        title: _skillTitle(userAsk, out),
        content: _asSkillDoc(_skillTitle(userAsk, out), out),
        reason: '这次给了一份可复用的做法，存成技能手册下次能直接用',
        confidence: skillScore,
      );
    }
    return MemorySuggestion(
      kind: MemorySuggestionKind.memory,
      title: _memoryTitle(userAsk),
      content: _asMemoryEntry(out),
      reason: '里面有稳定的事实或偏好，记下来以后不用重复说明',
      confidence: memoryScore,
    );
  }

  /// 长期事实/偏好的置信度
  static double _scoreMemory(String text) {
    if (_transient.hasMatch(text) && !_hasStableMarker(text)) return 0;
    var score = 0.0;
    score += _countHits(text, _stableMarkers).clamp(0, 3) * 0.22;
    // 第一人称陈述句（"我…"）权重更高
    final firstPerson = RegExp(r'(^|\n)\s*[-*\d.)\s]*我').allMatches(text).length;
    score += firstPerson.clamp(0, 3) * 0.12;
    // 明确"以后都这样"的语气
    if (RegExp(r'(以后|下次|默认)').hasMatch(text)) score += 0.2;
    // 太长的不像"稳定事实"，更像长文
    if (text.length > 1500) score -= 0.2;
    return score.clamp(0.0, 1.0);
  }

  /// 可复用流程的置信度
  static double _scoreSkill(String text) {
    var score = 0.0;
    score += _countHits(text, _procedureMarkers).clamp(0, 4) * 0.18;
    // 有序/无序列表结构
    final bullets = RegExp(r'(^|\n)\s*([-*]|\d+[.)])\s+')
        .allMatches(text)
        .length;
    if (bullets >= 3) score += 0.3;
    if (bullets >= 6) score += 0.1;
    // 有二级标题说明是结构化成文
    if (RegExp(r'(^|\n)##\s+').hasMatch(text)) score += 0.15;
    // 明显的模板/话术类产出
    if (RegExp(r'(模板|话术|清单|检查表)').hasMatch(text)) score += 0.2;
    return score.clamp(0.0, 1.0);
  }

  static bool _hasStableMarker(String text) =>
      _countHits(text, _stableMarkers) > 0;

  static int _countHits(String text, List<String> markers) {
    var n = 0;
    for (final m in markers) {
      if (text.contains(m)) n++;
    }
    return n;
  }

  /// 技能手册标题：优先用用户的要求（更贴近"以后怎么问"），否则取首行
  static String _skillTitle(String userAsk, String output) {
    final ask = userAsk.trim();
    if (ask.isNotEmpty && ask.length <= 20) return ask;
    final firstLine = output
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^#+\s*'), '').trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return '未命名流程';
    return firstLine.length <= 20 ? firstLine : '${firstLine.substring(0, 20)}…';
  }

  /// 记忆条目标题（用用户的问题做小标题，便于日后对照）
  static String _memoryTitle(String userAsk) {
    final ask = userAsk.trim();
    if (ask.isEmpty) return '关于我的信息';
    return ask.length <= 20 ? ask : '${ask.substring(0, 20)}…';
  }

  /// 组装技能手册文档（固定骨架，方便日后 AI 检索命中）
  static String _asSkillDoc(String title, String body) => '''
# $title

## 什么时候用

（可补充触发场景）

## 做法

${body.trim()}
''';

  /// 组装记忆条目（去掉可能存在的对话腔）
  static String _asMemoryEntry(String body) => body.trim();
}
