import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/triage/signal_scorer.dart';
import 'package:moodiary/features/ai/triage/time_signals.dart';

void main() {
  group('TimeSignals｜时间表达识别（最强信号）', () {
    test('相对日期', () {
      for (final t in ['今天', '明天', '后天', '大后天', '今晚', '明晚']) {
        expect(TimeSignals.has('我们$t要做这件事'), isTrue, reason: t);
      }
    });

    test('星期表达', () {
      for (final t in ['周一', '周三', '星期日', '下周一', '下下周三', '礼拜二']) {
        expect(TimeSignals.has('安排到$t'), isTrue, reason: t);
      }
    });

    test('绝对日期', () {
      for (final t in ['3月5日', '3月5号', '5日', '5号', '2026-03-05', '3/5']) {
        expect(TimeSignals.has('定在$t'), isTrue, reason: t);
      }
    });

    test('具体时刻', () {
      for (final t in ['15:30', '15：30', '下午3点', '晚上八点半', '6点半', '3点前']) {
        expect(TimeSignals.has('会议$t'), isTrue, reason: t);
      }
    });

    test('时间范围/紧迫词', () {
      for (final t in ['三天内', '一周后', '月底前', '下个月', '尽快', '周末']) {
        expect(TimeSignals.has('$t处理掉'), isTrue, reason: t);
      }
    });

    test('普通文本不误报', () {
      expect(TimeSignals.has('今天天气不错'), isTrue, reason: '今天也算时间词');
      expect(
        SignalScorer.score('今天天气不错').shouldEscalate,
        isFalse,
        reason: '只有"今天"这种低特异性时间词不该送 AI',
      );
      expect(TimeSignals.has('这个方案我觉得可以'), isFalse);
      expect(TimeSignals.has('记录了三个想法'), isFalse);
    });

    test('find 返回命中的原文片段（去重）', () {
      final hits = TimeSignals.find('明天下午3点开会，明天记得带电脑');
      expect(hits, isNotEmpty);
      expect(hits.any((h) => h.contains('明天')), isTrue);
      expect(hits.any((h) => h.contains('3点')), isTrue);
      // 去重
      expect(hits.where((h) => h == '明天').length, lessThanOrEqualTo(1));
    });
  });

  group('SignalScorer｜打分机制', () {
    test('权重：时间 +3、待办 +2、日程 +2', () {
      // 只命中时间 → +3；短文本还有 -1，所以用长一点的句子看纯权重
      final timeOnly = SignalScorer.score('明天上午十点在办公室');
      expect(SignalScorer.score('明天上午十点在办公室').hits.first.delta, 3);
      expect(timeOnly.total, 3);
      expect(timeOnly.shouldEscalate, isTrue);

      // 只命中待办词 → 2 分，不达标
      final todoOnly = SignalScorer.score('记得带电脑过来');
      expect(todoOnly.total, 2);
      expect(todoOnly.shouldEscalate, isFalse);

      // 只命中日程词 → 2 分，不达标
      final scheduleOnly = SignalScorer.score('跟他约一下见面');
      expect(scheduleOnly.total, 2);
      expect(scheduleOnly.shouldEscalate, isFalse);
    });

    test('待办 + 日程 = 4 分 → 达标（即使没有时间词）', () {
      final s = SignalScorer.score('记得跟老王约一下见面的事');
      expect(s.total, greaterThanOrEqualTo(4));
      expect(s.shouldEscalate, isTrue);
    });

    test('闲聊特征 -1：句尾语气词/问号', () {
      final withTime = SignalScorer.score('明天开会').total;
      final chatty = SignalScorer.score('明天开会吗').total;
      expect(chatty, withTime - 1);
      expect(SignalScorer.score('你在干嘛呢').total, lessThan(0));
      expect(SignalScorer.score('这个怎么弄？').total, lessThan(0));
    });

    test('太短 -1：<8 字', () {
      // 4 字 + 无信号 → -1
      expect(SignalScorer.score('随便写写').total, -1);
      // 6 字及以上不再扣分
      expect(SignalScorer.score('随便写写看看').hits.any(
        (h) => h.kind == SignalKind.tooShort,
      ), isFalse);
      // 时间词 +3，但 2 字要扣 1 → 净 2 分，不够阈值
      expect(SignalScorer.score('明天').total, 2);
      expect(SignalScorer.score('明天').shouldEscalate, isFalse);
      // 同样带时间，长一些的句子（时间 +3、日程 +2）达到 5 分
      expect(SignalScorer.score('明天我要去上海出差开会').total, 5);
    });

    test('测试占位内容重罚 -3', () {
      expect(SignalScorer.score('测试').total, lessThan(0));
      expect(SignalScorer.score('test').total, lessThan(0));
    });

    test('阈值 3：典型笔记的走向符合预期', () {
      // 普通日记：本地
      expect(SignalScorer.shouldEscalate('今天心情不错，看了会儿书'), isFalse);
      // 带时间的随手记：送 AI
      expect(SignalScorer.shouldEscalate('明天下午3点开会'), isTrue);
      // 待办+时间：送 AI
      expect(SignalScorer.shouldEscalate('明天记得把报告交了'), isTrue);
      // 只有"记得"（2 分）：本地 —— 这正是"挡掉 80~90% 普通笔记"的效果
      expect(SignalScorer.shouldEscalate('记得买牛奶回来'), isFalse);
    });

    test('explanation 可读（给用户看"为什么"）', () {
      final s = SignalScorer.score('明天记得把报告交了');
      expect(s.explanation, contains('时间'));
      expect(s.explanation, contains('待办'));
      expect(s.explanation, contains('+'));
    });
  });
}
