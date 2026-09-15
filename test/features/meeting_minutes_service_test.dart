import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/voice/meeting_minutes_service.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

void main() {
  group('MeetingMinutesPrompts', () {
    test('提示词包含转写原文与反编造约束', () {
      final prompt = MeetingMinutesPrompts.build('明天十点给李总回电');
      expect(prompt, contains('明天十点给李总回电'));
      expect(prompt, contains('不要编造'));
      expect(prompt, contains('decisions'));
      expect(prompt, contains('actions'));
    });

    test('画像段落按需注入', () {
      expect(
        MeetingMinutesPrompts.build('内容', profileSection: '常用表达：简洁'),
        contains('常用表达：简洁'),
      );
      expect(MeetingMinutesPrompts.build('内容'), isNot(contains('常用表达')));
    });
  });

  group('MeetingMinutesResult.tryParse', () {
    test('解析标准 JSON', () {
      final result = MeetingMinutesResult.tryParse('''
{"title":"菲律宾项目推进","summary":"确认了报价与交期。",
 "decisions":["本周内出报价单"],"actions":["张经理周五前发报价单","李总确认项目进度"],
 "body":"## 议题\\n- 报价与交期"}
''')!;
      expect(result.title, '菲律宾项目推进');
      expect(result.summary, '确认了报价与交期。');
      expect(result.decisions, ['本周内出报价单']);
      expect(result.actions, hasLength(2));
      expect(result.body, contains('报价与交期'));
    });

    test('容错 ```json 围栏与 minutes 字段名', () {
      final result = MeetingMinutesResult.tryParse('''
```json
{"title":"","summary":"整段摘要","minutes":"正文内容"}
```
''')!;
      expect(result.title, '整段摘要');
      expect(result.body, '正文内容');
    });

    test('非 JSON 输出按纯文本兜底，不丢内容', () {
      final result = MeetingMinutesResult.tryParse(
        '# 会议纪要\n讨论了报价与交期。',
      )!;
      expect(result.title, '会议纪要');
      expect(result.body, contains('讨论了报价与交期'));
    });

    test('空输出 / 无有效字段 → null', () {
      expect(MeetingMinutesResult.tryParse('   '), isNull);
      expect(MeetingMinutesResult.tryParse('{"title":"","summary":"","body":""}'),
          isNull);
    });
  });

  group('MeetingMinutesResult.toMarkdown', () {
    test('只渲染有内容的小节，待办用复选框', () {
      const result = MeetingMinutesResult(
        title: '标题',
        summary: '摘要内容',
        decisions: ['决定一'],
        actions: ['行动一'],
        body: '正文',
      );
      final markdown = result.toMarkdown();
      expect(markdown, contains('## 摘要\n摘要内容'));
      expect(markdown, contains('## 决定\n- 决定一'));
      expect(markdown, contains('## 待办\n- [ ] 行动一'));
      expect(markdown, contains('## 纪要\n正文'));
    });

    test('正文标题降一级，不与纪要小节同级', () {
      const result = MeetingMinutesResult(
        title: '标题',
        body: '## 议题\n- 报价与交期\n# 大标题',
      );
      final markdown = result.toMarkdown();
      expect(markdown, contains('## 纪要\n### 议题'));
      expect(markdown, contains('## 大标题'));
      expect(markdown, isNot(contains('\n## 议题')));
    });

    test('空小节不输出标题', () {
      const result = MeetingMinutesResult(title: '标题', summary: '只有摘要');
      final markdown = result.toMarkdown();
      expect(markdown, '## 摘要\n只有摘要');
      expect(markdown, isNot(contains('## 决定')));
      expect(markdown, isNot(contains('## 待办')));
    });
  });

  group('MeetingMinutesService.saveAsAiBlock', () {
    late AppDatabase db;

    setUp(() => db = openTestDb());
    tearDown(() => closeTestDb(db));

    test('写入 AI 生成区：source=ai、aiTemplate=minutes、排序在末尾', () async {
      final diary = Diary()
        ..title = '会议'
        ..content = '转写原文'
        ..contentText = '转写原文'
        ..type = 'markdown';
      await IsarUtil.insertADiary(diary);
      await IsarUtil.insertBlock(
        Block()
          ..diaryId = diary.id
          ..blockType = BlockType.text
          ..content = '转写原文'
          ..sortOrder = 0,
      );

      final block = await MeetingMinutesService.saveAsAiBlock(
        diaryId: diary.id,
        minutes: const MeetingMinutesResult(
          title: '项目对齐',
          summary: '确认报价与交期',
          actions: ['周五前发报价单'],
        ),
        sourceContent: '转写原文',
      );

      expect(block, isNotNull);
      expect(block!.meta.isAi, isTrue);
      expect(block.meta.aiTemplate, MeetingMinutesService.templateId);
      expect(block.meta.title, '项目对齐');
      expect(block.meta.captureType, 'meeting');
      expect(block.meta.sourceContent, '转写原文');
      expect(block.sortOrder, 1);
      expect(block.content, contains('- [ ] 周五前发报价单'));

      final all = await IsarUtil.getBlocksByDiary(diary.id);
      expect(all, hasLength(2));
      // 原文块保持不动
      expect(all.firstWhere((b) => b.sortOrder == 0).content, '转写原文');
    });

    test('空纪要（无任何小节）不落块', () async {
      final block = await MeetingMinutesService.saveAsAiBlock(
        diaryId: 'no-such-diary',
        minutes: const MeetingMinutesResult(title: '空'),
      );
      expect(block, isNull);
    });
  });
}
