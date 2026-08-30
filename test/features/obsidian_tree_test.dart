import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/features/obsidian/obsidian_tree.dart';

void main() {
  ObsidianFile file(String rel) => ObsidianFile(
    relativePath: rel,
    name: rel.split(RegExp(r'[\\/]')).last,
    content: '',
    absolutePath: '/vault/$rel',
  );

  test('空文件列表返回空根节点', () {
    final root = buildObsidianTree([]);
    expect(root.children, isEmpty);
  });

  test('嵌套目录（正斜杠）构建为树，叶子挂文件', () {
    final root = buildObsidianTree([
      file('日记/2026-08/30.md'),
      file('日记/2026-08/31.md'),
      file('目标.md'),
    ]);

    expect(root.children, hasLength(2));
    final diary = root.children.firstWhere((n) => n.name == '日记');
    final month = diary.children.single;
    expect(month.name, '2026-08');
    expect(month.children, hasLength(2));
    expect(month.children.every((n) => n.file != null), isTrue);
    expect(root.children.any((n) => n.name == '目标.md'), isTrue);
  });

  test('Windows 反斜杠路径同样按目录拆分（回归：路径兼容）', () {
    final root = buildObsidianTree([
      file(r'日记\2026-08\30.md'),
      file(r'日记\2026-08\31.md'),
    ]);

    final diary = root.children.single;
    expect(diary.name, '日记');
    final month = diary.children.single;
    expect(month.name, '2026-08');
    expect(month.children, hasLength(2));
  });
}
