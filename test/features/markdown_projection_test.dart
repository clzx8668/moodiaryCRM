import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/block/markdown_projection.dart';
import 'package:moodiary/features/block/models/block.dart';

void main() {
  group('MarkdownProjection.blockToMarkdown', () {
    test('text 原样返回', () {
      final block = Block()
        ..blockType = BlockType.text
        ..content = '今天约了张三聊合同';
      expect(MarkdownProjection.blockToMarkdown(block), '今天约了张三聊合同');
    });

    test('code 包三层反引号', () {
      final block = Block()
        ..blockType = BlockType.code
        ..content = 'void main() {}';
      expect(
        MarkdownProjection.blockToMarkdown(block),
        '```\nvoid main() {}\n```',
      );
    });

    test('todo 前缀标记', () {
      final pending = Block()
        ..blockType = BlockType.todo
        ..content = '- 下周三寄出样品';
      expect(MarkdownProjection.blockToMarkdown(pending), '- [ ] 下周三寄出样品');

      final done = Block()
        ..blockType = BlockType.todo
        ..content = '[x] 已完成事项';
      expect(MarkdownProjection.blockToMarkdown(done), '- [x] 已完成事项');

      final jsonDone = Block()
        ..blockType = BlockType.todo
        ..content = '{"text":"买牛奶","done":true}';
      expect(MarkdownProjection.blockToMarkdown(jsonDone), '- [x] 买牛奶');
    });

    test('smartEntity JSON 摘要', () {
      final block = Block()
        ..blockType = BlockType.smartEntity
        ..content =
            '{"entity_type":"company","name":"张三","crm_id":"crm_123","status":"pending"}';
      expect(
        MarkdownProjection.blockToMarkdown(block),
        '**company**：张三 · pending',
      );
    });

    test('image 投影为 Markdown 图片语法', () {
      final block = Block()
        ..blockType = BlockType.image
        ..content = '2026/08/abc.jpg';
      expect(
        MarkdownProjection.blockToMarkdown(block),
        '![](2026/08/abc.jpg)',
      );
    });

    test('chart JSON 摘要', () {
      final block = Block()
        ..blockType = BlockType.chart
        ..content = '{"type":"line","data":[1,2,3]}';
      expect(MarkdownProjection.blockToMarkdown(block), '**图表**：line 3 项');
    });

    test('aiStream 完成态用 content，未完成用 streamBuffer', () {
      final streaming = Block()
        ..blockType = BlockType.aiStream
        ..content = ''
        ..streamBuffer = '已收到部分'
        ..streamComplete = false;
      expect(MarkdownProjection.blockToMarkdown(streaming), '已收到部分');

      final done = Block()
        ..blockType = BlockType.aiStream
        ..content = '完整结果'
        ..streamBuffer = '旧缓存'
        ..streamComplete = true;
      expect(MarkdownProjection.blockToMarkdown(done), '完整结果');
    });

    test('非法 JSON 容错回退原文', () {
      final block = Block()
        ..blockType = BlockType.smartEntity
        ..content = '不是 JSON';
      expect(MarkdownProjection.blockToMarkdown(block), '不是 JSON');
    });
  });

  group('MarkdownProjection.aggregate', () {
    test('按 sortOrder 拼接并跳过删除块', () {
      final b1 = Block()
        ..id = 'b1'
        ..blockType = BlockType.text
        ..content = '第一张卡'
        ..sortOrder = 1;
      final b2 = Block()
        ..id = 'b2'
        ..blockType = BlockType.todo
        ..content = '待办事项'
        ..sortOrder = 0;
      final deleted = Block()
        ..id = 'b3'
        ..blockType = BlockType.text
        ..content = '已删除'
        ..sortOrder = 2
        ..isDeleted = true;

      final result = MarkdownProjection.aggregate([b1, b2, deleted]);

      expect(result, '- [ ] 待办事项\n\n第一张卡');
    });

    test('空列表返回空串', () {
      expect(MarkdownProjection.aggregate([]), '');
    });
  });
}
