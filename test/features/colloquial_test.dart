import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/colloquial/colloquial_detector.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_meta.dart';
import 'package:moodiary/features/ai/colloquial/info_preservation.dart';
import 'package:moodiary/features/block/models/block.dart';

void main() {
  group('ColloquialDetector', () {
    test('口语明显 → shouldClean=true', () {
      final r = ColloquialDetector.analyze(
        '嗯那个就是我今天感觉有点累啊然后想休息一下',
      );
      expect(r.shouldClean, isTrue);
      expect(r.score, greaterThanOrEqualTo(ColloquialDetector.threshold));
      expect(r.reasons, isNotEmpty);
    });

    test('行动项/祈使开头 → 不处理', () {
      final r = ColloquialDetector.analyze(
        '明天下午三点和星海科技张总开个会，记得带合同',
      );
      expect(r.shouldClean, isFalse);
    });

    test('简洁陈述无口头禅 → 不处理', () {
      final r = ColloquialDetector.analyze('我今天去超市买了牛奶和鸡蛋');
      expect(r.shouldClean, isFalse);
    });

    test('过短/过长 → 不处理', () {
      expect(ColloquialDetector.analyze('啊').shouldClean, isFalse);
      expect(
        ColloquialDetector.analyze(
          '啊${List.filled(100, '然后').join()}',
        ).shouldClean,
        isFalse,
      );
    });
  });

  group('InfoPreservation', () {
    test('保留数字/电话 → ok', () {
      final r = InfoPreservation.verify(
        '明天下午3点联系13800000000，报价3000元',
        '明天下午三点联系 13800000000，报价 3000 元',
      );
      expect(r.ok, isTrue);
    });

    test('改写丢了金额 → 拒绝', () {
      final r = InfoPreservation.verify(
        '报价3000元',
        '报价便宜一点',
      );
      expect(r.ok, isFalse);
      expect(r.lost, contains('3000'));
    });

    test('空原文 → 通过', () {
      expect(InfoPreservation.verify('', 'x').ok, isTrue);
    });
  });

  group('DeColoquialMeta', () {
    test('读写/清除 metaJson 不丢其它键', () {
      final block = Block()..id = 'b1';
      // 预置一个无关键
      block.metaJson = '{"source":"initial","entityType":"account"}';
      DeColoquialMeta.write(
        block,
        const DeColoquialMeta(original: '原', cleaned: '清', ts: 1),
      );
      expect(DeColoquialMeta.has(block), isTrue);
      final meta = DeColoquialMeta.read(block)!;
      expect(meta.original, '原');
      expect(meta.cleaned, '清');
      // 其它键仍在
      expect(block.metaJson, contains('"entityType":"account"'));

      DeColoquialMeta.clear(block);
      expect(DeColoquialMeta.has(block), isFalse);
      expect(block.metaJson, contains('"source":"initial"'));
    });

    test('脏 metaJson 容错为空', () {
      final block = Block()..metaJson = 'not-json';
      expect(DeColoquialMeta.has(block), isFalse);
    });
  });
}
