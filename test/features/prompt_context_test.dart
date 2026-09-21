import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/memory/prompt_context.dart';

/// 锁定"AI 上下文组装"的契约（批次 121），全部对着**生产代码** [PromptContext] 断言，
/// 不复制逻辑——这样以后谁改了组装顺序，这里会立刻失败。
void main() {
  group('PromptContext.buildForNote｜详情页交流', () {
    test('同时带：全局记忆 + 当前笔记正文（并标明对话对象）', () {
      final system = PromptContext.buildForNote(
        memorySection: '## 用户偏好（请在表达中照顾）\n- 专业词库：膜池',
        noteText: '今天和客户聊了报价，下周三给方案。',
      );
      expect(system, contains('膜池'), reason: '全局画像必须进上下文');
      expect(system, contains('当前笔记（本次对话的对象）'), reason: '要标明对话对象');
      expect(system, contains('下周三给方案'), reason: '笔记正文必须在');
      expect(system, contains(PromptContext.memoryGuidance), reason: '要求不要复述画像');
    });

    test('记忆为空时也能工作（不得因此报错或塞入空段）', () {
      final system = PromptContext.buildForNote(
        memorySection: '   ',
        noteText: '随手记一笔',
      );
      expect(system, contains('随手记一笔'));
      expect(system.contains('用户偏好'), isFalse);
      expect(system.contains(PromptContext.memoryGuidance), isFalse);
    });

    test('笔记为空时不出现空的对象段', () {
      final system = PromptContext.buildForNote(
        memorySection: '## 长期记忆\n- 常驻上海',
        noteText: '  ',
      );
      expect(system.contains('当前笔记'), isFalse);
      expect(system, contains('常驻上海'));
    });

    test('顺序：人格 → 记忆 → 笔记 → 附加资料（越靠后注意力越强）', () {
      final system = PromptContext.buildForNote(
        memorySection: '## 长期记忆\n- 常驻上海',
        noteText: '笔记正文',
        attachments: const ['参考资料 A'],
      );
      final iPersona = system.indexOf(PromptContext.notePersona);
      final iMemory = system.indexOf('常驻上海');
      final iNote = system.indexOf('笔记正文');
      final iAttach = system.indexOf('参考资料 A');
      expect(iPersona, 0);
      expect(iMemory, greaterThan(iPersona));
      expect(iNote, greaterThan(iMemory));
      expect(iAttach, greaterThan(iNote));
    });

    test('多条附加资料按序号列出', () {
      final system = PromptContext.buildForNote(
        memorySection: '',
        noteText: '笔记',
        attachments: const ['甲', '乙'],
      );
      expect(system, contains('[资料 1]\n甲'));
      expect(system, contains('[资料 2]\n乙'));
    });
  });

  group('PromptContext.build｜通用助手工', () {
    test('AI 页与详情页用**同一份**记忆文本，只是拼装位置不同', () {
      const memory = '## 用户偏好（请在表达中照顾）\n- 风格偏好：先结论后论据';
      final home = PromptContext.build(memorySection: memory);
      final detail = PromptContext.buildForNote(
        memorySection: memory,
        noteText: '笔记',
      );
      expect(home, contains(memory));
      expect(detail, contains(memory));
      // 两个入口的人格不同，但记忆块原样一致
      expect(home, contains(PromptContext.defaultPersona));
      expect(detail, contains(PromptContext.notePersona));
    });

    test('extraSections 排在记忆之后（RAG/联网结果）', () {
      final system = PromptContext.build(
        memorySection: '## 长期记忆\n- 常驻上海',
        extraSections: const ['请优先依据「参考内容」回答：…片段…'],
      );
      expect(
        system.indexOf('参考内容'),
        greaterThan(system.indexOf('常驻上海')),
      );
    });

    test('自定义人格可覆盖', () {
      final system = PromptContext.build(
        persona: '你是笔记整理助手，用中文输出。',
        memorySection: '',
      );
      expect(system, contains('笔记整理助手'));
      expect(system.contains(PromptContext.defaultPersona), isFalse);
    });
  });

  group('PromptContext.readNoteText｜正文取值与截断', () {
    test('优先用日记投影文本', () {
      final text = PromptContext.readNoteText(
        projection: '投影文本',
        blocks: const [(content: '块文本', isAi: false, isDeleted: false)],
      );
      expect(text, '投影文本');
    });

    test('投影为空时退回来源块拼接，并**排除 AI 卡片**', () {
      final text = PromptContext.readNoteText(
        projection: '',
        blocks: const [
          (content: '用户写的内容', isAi: false, isDeleted: false),
          (content: 'AI 生成的卡片', isAi: true, isDeleted: false),
          (content: '已删除的内容', isAi: false, isDeleted: true),
        ],
      );
      expect(text, contains('用户写的内容'));
      expect(text.contains('AI 生成的卡片'), isFalse, reason: '不能把本轮对话塞回上下文');
      expect(text.contains('已删除的内容'), isFalse);
    });

    test('超长正文做头尾截断并标注省略字数', () {
      final long = 'A' * 10000;
      final clipped = PromptContext.clipNoteText(long);
      expect(clipped.length, lessThan(long.length));
      expect(clipped, contains('中间省略'));
      expect(clipped.startsWith('AAAA'), isTrue);
      expect(clipped.endsWith('AAAA'), isTrue);
    });

    test('未超长时原样返回', () {
      const short = '短文本';
      expect(PromptContext.clipNoteText(short), short);
    });
  });
}
