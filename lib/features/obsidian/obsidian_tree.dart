import 'package:moodiary/features/obsidian/obsidian_service.dart';

/// Obsidian 文件树节点（目录或文件）。
class ObsidianTreeNode {
  final String name;
  final List<ObsidianTreeNode> children;
  final ObsidianFile? file;

  ObsidianTreeNode(this.name, List<ObsidianTreeNode> children, {this.file})
    : children = List.of(children);

  ObsidianTreeNode childOrCreate(String name) {
    for (final c in children) {
      if (c.name == name) return c;
    }
    final node = ObsidianTreeNode(name, const []);
    children.add(node);
    return node;
  }
}

/// 按相对路径构建文件树（兼容 Windows 反斜杠与移动端正斜杠）。
ObsidianTreeNode buildObsidianTree(List<ObsidianFile> files) {
  final root = ObsidianTreeNode('', []);
  for (final f in files) {
    final parts = f.relativePath.split(RegExp(r'[\\/]'));
    var node = root;
    for (var i = 0; i < parts.length - 1; i++) {
      node = node.childOrCreate(parts[i]);
    }
    node.children.add(ObsidianTreeNode(parts.last, const [], file: f));
  }
  return root;
}
