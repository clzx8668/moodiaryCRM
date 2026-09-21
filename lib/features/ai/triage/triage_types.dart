/// 「边缘预筛选 + 云端精处理」分层的公共契约（批次 109）。
///
/// 三级分流的定位：
/// ```
/// 用户输入
///   ├─ 第一级：本地规则引擎   ← 零成本 / 零延迟 / 完全离线
///   │     命中 → 送 AI；未命中 → 本地保存
///   ├─ 第二级：本地轻量分类器 ← 可选，对第一级未命中的内容进一步兜底
///   │     命中 → 送 AI；未命中 → 本地保存
///   └─ 第三级：云端（或本地大模型）  ← 只处理被上面选中的内容
/// ```
///
/// 本文件只放**纯数据契约**，不依赖任何存储/网络，便于单测与跨层复用。
library;

/// 分流结论。
enum TriageAction {
  /// 值得送 AI 深度处理
  sendToAI,

  /// 本地保存即可，不必花 AI 额度
  keepLocal,

  /// 含敏感信息：**默认不上云**，只做本地保存（隐私优先）
  sensitiveLocalOnly,

  /// 拿不准：按策略决定（保守策略下会问用户，平衡策略下按操作白名单放行）
  uncertain,
}

/// 需要做分流决策的 AI 操作类型（与队列任务类型一一对应）。
enum TriageOperation {
  /// 自动标签
  autoTag,

  /// 自动分类
  autoClassify,

  /// 自动摘要
  autoSummary,

  /// 去口语化
  deColloquial,

  /// 待办/日程/CRM 抽取
  extractPlan,

  /// 向量索引（本地即可完成，不需要云端）
  embedding,

  /// 模板类 AI 处理（用户在快速收集里显式选了模板 → 视为已确认）
  aiTemplate,

  /// 图片/链接/语音的补全（OSS 抓取、云端转写等）
  enrich,
}

/// 分流用的内容类型。
enum TriageContentType { text, voice, image, link, mixed }

/// 单条规则命中后的信号（用于给用户解释"为什么送/不送"）。
class TriageSignal {
  /// 规则 id（稳定标识，便于统计与测试）
  final String ruleId;

  /// 给用户看的一句话
  final String label;

  /// 这个信号支持"送 AI"还是"留在本地"
  final TriageAction bias;

  const TriageSignal({
    required this.ruleId,
    required this.label,
    required this.bias,
  });

  @override
  String toString() => '$ruleId(${bias.name}): $label';
}

/// 某个操作的分流决策。
class TriageDecision {
  final TriageOperation operation;
  final TriageAction action;

  /// 决策依据（0..1）：越高越确信
  final double confidence;

  /// 一句话理由（给用户看）
  final String reason;

  /// 命中的信号
  final List<TriageSignal> signals;

  /// 是否由"本地轻量分类器"（第二级）给出
  final bool fromClassifier;

  const TriageDecision({
    required this.operation,
    required this.action,
    required this.reason,
    this.confidence = 0,
    this.signals = const [],
    this.fromClassifier = false,
  });

  /// 是否应该真正调用 AI
  bool get shouldSendToAI => action == TriageAction.sendToAI;

  /// 是否属于"内容本身就该留在本地"
  bool get staysLocal =>
      action == TriageAction.keepLocal ||
      action == TriageAction.sensitiveLocalOnly;

  @override
  String toString() =>
      'TriageDecision(${operation.name} → ${action.name}, '
      '${(confidence * 100).toStringAsFixed(0)}%, $reason)';
}

/// 一次完整的分流结果（一条内容可能同时决定多个操作）。
class TriageResult {
  /// 内容类型
  final TriageContentType contentType;

  /// 是否检测到敏感信息（决定"能不能上云"）
  final bool hasSensitive;

  /// 敏感信息的类型说明（如"手机号/身份证号"）
  final List<String> sensitiveKinds;

  /// 各操作的决策（按 [TriageOperation] 去重，顺序与传入一致）
  final Map<TriageOperation, TriageDecision> decisions;

  /// 命中的全部信号（去重）
  final List<TriageSignal> signals;

  /// 规则/分类器的综合置信度（0..1）
  final double confidence;

  /// 是否由第二级分类器参与
  final bool usedClassifier;

  /// 第一级规则引擎的**总分**（点数制；见 `SignalScorer`）
  final int score;

  /// 打分明细（可展示给用户："+3 时间：明天 · +2 待办词：记得"）
  final List<String> scoreDetail;

  /// **只送相关片段**：命中后建议发送的片段（未截取时等于原文）
  final String relevantSegment;

  const TriageResult({
    required this.contentType,
    required this.decisions,
    this.hasSensitive = false,
    this.sensitiveKinds = const [],
    this.signals = const [],
    this.confidence = 0,
    this.usedClassifier = false,
    this.score = 0,
    this.scoreDetail = const [],
    this.relevantSegment = '',
  });

  /// 需要送 AI 的操作
  List<TriageOperation> get sendOperations => decisions.entries
      .where((e) => e.value.shouldSendToAI)
      .map((e) => e.key)
      .toList();

  /// 留在本地的操作
  List<TriageOperation> get localOperations => decisions.entries
      .where((e) => e.value.staysLocal)
      .map((e) => e.key)
      .toList();

  /// 是否整条内容都不需要上云
  bool get fullyLocal => sendOperations.isEmpty;

  /// 是否有可用的相关片段（未截取时也等于原文，仅作"取文本"的入口）
  bool get hasSegment => relevantSegment.trim().isNotEmpty;

  /// 一行摘要（列表/详情页展示用）
  String get summary {
    if (decisions.isEmpty) return '无需 AI 处理';
    final kept = localOperations.length;
    final sent = sendOperations.length;
    if (sent == 0) {
      return kept == 0 ? '无需 AI 处理' : '已在本地处理（$kept 项未上云）';
    }
    if (kept == 0) return '送 AI 处理（$sent 项）';
    return '本地处理 $kept 项 · 送 AI $sent 项';
  }

  @override
  String toString() =>
      'TriageResult(${contentType.name}, sensitive=$hasSensitive, $summary)';
}
