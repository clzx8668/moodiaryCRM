import 'package:moodiary/features/ai/triage/naive_bayes_model.dart';
import 'package:moodiary/features/ai/triage/triage_rules.dart';
import 'package:moodiary/features/ai/triage/triage_types.dart';

/// 第二级：**本地轻量分类器**（可选兜底）。
///
/// 规则引擎只能判"命中/未命中"，对"第一级没命中但内容其实值得处理"的情况无能为力
/// （例如没有明显信号词、但写了一大段有结构的内容）。
/// 这一级用**可解释的特征打分**做兜底判断：
///
/// | 特征 | 含义 |
/// | :-- | :-- |
/// | 信息量 | 长度、是否成篇 |
/// | 结构度 | 标点/分点/换行，说明"写成了东西" |
/// | 主题度 | 是否含主题名词，标签/分类才有意义 |
/// | 行动度 | 是否含时间/待办线索 |
/// | 噪声度 | 是否像测试占位内容（负权重） |
///
/// 刻意保持**线性 + 可解释**：每个特征都能单独拉出来给用户看，
/// 而不是一个黑盒分类器。后续要换成真正的端侧文本分类模型时，
/// 只要实现同一个 [score] 契约即可（[AiTriageRouter] 不感知实现）。
class LightTextClassifier {
  const LightTextClassifier();

  /// 朴素贝叶斯（字符二元/三元组 + 关键词特征）：
  /// - 纯 Dart、无依赖、微秒级；
  /// - 训练数据在 `ClassifierTrainingData`（可测试、可逐步补充）；
  /// - 输出的不仅是分数，还有**贡献最大的特征**，所以依然可解释。
  static final NaiveBayesModel _bayes = NaiveBayesModel.train();

  /// 特征权重（和为 1.0，便于把总分当概率看）
  static const double wInformation = 0.30;
  static const double wStructure = 0.25;
  static const double wTopic = 0.25;
  static const double wAction = 0.20;

  /// 达到这个分就认为"值得送 AI"
  static const double threshold = 0.42;

  /// 打分（0..1）与命中的特征说明。
  ClassifierScore score(String text) {
    final t = text.trim();
    if (t.isEmpty) {
      return const ClassifierScore(0, []);
    }
    // 主判：朴素贝叶斯（字符 n-gram + 关键词特征）
    final bayes = _bayes.classify(t);
    final reasons = <String>[];

    // 贝叶斯给的解释（贡献最大的几个特征）
    for (final c in bayes.topContributors) {
      reasons.add('特征「${c.feature}」→ ${c.label}（+${c.weight.toStringAsFixed(2)}）');
    }

    // ── 以下为可解释的**规则特征**，与贝叶斯结果取加权，
    //    保证短样本上不比原来的线性打分差，也便于人工核对
    var linear = 0.0;
    final linearReasons = <String>[];

    // 1) 信息量：4 字→0，120 字→1
    final len = TriageRules.meaningfulLength(t);
    final information = ((len - 4) / 116).clamp(0.0, 1.0);
    if (information >= 0.4) linearReasons.add('内容成篇（$len 字）');

    // 2) 结构度：标点、分点、换行
    var structure = 0.0;
    final punct = RegExp(r'[。！？；，]').allMatches(t).length;
    structure += (punct / 6).clamp(0.0, 0.6);
    if (RegExp(r'\n').hasMatch(t)) structure += 0.2;
    if (RegExp(r'^\s*[-*·•\d]+[.、)]', multiLine: true).hasMatch(t)) {
      structure += 0.2;
    }
    structure = structure.clamp(0.0, 1.0);
    if (structure >= 0.5) linearReasons.add('表达有结构（标点/分点）');

    // 3) 主题度
    final topic = TriageRules.hasTopicSignal(t) ? 1.0 : 0.0;
    if (topic > 0) linearReasons.add('含主题词，适合打标签/归类');

    // 4) 行动度
    final action = TriageRules.hasExtractableSignal(t) ? 1.0 : 0.0;
    if (action > 0) linearReasons.add('含行动线索（时间/待办）');

    linear =
        information * wInformation +
        structure * wStructure +
        topic * wTopic +
        action * wAction;

    // 5) 噪声惩罚：像测试占位内容
    if (TriageRules.looksPlaceholder(t)) {
      linear *= 0.4;
      linearReasons.add('疑似测试/占位内容（降权）');
    }
    if (TriageRules.looksPrivateJournal(t)) {
      linearReasons.add('私人情绪记录（本地优先）');
    }

    // 融合：贝叶斯为主（学到标注经验），线性特征兜底（规则可核对）
    final blended = bayes.probability * 0.65 + linear.clamp(0.0, 1.0) * 0.35;

    // 解释里只保留最有信息量的几条，避免刷屏
    final merged = <String>[...reasons.take(2), ...linearReasons.take(2)];
    return ClassifierScore(blended.clamp(0.0, 1.0), merged);
  }

  /// 是否达到"值得送 AI"的门槛
  bool shouldEscalate(String text) => score(text).value >= threshold;

  /// 生成一条分类器决策（第二级被调用时使用）
  TriageDecision decide({
    required TriageOperation operation,
    required String text,
    required bool localHandled,
  }) {
    final s = score(text);
    final escalate = s.value >= threshold;
    return TriageDecision(
      operation: operation,
      action: escalate ? TriageAction.sendToAI : TriageAction.keepLocal,
      confidence: s.value,
      reason: escalate
          ? '本地分类器认为值得处理（${(s.value * 100).toStringAsFixed(0)}%）：'
                '${s.reasons.isEmpty ? '综合分达标' : s.reasons.first}'
          : localHandled
          ? '本地已能处理，未达到送 AI 门槛（${(s.value * 100).toStringAsFixed(0)}%）'
          : '信息量不足，本地保存即可（${(s.value * 100).toStringAsFixed(0)}%）',
      fromClassifier: true,
      signals: [
        for (final r in s.reasons)
          TriageSignal(
            ruleId: 'classifier',
            label: r,
            bias: escalate ? TriageAction.sendToAI : TriageAction.keepLocal,
          ),
      ],
    );
  }
}

/// 分类器打分结果。
class ClassifierScore {
  /// 0..1
  final double value;

  /// 可解释的原因
  final List<String> reasons;

  const ClassifierScore(this.value, this.reasons);
}
