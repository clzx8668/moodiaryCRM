import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/block/delta_to_markdown.dart';

void main() {
  test('纯文本', () {
    expect(
      DeltaToMarkdown.convert('[{"insert":"你好世界\\n"}]'),
      '你好世界',
    );
  });

  test('加粗/斜体/删除线/链接', () {
    final delta = jsonEncode([
      {'insert': '重点', 'attributes': {'bold': true}},
      {'insert': ' '},
      {'insert': '斜体', 'attributes': {'italic': true}},
      {'insert': ' '},
      {'insert': '删除', 'attributes': {'strike': true}},
      {'insert': ' '},
      {'insert': '链接', 'attributes': {'link': 'https://example.com'}},
      {'insert': '\n'},
    ]);
    expect(
      DeltaToMarkdown.convert(delta),
      '**重点** *斜体* ~~删除~~ [链接](https://example.com)',
    );
  });

  test('标题与引用', () {
    final delta = jsonEncode([
      {'insert': '大标题'},
      {'insert': '\n', 'attributes': {'header': 1}},
      {'insert': '引用内容'},
      {'insert': '\n', 'attributes': {'blockquote': true}},
    ]);
    expect(DeltaToMarkdown.convert(delta), '# 大标题\n> 引用内容');
  });

  test('列表', () {
    final delta = jsonEncode([
      {'insert': '苹果'},
      {'insert': '\n', 'attributes': {'list': 'bullet'}},
      {'insert': '香蕉'},
      {'insert': '\n', 'attributes': {'list': 'bullet'}},
    ]);
    expect(DeltaToMarkdown.convert(delta), '- 苹果\n- 香蕉');
  });

  test('图片嵌入', () {
    final delta = jsonEncode([
      {'insert': {'image': 'image-abc.jpg'}},
      {'insert': '\n'},
    ]);
    expect(DeltaToMarkdown.convert(delta), '![](image-abc.jpg)');
  });

  test('代码块', () {
    final delta = jsonEncode([
      {'insert': 'print(1)'},
      {'insert': '\n', 'attributes': {'code-block': true}},
      {'insert': 'print(2)'},
      {'insert': '\n', 'attributes': {'code-block': true}},
    ]);
    final result = DeltaToMarkdown.convert(delta);
    expect(result, contains('```'));
    expect(result, contains('print(1)'));
    expect(result, contains('print(2)'));
  });

  test('非 Delta 内容原样返回', () {
    expect(
      DeltaToMarkdown.convertIfDelta('# 这是 Markdown'),
      '# 这是 Markdown',
    );
  });
}
