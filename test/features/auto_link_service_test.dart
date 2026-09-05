import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/autolink/auto_link_service.dart';

void main() {
  group('AutoLinkService', () {
    test('按标签重叠推荐，排除自身', () {
      const all = [
        NoteSummary(id: 'a', title: '客户访谈', tags: ['客户', '销售']),
        NoteSummary(id: 'b', title: '定价思考', tags: ['产品', '定价']),
        NoteSummary(id: 'c', title: '客户报价', tags: ['客户', '合同']),
      ];
      const target = NoteSummary(
        id: 'a',
        title: '客户访谈',
        tags: ['客户', '销售'],
      );
      final r = AutoLinkService.suggest(target: target, all: all);
      expect(r.map((e) => e.diaryId), contains('c'));
      expect(r.every((e) => e.diaryId != 'a'), isTrue);
      expect(r.first.diaryId, 'c'); // 共享「客户」标签
    });
    test('无重叠不推荐', () {
      const all = [
        NoteSummary(id: 'b', title: '读书', tags: ['书']),
      ];
      const target = NoteSummary(id: 'a', title: '健身', tags: ['运动']);
      final r = AutoLinkService.suggest(target: target, all: all);
      expect(r, isEmpty);
    });
  });
}
