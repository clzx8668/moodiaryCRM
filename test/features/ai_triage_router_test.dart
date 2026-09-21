import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/triage/ai_triage_router.dart';
import 'package:moodiary/features/ai/triage/triage_config.dart';
import 'package:moodiary/features/ai/triage/triage_types.dart';

void main() {
  const router = AiTriageRouter();

  TriageResult route(
    String text,
    List<TriageOperation> ops, {
    TriageConfig config = const TriageConfig(),
    Set<TriageOperation> explicit = const {},
    String? extra,
  }) => router.route(
    text: text,
    operations: ops,
    config: config,
    explicitUserIntent: explicit,
    extraSensitiveText: extra,
  );

  group('第一级：规则命中 → 送 AI', () {
    test('含待办/时间线索 → extractPlan 送 AI', () {
      final r = route('明天下午3点前把报价发给客户', [TriageOperation.extractPlan]);
      expect(r.decisions[TriageOperation.extractPlan]!.shouldSendToAI, isTrue);
      expect(r.decisions[TriageOperation.extractPlan]!.reason, contains('结构化信号'));
    });

    test('含主题词 → 打标签送 AI', () {
      final r = route('这个版本要加一个新的收藏功能，顺便修两个 bug', [
        TriageOperation.autoTag,
      ]);
      expect(r.decisions[TriageOperation.autoTag]!.shouldSendToAI, isTrue);
    });

    test('长内容 → 摘要送 AI', () {
      final long = '今天的复盘：${'我们把整个采集链路重新梳理了一遍，' * 5}';
      final r = route(long, [TriageOperation.autoSummary]);
      expect(r.decisions[TriageOperation.autoSummary]!.shouldSendToAI, isTrue);
    });
  });

  group('第一级：规则判定"不值得" → 留在本地', () {
    test('空内容/纯符号一律本地', () {
      for (final t in ['', '。。。', '123']) {
        final r = route(t, [TriageOperation.autoTag]);
        expect(
          r.decisions[TriageOperation.autoTag]!.action,
          TriageAction.keepLocal,
          reason: '「$t」不该送 AI',
        );
      }
    });

    test('测试占位内容不打标签', () {
      final r = route('test', [TriageOperation.autoTag]);
      final d = r.decisions[TriageOperation.autoTag]!;
      expect(d.action, TriageAction.keepLocal);
      expect(d.reason, contains('测试'));
    });

    test('私人情绪记录：不做摘要、不抽待办', () {
      final r = route('今天心情有点低落，什么都不想做', [
        TriageOperation.autoSummary,
        TriageOperation.extractPlan,
      ]);
      expect(r.decisions[TriageOperation.autoSummary]!.staysLocal, isTrue);
      expect(r.decisions[TriageOperation.extractPlan]!.staysLocal, isTrue);
      expect(r.fullyLocal, isTrue);
    });

    test('本地可完成的操作（向量索引）永不上云', () {
      final r = route('明天开会', [TriageOperation.embedding]);
      expect(r.decisions[TriageOperation.embedding]!.action,
          TriageAction.keepLocal);
    });

    test('设置里关掉的操作 → 本地', () {
      final r = route(
        '明天下午3点前把报价发给客户',
        [TriageOperation.autoTag, TriageOperation.extractPlan],
        config: const TriageConfig(
          disabledOperations: {TriageOperation.autoTag},
        ),
      );
      expect(r.decisions[TriageOperation.autoTag]!.action,
          TriageAction.keepLocal);
      expect(r.decisions[TriageOperation.extractPlan]!.shouldSendToAI, isTrue);
    });
  });

  group('隐私闸门：敏感信息默认不上云', () {
    test('含手机号 → 敏感操作落本地，并给出理由', () {
      final r = route('明天下午3点给客户 13812345678 回电话', [
        TriageOperation.extractPlan,
      ]);
      final d = r.decisions[TriageOperation.extractPlan]!;
      expect(d.action, TriageAction.sensitiveLocalOnly);
      expect(d.reason, contains('敏感'));
      expect(r.hasSensitive, isTrue);
      expect(r.sensitiveKinds, contains('手机号'));
      expect(r.fullyLocal, isTrue);
    });

    test('敏感信息在"附带内容"里也能拦到（链接正文/图片 OCR）', () {
      final r = route(
        '看这个链接',
        [TriageOperation.autoTag],
        extra: '身份证号 11010119900307617X',
      );
      expect(r.hasSensitive, isTrue);
      expect(r.decisions[TriageOperation.autoTag]!.staysLocal, isTrue);
    });

    test('用户显式开允许后，敏感内容才放行', () {
      final r = route(
        '明天下午3点给客户 13812345678 回电话',
        [TriageOperation.extractPlan],
        config: const TriageConfig(allowSensitiveToCloud: true),
      );
      expect(r.decisions[TriageOperation.extractPlan]!.shouldSendToAI, isTrue);
    });

    test('显式用户意图也不能绕过隐私闸门', () {
      final r = route(
        '客户 13812345678 的报价明天发',
        [TriageOperation.extractPlan],
        explicit: {TriageOperation.extractPlan},
      );
      expect(r.decisions[TriageOperation.extractPlan]!.action,
          TriageAction.sensitiveLocalOnly);
    });
  });

  group('第二级：本地轻量分类器兜底', () {
    test('规则未命中但内容成篇 → 分类器放行', () {
      // 无待办/主题信号词，但很长且有结构
      const text = '这段时间我一直在想一个问题。'
          '它没有一个明确的名字。'
          '我只是觉得它反复出现。'
          '也许它值得被写下来。';
      final r = route(text, [TriageOperation.autoSummary]);
      final d = r.decisions[TriageOperation.autoSummary]!;
      expect(r.usedClassifier, isTrue);
      expect(d.shouldSendToAI, isTrue, reason: '分类器应认为值得处理');
      expect(d.fromClassifier, isTrue);
    });

    test('规则未命中且信息量不足 → 分类器也拦下（留在本地）', () {
      final r = route('看到了', [TriageOperation.autoTag]);
      final d = r.decisions[TriageOperation.autoTag]!;
      // 长度不足是规则直接拦，不会走到分类器；这里验证结果是本地
      expect(d.staysLocal, isTrue);
    });

    test('保守档：规则未命中一律本地，不走分类器', () {
      const text = '这段时间我一直在想一个问题。它没有名字。'
          '我只是觉得它反复出现。也许值得写下来。';
      final r = route(
        text,
        [TriageOperation.autoSummary],
        config: const TriageConfig(level: TriageLevel.conservative),
      );
      expect(r.usedClassifier, isFalse);
      expect(r.decisions[TriageOperation.autoSummary]!.staysLocal, isTrue);
    });

    test('激进档：规则未命中直接放行', () {
      final r = route(
        '看到了',
        [TriageOperation.autoTag],
        config: const TriageConfig(level: TriageLevel.aggressive),
      );
      // 内容过短仍被规则挡住（连激进档也不该为空内容花额度）
      expect(r.decisions[TriageOperation.autoTag]!.staysLocal, isTrue);
    });
  });

  group('额度闸门', () {
    test('额度用完 → 全部转本地，并说明原因', () {
      final r = route(
        '明天下午3点前把报价发给客户',
        [TriageOperation.extractPlan],
        config: const TriageConfig(
          quota: TriageQuota(monthlyLimit: 10, usedThisMonth: 10, month: '2026-09'),
        ),
      );
      final d = r.decisions[TriageOperation.extractPlan]!;
      expect(d.staysLocal, isTrue);
      expect(d.reason, contains('额度'));
    });

    test('用户显式选择模板优先于额度（他自己点的，照做）', () {
      final r = route(
        '明天下午3点前把报价发给客户',
        [TriageOperation.extractPlan],
        config: const TriageConfig(
          quota: TriageQuota(monthlyLimit: 1, usedThisMonth: 1, month: '2026-09'),
        ),
        explicit: {TriageOperation.extractPlan},
      );
      expect(r.decisions[TriageOperation.extractPlan]!.shouldSendToAI, isTrue);
    });
  });

  group('汇总信息', () {
    test('summary / sendOperations / localOperations 正确', () {
      final r = route('明天下午3点前把报价发给客户', [
        TriageOperation.extractPlan,
        TriageOperation.autoTag,
        TriageOperation.embedding,
      ]);
      expect(r.sendOperations, contains(TriageOperation.extractPlan));
      expect(r.localOperations, contains(TriageOperation.embedding));
      expect(r.fullyLocal, isFalse);
      expect(r.summary, contains('送 AI'));
    });

    test('全本地时摘要说明不上云', () {
      final r = route('看到', [TriageOperation.autoTag]);
      expect(r.fullyLocal, isTrue);
      expect(r.summary, contains('本地'));
    });

    test('无候选操作时安全返回', () {
      final r = route('明天开会', const []);
      expect(r.decisions, isEmpty);
      expect(r.summary, '无需 AI 处理');
    });
  });
}
