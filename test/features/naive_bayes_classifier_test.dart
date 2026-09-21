import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/triage/classifier_training_data.dart';
import 'package:moodiary/features/ai/triage/light_classifier.dart';
import 'package:moodiary/features/ai/triage/naive_bayes_model.dart';

void main() {
  final model = NaiveBayesModel.train();
  const classifier = LightTextClassifier();

  group('NaiveBayesModel｜训练与基础性质', () {
    test('训练集规模与先验', () {
      expect(model.positiveCount, ClassifierTrainingData.actionable.length);
      expect(model.negativeCount, ClassifierTrainingData.localsOnly.length);
      expect(model.vocabularySize, greaterThan(100));
    });

    test('特征抽取：字符 n-gram + 数字标记，且去掉标点空白', () {
      final a = NaiveBayesModel.featuresOf('明天开会。');
      final b = NaiveBayesModel.featuresOf(' 明天开会 ');
      expect(a.toSet(), b.toSet(), reason: '标点/空白不该影响特征');
      // n-gram 带长度前缀：一元 `1明` / 二元 `2明天` / 三元 `3明天开`
      expect(a.contains('1明'), isTrue);
      expect(a.contains('2明天'), isTrue);
      expect(a.contains('3明天开'), isTrue);
      expect(NaiveBayesModel.featuresOf('下午3点').any((f) => f == 'D数字'), isTrue);
      expect(NaiveBayesModel.featuresOf('   '), isEmpty);
    });

    test('概率在 0..1，且正类文本普遍高于负类文本', () {
      final pos = model.classify('明天下午三点跟客户开会讨论报价').probability;
      final neg = model.classify('今天心情不错').probability;
      expect(pos, inInclusiveRange(0, 1));
      expect(neg, inInclusiveRange(0, 1));
      expect(pos, greaterThan(neg));
    });

    test('可解释：给出贡献最大的特征与方向', () {
      final r = model.classify('明天下午三点跟客户开会讨论报价');
      expect(r.topContributors, isNotEmpty);
      expect(r.topContributors.first.feature.trim(), isNotEmpty);
      expect(r.topContributors.first.weight, greaterThan(0));
    });
  });

  group('LightTextClassifier｜兜底判定（含规则引擎覆盖不到的表达）', () {
    test('"老王那事儿别忘了" 这类无时间词待办 → 能兜回来', () {
      // 规则引擎只给 +2（待办词），不到 3 分；分类器应认为值得处理
      expect(classifier.score('老王那事儿别忘了').value, greaterThan(0.4));
      expect(classifier.shouldEscalate('老王那事儿别忘了'), isTrue);
    });

    test('闲聊/寒暄 → 留在本地', () {
      for (final t in ['你好', '在吗', '哈哈', '收到', '晚安']) {
        expect(
          classifier.shouldEscalate(t),
          isFalse,
          reason: '「$t」不该送 AI',
        );
      }
    });

    test('情绪/随手记 → 留在本地', () {
      for (final t in ['今天心情不错', '有点累', '楼下那只猫又来了', '路上堵车了']) {
        expect(
          classifier.shouldEscalate(t),
          isFalse,
          reason: '「$t」不该送 AI',
        );
      }
    });

    test('成篇内容 → 认为值得整理', () {
      const text =
          '这次复盘的结论是流程上要加一道校验，另外沟通节奏也要调整，'
          '总体方向没问题但执行需要更细的拆解';
      expect(classifier.shouldEscalate(text), isTrue);
    });

    test('时间/日程类 → 认为值得处理', () {
      for (final t in ['明天下午三点跟客户开会', '周五之前把钱打过去', '下周三要约见张总']) {
        expect(classifier.shouldEscalate(t), isTrue, reason: t);
      }
    });

    test('空输入安全', () {
      expect(classifier.score('').value, 0);
      expect(classifier.shouldEscalate('   '), isFalse);
    });

    test('训练集自检：绝大多数标注样本能被自己判对（防止标注互相矛盾）', () {
      var posOk = 0;
      for (final s in ClassifierTrainingData.actionable) {
        if (classifier.shouldEscalate(s)) posOk++;
      }
      var negOk = 0;
      for (final s in ClassifierTrainingData.localsOnly) {
        if (!classifier.shouldEscalate(s)) negOk++;
      }
      final posRate = posOk / ClassifierTrainingData.actionable.length;
      final negRate = negOk / ClassifierTrainingData.localsOnly.length;
      expect(posRate, greaterThan(0.7), reason: '正样本召回率过低：$posRate');
      expect(negRate, greaterThan(0.85), reason: '负样本准确率过低：$negRate');
    });
  });
}
