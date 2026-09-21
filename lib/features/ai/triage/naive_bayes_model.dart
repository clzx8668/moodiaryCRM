import 'dart:math' as math;

import 'package:moodiary/features/ai/triage/classifier_training_data.dart';

/// 极轻量的**朴素贝叶斯二分类器**（纯 Dart，零依赖，微秒级）。
///
/// 为什么选它（对应方案里的"方案C"）：
/// - 训练/推理都在本地，不需要模型文件、不需要分词库；
/// - 中文用**字符 n-gram**（1/2/3 元）当特征，绕开分词；
/// - 在几百条标注上就能给出可用区分度，且**每个特征的贡献都能打印出来**，
///   不像神经网络那样只能给一个分数。
///
/// 之后若要换成 fastText / TinyBERT，只要提供同样的
/// `probability + topContributors` 输出即可，上层无需改动。
class NaiveBayesModel {
  NaiveBayesModel._({
    required this.positiveCount,
    required this.negativeCount,
    required this.logPrior,
    required this.featureLogProb,
    required this.vocabularySize,
  });

  /// 正类（需要 AI）样本数
  final int positiveCount;

  /// 负类（本地保存）样本数
  final int negativeCount;

  /// 先验 log 比（正/负）
  final double logPrior;

  /// 特征 → [正类 log 概率, 负类 log 概率]
  final Map<String, List<double>> featureLogProb;

  /// 特征表大小（用于拉普拉斯平滑）
  final int vocabularySize;

  /// 用内置标注数据训练
  factory NaiveBayesModel.train() =>
      NaiveBayesModel.fromSamples(
        positive: ClassifierTrainingData.actionable,
        negative: ClassifierTrainingData.localsOnly,
      );

  /// 用给定样本训练（便于测试与以后增量学习）
  factory NaiveBayesModel.fromSamples({
    required List<String> positive,
    required List<String> negative,
  }) {
    final posCounts = <String, int>{};
    final negCounts = <String, int>{};
    var posTotal = 0;
    var negTotal = 0;

    for (final s in positive) {
      for (final f in featuresOf(s)) {
        posCounts[f] = (posCounts[f] ?? 0) + 1;
        posTotal++;
      }
    }
    for (final s in negative) {
      for (final f in featuresOf(s)) {
        negCounts[f] = (negCounts[f] ?? 0) + 1;
        negTotal++;
      }
    }

    final vocab = <String>{...posCounts.keys, ...negCounts.keys};
    final v = math.max(vocab.length, 1);

    final logProb = <String, List<double>>{};
    for (final f in vocab) {
      // 拉普拉斯平滑（+1），避免未出现特征把概率打成 0
      final pPos = ((posCounts[f] ?? 0) + 1) / (posTotal + v);
      final pNeg = ((negCounts[f] ?? 0) + 1) / (negTotal + v);
      logProb[f] = [math.log(pPos), math.log(pNeg)];
    }

    final p = math.max(positive.length, 1);
    final n = math.max(negative.length, 1);
    return NaiveBayesModel._(
      positiveCount: p,
      negativeCount: n,
      logPrior: math.log(p / (p + n)) - math.log(n / (p + n)),
      featureLogProb: logProb,
      vocabularySize: v,
    );
  }

  /// 分类：返回正类概率与贡献最大的特征（可解释）。
  BayesResult classify(String text) {
    final feats = featuresOf(text);
    if (feats.isEmpty) {
      return const BayesResult(probability: 0.5, topContributors: []);
    }
    var logOdds = logPrior;
    // 未知特征用平滑后的默认值（不改变先验）
    final unknownPos = math.log(1 / (positiveCount * 2.0 + vocabularySize));
    final unknownNeg = math.log(1 / (negativeCount * 2.0 + vocabularySize));
    logOdds += unknownPos - unknownNeg; // 默认特征一次即可

    final contributions = <_Contribution>[];
    for (final f in feats) {
      final lp = featureLogProb[f];
      if (lp == null) continue;
      final delta = lp[0] - lp[1];
      logOdds += delta;
      contributions.add(_Contribution(feature: f, delta: delta));
    }

    // sigmoid → 概率
    final prob = 1 / (1 + math.exp(-logOdds.clamp(-30.0, 30.0)));

    contributions.sort(
      (a, b) => b.delta.abs().compareTo(a.delta.abs()),
    );
    final top = contributions
        .take(3)
        .map(
          (c) => BayesFeature(
            feature: _pretty(c.feature),
            label: c.delta > 0 ? '更像要办的事' : '更像随手记',
            weight: c.delta.abs(),
          ),
        )
        .toList();

    return BayesResult(probability: prob, topContributors: top);
  }

  /// 字符 n-gram 特征（1/2/3 元）+ 是否含数字
  ///
  /// 纯函数、可测：中文不用分词也能拿到足够区分度。
  static List<String> featuresOf(String raw) {
    // 去掉空白与中文标点（标点对二分类没有信息量，只会引入噪声）
    final t = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp('[\u3000-\u303F\uFF00-\uFFEF]'), '');
    if (t.isEmpty) return const [];
    final out = <String>{};
    final chars = t.runes.map(String.fromCharCode).toList();
    // 一元：整串长度不大时才有意义，限制数量避免噪声
    if (chars.length <= 24) {
      for (final c in chars) {
        out.add('1$c');
      }
    }
    for (var i = 0; i + 1 < chars.length; i++) {
      out.add('2${chars[i]}${chars[i + 1]}');
    }
    for (var i = 0; i + 2 < chars.length; i++) {
      out.add('3${chars[i]}${chars[i + 1]}${chars[i + 2]}');
    }
    if (RegExp(r'\d').hasMatch(t)) out.add('D数字');
    return out.toList();
  }

  /// 特征名还原成人能看的片段（去掉 1/2/3 前缀）
  static String _pretty(String f) =>
      f.startsWith('1') || f.startsWith('2') || f.startsWith('3')
      ? f.substring(1)
      : f;
}

/// 分类结果
class BayesResult {
  /// 正类（需要 AI）概率 0..1
  final double probability;

  /// 贡献最大的特征（已排序）
  final List<BayesFeature> topContributors;

  const BayesResult({
    required this.probability,
    required this.topContributors,
  });
}

/// 可展示的特征贡献
class BayesFeature {
  final String feature;
  final String label;
  final double weight;

  const BayesFeature({
    required this.feature,
    required this.label,
    required this.weight,
  });
}

class _Contribution {
  final String feature;
  final double delta;

  const _Contribution({required this.feature, required this.delta});
}
