import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/memory/memory_files.dart';
import 'package:moodiary/features/ai/memory/memory_store.dart';
import 'package:moodiary/features/ai/memory/memory_suggestion.dart';
import 'package:moodiary/features/ai/memory/memory_suggestion_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MemorySuggestionDetector｜识别值得记的内容', () {
    test('稳定事实/偏好 → memory 建议', () {
      final s = MemorySuggestionDetector.detect(
        aiOutput:
            '根据你的记录，我注意到几个稳定特征：\n'
            '- 我常驻上海，客户主要集中在制造业\n'
            '- 我习惯先看结论再看论据\n'
            '- 我的工作节奏是周一排计划、周五复盘\n'
            '以后请都按这个前提来理解我的记录。',
        userAsk: '看看我的记录有什么规律',
      );
      expect(s, isNotNull);
      expect(s!.kind, MemorySuggestionKind.memory);
      expect(s.confidence, greaterThanOrEqualTo(
        MemorySuggestionDetector.threshold,
      ));
      expect(s.reason, contains('稳定'));
    });

    test('可复用流程（有步骤/列表）→ skill 建议', () {
      final s = MemorySuggestionDetector.detect(
        aiOutput:
            '下面是一套客户报价流程：\n\n'
            '## 步骤\n'
            '1. 第一步：确认预算与交期\n'
            '2. 然后：查成本价格库\n'
            '3. 接着：给三档方案\n'
            '4. 最后：留出议价空间\n'
            '这套模板以后遇到类似需求可以直接套。',
        userAsk: '客户报价怎么走',
      );
      expect(s, isNotNull);
      expect(s!.kind, MemorySuggestionKind.skill);
      expect(s.content, contains('## 步骤'));
    });

    test('短期/一次性内容 → 不建议', () {
      final s = MemorySuggestionDetector.detect(
        aiOutput:
            '今天你记录了三条：开会、买咖啡、修打印机。'
            '这次会议的要点是排期，昨天那条待办已经完成。',
        userAsk: '今天记了什么',
      );
      expect(s, isNull);
    });

    test('太短的回答不建议（避免骚扰）', () {
      expect(
        MemorySuggestionDetector.detect(aiOutput: '好的，记住了。'),
        isNull,
      );
      expect(MemorySuggestionDetector.detect(aiOutput: '今天记了三条待办'), isNull);
    });

    test('空输入安全', () {
      expect(MemorySuggestionDetector.detect(aiOutput: ''), isNull);
      expect(MemorySuggestionDetector.detect(aiOutput: '   '), isNull);
    });

    test('技能标题优先用用户提问（更贴近以后怎么问）', () {
      final s = MemorySuggestionDetector.detect(
        aiOutput:
            '## 步骤\n1. 第一步：确认预算\n2. 然后：查成本库\n3. 最后：出三档\n'
            '这套模板以后可以复用，流程固定。',
        userAsk: '客户报价流程',
      );
      expect(s!.title, '客户报价流程');
    });
  });

  group('MemorySuggestionService｜建议式（点了才落盘）', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('suggest_test');
      MemoryFiles.rootDirOverride = p.join(tempDir.path, 'ai-memory');
      MemoryStore.resetForTest();
      MemorySuggestionService.instance.reset();
    });

    tearDown(() {
      MemoryFiles.rootDirOverride = null;
      MemorySuggestionService.instance.reset();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('consider 只挂建议，不写文件', () async {
      MemorySuggestionService.instance.consider(
        aiOutput:
            '## 步骤\n1. 第一步：确认预算\n2. 然后：查成本库\n3. 最后：出三档方案\n'
            '这套模板以后可复用。',
        userAsk: '报价流程',
      );
      await MemoryStore.ensureDirsForTest();
      expect(MemorySuggestionService.instance.pending.value, isNotNull);
      // 关键：还没有落盘
      expect(File(p.join(MemoryFiles.skillsDir(), '报价流程.md')).existsSync(),
          isFalse);
      expect((await MemoryStore.loadSkills()), isEmpty);
    });

    test('accept → 落到技能手册，并清掉待确认', () async {
      MemorySuggestionService.instance.consider(
        aiOutput:
            '## 步骤\n1. 第一步：确认预算\n2. 然后：查成本库\n3. 最后：出三档方案\n'
            '这套模板以后可复用。',
        userAsk: '报价流程',
      );
      final msg = await MemorySuggestionService.instance.accept();
      expect(msg, contains('技能手册'));
      expect(MemorySuggestionService.instance.pending.value, isNull);
      expect((await MemoryStore.loadSkills()).keys, contains('报价流程'));
    });

    test('accept（记忆类）→ 追加到 memory.md', () async {
      MemorySuggestionService.instance.consider(
        aiOutput:
            '我常驻上海，客户多在制造业。我习惯先看结论。以后请都按这个前提理解。',
        userAsk: '我的习惯',
      );
      final msg = await MemorySuggestionService.instance.accept();
      expect(msg, contains('长期记忆'));
      expect(await MemoryStore.loadMemory(), contains('常驻上海'));
    });

    test('dismiss → 什么都不写', () async {
      MemorySuggestionService.instance.consider(
        aiOutput:
            '## 步骤\n1. 第一步：确认预算\n2. 然后：查成本库\n3. 最后：出三档方案\n'
            '这套模板以后可复用。',
        userAsk: '报价流程',
      );
      MemorySuggestionService.instance.dismiss();
      expect(MemorySuggestionService.instance.pending.value, isNull);
      await MemoryStore.ensureDirsForTest();
      expect((await MemoryStore.loadSkills()), isEmpty);
    });

    test('已有待确认建议时不覆盖（避免刷屏）', () {
      MemorySuggestionService.instance.consider(
        aiOutput:
            '我常驻上海，客户多在制造业。我习惯先看结论。以后请都按这个前提理解。',
        userAsk: '习惯',
      );
      final first = MemorySuggestionService.instance.pending.value;
      MemorySuggestionService.instance.consider(
        aiOutput:
            '## 步骤\n1. 第一步：A\n2. 然后：B\n3. 最后：C\n这套模板以后可复用。',
        userAsk: '别的流程',
      );
      expect(MemorySuggestionService.instance.pending.value, same(first));
    });
  });
}
