import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/asr/cn_punctuator.dart';

void main() {
  group('CnPunctuator（端侧转写的本地标点）', () {
    test('finish：没有标点的长句会断句并补句号', () {
      const raw = '对我做了介绍啊那么我想说的是呢大家如果对我的研究感兴趣呢';
      final out = CnPunctuator.finish(raw);
      expect(
        out.endsWith('。') || out.endsWith('？'),
        isTrue,
        reason: '结尾必须有句末标点',
      );
      expect(
        RegExp(r'[。？]').allMatches(out).length,
        greaterThanOrEqualTo(2),
        reason: '语气词处应该断句',
      );
      // 断句后每段不该太长，否则等于没断
      final longest = out
          .split(RegExp(r'[。？]'))
          .map((s) => s.length)
          .fold<int>(0, (a, b) => a > b ? a : b);
      expect(longest, lessThanOrEqualTo(26));
      // 不该出现连续标点
      expect(RegExp(r'[，。？！]{2,}').hasMatch(out), isFalse);
    });

    test('finish：疑问词结尾补问号', () {
      expect(CnPunctuator.finish('你明天来吗'), '你明天来吗？');
      expect(CnPunctuator.finish('这个到底怎么回事'), endsWith('？'));
    });

    test('finish：删掉句首口语填充词，不删句中的', () {
      expect(CnPunctuator.finish('嗯，我叫张三'), '我叫张三。');
      expect(CnPunctuator.finish('呃那个我想约时间'), '我想约时间。');
      // 句中的"那个"是正常用词，必须保留
      expect(CnPunctuator.finish('把那个文件发我'), contains('那个文件'));
    });

    test('finish：英文/数字不影响断句长度统计', () {
      final out = CnPunctuator.finish('版本号v1 2 3已经发布了请大家更新');
      expect(out.endsWith('。'), isTrue);
    });

    test('join：短句之间用逗号，长句之间用句号', () {
      final short = CnPunctuator.join('我们讨论一下', '再决定');
      expect(short, contains('，'));

      final long = CnPunctuator.join(
        '这个方案的总体收益已经比较清楚了',
        '但是如果成本下不来就很难推进',
      );
      expect(long.contains('。') || long.contains('，'), isTrue);
      expect(RegExp(r'[，。]{2,}').hasMatch(long), isFalse);
    });

    test('join：新句以连接词开头时，前面断开用句号', () {
      final out = CnPunctuator.join('先看第一部分内容', '然后我们再看第二部分');
      expect(out.startsWith('先看第一部分内容。'), isTrue);
    });

    test('join：不会产生重复标点', () {
      final out = CnPunctuator.join('你好。', '今天天气不错');
      expect(out.contains('。。'), isFalse);
      expect(out.contains('。，'), isFalse);
    });

    test('幂等：对同一段文本重复处理不叠加标点', () {
      const raw = '嗯我明天上午过去找你';
      final once = CnPunctuator.finish(raw);
      final twice = CnPunctuator.finish(once);
      expect(twice, once);
    });

    test('空输入安全', () {
      expect(CnPunctuator.finish(''), '');
      expect(CnPunctuator.finish('   '), '');
      expect(CnPunctuator.join('', ''), '');
      expect(CnPunctuator.join('已有内容', ''), '已有内容');
    });

    test('绝不过长：一段超过阈值会强制断句', () {
      final raw = '这是一个很长的句子' * 6; // 60 字，无任何语气词
      final out = CnPunctuator.finish(raw);
      expect('。'.allMatches(out).length, greaterThan(1));
    });
  });
}
