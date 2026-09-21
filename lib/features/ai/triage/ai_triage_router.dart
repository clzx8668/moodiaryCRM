import 'package:moodiary/features/ai/triage/light_classifier.dart';
import 'package:moodiary/features/ai/triage/segment_extractor.dart';
import 'package:moodiary/features/ai/triage/signal_scorer.dart';
import 'package:moodiary/features/ai/triage/triage_config.dart';
import 'package:moodiary/features/ai/triage/triage_rules.dart';
import 'package:moodiary/features/ai/triage/triage_types.dart';

/// 分流路由器：把「第一级规则 → 第二级分类器 → 第三级大模型」串起来。
///
/// 纯函数式设计（不碰存储/网络）：配置由调用方传入，
/// 这样单测可以把每一档策略、每一条规则都钉死。
class AiTriageRouter {
  const AiTriageRouter({this.classifier = const LightTextClassifier()});

  final LightTextClassifier classifier;

  /// 对一条内容做完整分流。
  ///
  /// [operations]：本次**候选**操作；调用方通常只传自己已经决定要跑的那些
  /// （例如按自动标签/自动分类开关过滤后的集合）。
  /// [explicitUserIntent]：用户显式选择的处理（例如快速收集里选了"待办提取"模板）。
  /// 用户显式要求视为已确认，直接送 AI，但仍受敏感信息闸门约束。
  TriageResult route({
    required String text,
    required List<TriageOperation> operations,
    required TriageConfig config,
    TriageContentType contentType = TriageContentType.text,
    Set<TriageOperation> explicitUserIntent = const {},
    String? extraSensitiveText,
  }) {
    // 敏感检查要把附带内容（如链接正文、图片 OCR 文本）也算进去
    final scanText = extraSensitiveText == null || extraSensitiveText.isEmpty
        ? text
        : '$text\n$extraSensitiveText';
    final sensitiveKinds = TriageRules.detectSensitive(scanText);
    final hasSensitive = sensitiveKinds.isNotEmpty;

    final signals = <TriageSignal>[
      if (hasSensitive)
        TriageSignal(
          ruleId: 'sensitive',
          label: '含敏感信息（${sensitiveKinds.join('、')}）',
          bias: TriageAction.sensitiveLocalOnly,
        ),
    ];

    final decisions = <TriageOperation, TriageDecision>{};
    var usedClassifier = false;
    var confSum = 0.0;

    // 第一级打分（点数制）：同时用于判定与"为什么"展示
    final score = SignalScorer.score(text);
    // 只送相关片段：命中后截取含信号的句子（前后各留一句上下文）
    final segment = SegmentExtractor.extract(text);

    for (final op in operations) {
      final d = _decideOperation(
        op: op,
        text: text,
        config: config,
        hasSensitive: hasSensitive,
        sensitiveKinds: sensitiveKinds,
        explicitUserIntent: explicitUserIntent.contains(op),
        score: score,
      );
      decisions[op] = d;
      confSum += d.confidence;
      if (d.fromClassifier) usedClassifier = true;
      signals.addAll(d.signals);
    }

    return TriageResult(
      contentType: contentType,
      decisions: decisions,
      hasSensitive: hasSensitive,
      sensitiveKinds: sensitiveKinds,
      signals: _dedupe(signals),
      confidence: operations.isEmpty ? 0 : confSum / operations.length,
      usedClassifier: usedClassifier,
      score: score.total,
      scoreDetail: score.hits.map((h) => h.toString()).toList(),
      relevantSegment: segment.relevant,
    );
  }

  TriageDecision _decideOperation({
    required TriageOperation op,
    required String text,
    required TriageConfig config,
    required bool hasSensitive,
    required List<String> sensitiveKinds,
    required bool explicitUserIntent,
    required SignalScore score,
  }) {
    // 0) 操作被用户关掉 → 本地
    if (!config.isEnabled(op)) {
      return TriageDecision(
        operation: op,
        action: TriageAction.keepLocal,
        confidence: 1,
        reason: '该操作已在设置里关闭',
      );
    }

    // 1) 隐私闸门：敏感内容默认不出门（用户显式选择也拦，除非开了总开关）
    final isCloudOp = _isCloudOperation(op);
    if (hasSensitive && isCloudOp && !config.allowSensitiveToCloud) {
      return TriageDecision(
        operation: op,
        action: TriageAction.sensitiveLocalOnly,
        confidence: 1,
        reason: '含敏感信息（${sensitiveKinds.join('、')}），未上传云端',
        signals: [
          const TriageSignal(
            ruleId: 'sensitive',
            label: '隐私保护：本地保存',
            bias: TriageAction.sensitiveLocalOnly,
          ),
        ],
      );
    }

    // 2) 纯本地操作（如向量索引）：永远不需要云端
    if (!isCloudOp) {
      return TriageDecision(
        operation: op,
        action: TriageAction.keepLocal,
        confidence: 1,
        reason: '本地即可完成',
      );
    }

    // 3) 空内容 / 纯符号 / 无实义 → 本地
    if (TriageRules.isTrivial(text)) {
      return TriageDecision(
        operation: op,
        action: TriageAction.keepLocal,
        confidence: 1,
        reason: '内容过短或无语义，无需 AI',
      );
    }

    // 4) 用户显式要求（选了模板/手动触发）→ 视为已确认
    if (explicitUserIntent) {
      return TriageDecision(
        operation: op,
        action: TriageAction.sendToAI,
        confidence: 1,
        reason: '你手动选择了这项处理',
      );
    }

    // 5) 额度闸门
    if (config.quota.exhausted) {
      return TriageDecision(
        operation: op,
        action: TriageAction.keepLocal,
        confidence: 1,
        reason: '本月 AI 额度已用完，已转为本地保存',
      );
    }

    // 6) 第一级：规则命中判定
    final rule = _ruleVerdict(op, text, score);
    if (rule != null) return rule;

    // 7) 第二级：本地轻量分类器兜底（保守档不走这级）
    if (config.level == TriageLevel.conservative) {
      return TriageDecision(
        operation: op,
        action: TriageAction.keepLocal,
        confidence: 0.6,
        reason: '未命中分流信号（保守策略：本地保存）',
      );
    }
    if (config.level == TriageLevel.aggressive) {
      return TriageDecision(
        operation: op,
        action: TriageAction.sendToAI,
        confidence: 0.7,
        reason: '激进策略：本地不拦，交给 AI',
      );
    }
    return classifier.decide(
      operation: op,
      text: text,
      localHandled: false,
    );
  }

  /// 第一级规则：返回 null 表示"规则拿不准"，交给第二级。
  TriageDecision? _ruleVerdict(
    TriageOperation op,
    String text,
    SignalScore score,
  ) {
    switch (op) {
      case TriageOperation.extractPlan:
        // 打分制：累加命中信号，≥ 阈值(3) 才认为"值得抽取"
        if (score.shouldEscalate) {
          final kinds = <String>[
            if (_hasKind(score, SignalKind.time)) '时间',
            if (_hasKind(score, SignalKind.todo)) '待办',
            if (_hasKind(score, SignalKind.schedule)) '日程',
            if (_hasKind(score, SignalKind.crm)) '商机',
          ];
          return TriageDecision(
            operation: op,
            action: TriageAction.sendToAI,
            confidence: (0.6 + score.total * 0.1).clamp(0.0, 0.98),
            reason:
                '规则打分 ${score.total} 分（${score.explanation}）≥ 阈值 ${SignalScorer.threshold}，值得抽取',
            signals: [
              for (final k in (kinds.isEmpty ? ['结构化信号'] : kinds))
                TriageSignal(
                  ruleId: 'score',
                  label: '$k（合计 ${score.total} 分）',
                  bias: TriageAction.sendToAI,
                ),
            ],
          );
        }
        // 分数不够：把"差多少分"讲清楚，便于用户理解为什么没上云
        if (score.total > 0) {
          return TriageDecision(
            operation: op,
            action: TriageAction.keepLocal,
            confidence: 0.7,
            reason:
                '规则打分 ${score.total} 分 < 阈值 ${SignalScorer.threshold}（${score.explanation}），本地保存',
            signals: [
              TriageSignal(
                ruleId: 'score',
                label: '${score.total} 分（需 ${SignalScorer.threshold} 分）',
                bias: TriageAction.keepLocal,
              ),
            ],
          );
        }
        // 纯私人情绪记录，抽待办没有意义
        if (TriageRules.looksPrivateJournal(text)) {
          return TriageDecision(
            operation: op,
            action: TriageAction.keepLocal,
            confidence: 0.85,
            reason: '私人记录，未发现待办/商机线索',
          );
        }
        return null;

      case TriageOperation.autoTag:
      case TriageOperation.autoClassify:
        if (TriageRules.looksPlaceholder(text)) {
          return TriageDecision(
            operation: op,
            action: TriageAction.keepLocal,
            confidence: 0.9,
            reason: '疑似测试/占位内容，不值得打标签',
          );
        }
        final len = TriageRules.meaningfulLength(text);
        if (len < 8 && !TriageRules.hasTopicSignal(text)) {
          return TriageDecision(
            operation: op,
            action: TriageAction.keepLocal,
            confidence: 0.8,
            reason: '内容太短（$len 字），标签意义不大',
          );
        }
        if (TriageRules.hasTopicSignal(text) ||
            TriageRules.looksStructured(text)) {
          return TriageDecision(
            operation: op,
            action: TriageAction.sendToAI,
            confidence: 0.85,
            reason: '含主题词或已成篇，适合打标签/归类',
          );
        }
        return null;

      case TriageOperation.autoSummary:
        if (TriageRules.meaningfulLength(text) >= TriageRules.longContentChars) {
          return TriageDecision(
            operation: op,
            action: TriageAction.sendToAI,
            confidence: 0.9,
            reason: '内容较长（${TriageRules.meaningfulLength(text)} 字），值得摘要',
          );
        }
        if (TriageRules.looksPrivateJournal(text)) {
          return TriageDecision(
            operation: op,
            action: TriageAction.keepLocal,
            confidence: 0.8,
            reason: '私人记录，不做摘要',
          );
        }
        return null;

      case TriageOperation.deColloquial:
        // 去口语化的判定交给已有的 ColloquialDetector（调用方过滤后再传进来），
        // 这里只在"明显书面语"时挡一下，避免白跑。
        if (TriageRules.looksStructured(text) &&
            !RegExp(r'(嗯|啊|就是|那个|然后)').hasMatch(text)) {
          return TriageDecision(
            operation: op,
            action: TriageAction.keepLocal,
            confidence: 0.8,
            reason: '已接近书面语，无需去口语化',
          );
        }
        return null;

      case TriageOperation.enrich:
        // 图片/链接/语音的补全属于"内容本身没落地"，一律要处理；
        // 但要被敏感闸门与额度挡在前面（已在上游处理）。
        return TriageDecision(
          operation: op,
          action: TriageAction.sendToAI,
          confidence: 0.9,
          reason: '附件内容需要补全（抓取/转写/识别）',
        );

      case TriageOperation.aiTemplate:
        // 模板是用户显式选择，上游会以 explicitUserIntent 传入；
        // 走到这里说明没有显式意图（例如系统默认模板），保守处理。
        return TriageDecision(
          operation: op,
          action: TriageAction.keepLocal,
          confidence: 0.6,
          reason: '未选择具体模板，保持本地',
        );

      case TriageOperation.embedding:
        return TriageDecision(
          operation: op,
          action: TriageAction.keepLocal,
          confidence: 1,
          reason: '本地即可完成',
        );
    }
  }

  /// 该操作是否需要云端。
  static bool _isCloudOperation(TriageOperation op) => switch (op) {
    TriageOperation.embedding => false,
    _ => true,
  };

  /// 打分明细里是否包含某类信号
  static bool _hasKind(SignalScore score, SignalKind kind) =>
      score.hits.any((h) => h.kind == kind);

  static List<TriageSignal> _dedupe(List<TriageSignal> signals) {
    final seen = <String>{};
    final out = <TriageSignal>[];
    for (final s in signals) {
      final key = '${s.ruleId}|${s.label}|${s.bias.name}';
      if (seen.add(key)) out.add(s);
    }
    return out;
  }
}
