import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/triage/segment_extractor.dart';

void main() {
  group('SegmentExtractor｜只送相关片段', () {
    test('长笔记只保留含信号句子 + 前后各一句上下文', () {
      const text =
          '下午跟团队复盘了这个季度的进展。'
          '整体方向没有问题，节奏也在预期内。'
          '明天下午3点要跟客户开会对报价。'
          '另外我最近睡眠不好，有点焦虑，这件事我只跟自己说。'
          '想去爬山放松一下，但还没决定去哪里，也还没跟任何人提过。'
          '最近在看一本关于睡眠的书，做了不少笔记但没什么结论。'
          '对了，记得把合同扫描件发给法务。';
      final r = SegmentExtractor.extract(text);
      expect(r.trimmed, isTrue, reason: '应该截取而不是全文发送');
      expect(r.matchedCount, greaterThanOrEqualTo(2));
      // 含信号的句子必须在
      expect(r.relevant, contains('明天下午3点要跟客户开会'));
      expect(r.relevant, contains('记得把合同扫描件发给法务'));
      // 片段必须显著短于全文（无关内容大部分被丢掉）
      expect(r.relevant.length, lessThan(text.length * 0.9));
    });

    test('前后各留一句上下文（保留指代/因果）', () {
      const text = '第一句无关。第二句也无关。明天要交报告。第四句无关内容很长很长。';
      final r = SegmentExtractor.extract(text);
      expect(r.relevant, contains('第二句也无关'), reason: '前一句上下文');
      expect(r.relevant, contains('第四句无关内容'), reason: '后一句上下文');
      expect(r.relevant, isNot(contains('第一句无关')));
    });

    test('短文本/单句不截取（截了也不省）', () {
      const short = '明天开会';
      final r = SegmentExtractor.extract(short);
      expect(r.trimmed, isFalse);
      expect(r.relevant, short);
    });

    test('没有任何信号时返回全文（交由后续策略决定）', () {
      const text = '楼下那只猫又来了。心情挺好的。随便写点什么。';
      final r = SegmentExtractor.extract(text);
      expect(r.trimmed, isFalse);
      expect(r.relevant, text);
      expect(r.matchedCount, 0);
    });

    test('空输入安全', () {
      final r = SegmentExtractor.extract('   ');
      expect(r.relevant, '');
      expect(r.trimmed, isFalse);
      expect(r.matchedCount, 0);
    });

    test('保留的片段过短收益不足时退回全文', () {
      // 全文 3 句，其中 3 句都含信号 → 截取没有收益
      const text = '明天开会。明天交报告。明天记得打电话。';
      final r = SegmentExtractor.extract(text);
      expect(r.trimmed, isFalse, reason: '全部句子都相关时不必截取');
      expect(r.relevant, text);
    });

    test('跳过段落用省略标记，避免读起来断裂', () {
      const text =
          '明天要交季度报告给老板。'
          '第一段无关的内容，讲的是背景以及一些不重要的事情，写得比较长比较啰嗦。'
          '第二段也无关，继续啰嗦一些没有信息量的描述。'
          '第三段同样无关，只是填充内容而已。'
          '记得带上合同和发票。';
      final r = SegmentExtractor.extract(text);
      expect(r.trimmed, isTrue);
      expect(r.relevant, contains('…'), reason: '中间被跳过的段落应有省略标记');
    });

    test('splitSentences 按中英标点与换行切分', () {
      final s = SegmentExtractor.splitSentences('第一句。第二句！第三句？\n第四句');
      expect(s.length, 4);
      expect(s.first, '第一句');
    });

    test('超长片段会被截断（单段上限）', () {
      final long = '明天开会${'这是很长的补充说明' * 100}';
      final r = SegmentExtractor.extract(long);
      expect(
        r.relevant.length,
        lessThanOrEqualTo(SegmentExtractor.maxSegmentChars + 1),
      );
    });
  });
}
