import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_meta.dart';
import 'package:moodiary/features/ai/extract/extract_plan_service.dart';
import 'package:moodiary/features/block/models/block.dart';

void main() {
  Block textBlock(String content) => Block()
    ..diaryId = 'd1'
    ..blockType = BlockType.text
    ..content = content;

  group('抽取源文本（保证与去口语化的执行顺序无关）', () {
    test('没有去口语化记录 → 用卡片正文', () {
      final block = textBlock('明天上午十点给李总回电话');
      expect(ExtractPlanService.sourceTextOf(block), '明天上午十点给李总回电话');
    });

    test('已去口语化 → 用保留下来的原文（而不是清洗稿）', () {
      // 清洗可能抹掉"明天""十点"这类时间线索，抽取必须基于原文
      final block = textBlock('明早十点给李总回电话。');
      DeColoquialMeta.write(
        block,
        const DeColoquialMeta(
          original: '嗯那个就是明早十点给李总回个电话吧',
          cleaned: '明早十点给李总回电话。',
        ),
      );
      expect(ExtractPlanService.sourceTextOf(block), '嗯那个就是明早十点给李总回个电话吧');
    });

    test('原文为空（历史脏数据）→ 回退卡片正文', () {
      final block = textBlock('正文兜底');
      DeColoquialMeta.write(
        block,
        const DeColoquialMeta(original: '   ', cleaned: '正文兜底'),
      );
      expect(ExtractPlanService.sourceTextOf(block), '正文兜底');
    });
  });
}
