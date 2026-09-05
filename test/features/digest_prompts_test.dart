import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/digest/digest_prompts.dart';
import 'package:moodiary/features/ai/digest/digest_service.dart';

void main() {
  group('DigestPrompts', () {
    test('每日包含记录清单与要点', () {
      final p = DigestPrompts.build(
        DigestPeriod.daily,
        '09-06',
        const [
          DigestItem(title: '客户跟进', summary: '谈了报价', tags: ['客户']),
        ],
      );
      expect(p, contains('每日回顾'));
      expect(p, contains('客户跟进'));
      expect(p, contains('#客户'));
      expect(p, contains('下一步'));
    });
    test('空记录有兜底文案', () {
      final p = DigestPrompts.build(DigestPeriod.weekly, '2026 第36周', const []);
      expect(p, contains('暂无记录'));
      expect(p, contains('每周总结'));
    });
    test('DigestService 每日范围覆盖当天', () {
      final now = DateTime(2026, 9, 6, 12);
      final r = DigestService.range(DigestPeriod.daily, now);
      expect(r.start, DateTime(2026, 9, 6));
      expect(r.end, DateTime(2026, 9, 7));
    });
  });
}
