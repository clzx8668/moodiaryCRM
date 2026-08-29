import 'package:flutter/material.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/features/block/block_renderer.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/utils/notice_util.dart';

/// Obsidian 子页：主区 Markdown 渲染 + 右侧抽屉文件目录树 + 双链跳转。
class ObsidianPage extends StatefulWidget {
  const ObsidianPage({super.key});

  @override
  State<ObsidianPage> createState() => _ObsidianPageState();
}

class _ObsidianPageState extends State<ObsidianPage> {
  final ObsidianService _service = ObsidianService.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  _Node? _tree;
  ObsidianFile? _selected;
  List<String> _links = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    // 首次加载复用 5 秒幂等缓存；「刷新文件树」按钮才强制重扫
    await _service.scan(force: force);
    if (!mounted) return;
    setState(() {
      _tree = _buildTree(_service.files);
      _loading = false;
      // 保持当前选中文件（若仍在列表）
      if (_selected != null) {
        final same = _service.files
            .where((f) => f.relativePath == _selected!.relativePath)
            .toList();
        _selected = same.isEmpty ? null : same.first;
        _refreshLinks();
      }
    });
  }

  void _refreshLinks() {
    _links = _selected == null
        ? const []
        : _service.extractLinks(_selected!.content);
  }

  void _select(ObsidianFile file) {
    setState(() {
      _selected = file;
      _refreshLinks();
    });
    // 关闭抽屉（EndDrawer 打开时）
    _scaffoldKey.currentState?.closeEndDrawer();
  }

  void _jumpToLink(String link) {
    final target = _service.findByLink(link);
    if (target == null) {
      toast.info(message: '未找到笔记：$link');
      return;
    }
    _select(target);
  }

  _Node? _buildTree(List<ObsidianFile> files) {
    final root = _Node('', []);
    for (final f in files) {
      // Windows 下 p.relative 返回反斜杠路径，统一按 / 与 \ 拆分
      final parts = f.relativePath.split(RegExp(r'[\\/]'));
      var node = root;
      for (var i = 0; i < parts.length - 1; i++) {
        node = node.childOrCreate(parts[i]);
      }
      node.children.add(_Node(parts.last, const [], file: f));
    }
    return root;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _selected == null ? 'Obsidian' : _selected!.linkName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        leading: const PageBackButton(),
        actions: [
          IconButton(
            tooltip: '文件目录树',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.account_tree_outlined),
          ),
          IconButton(
            tooltip: '刷新文件树',
            onPressed: () => _load(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '文件目录树',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading || _tree == null
                    ? const Center(child: CircularProgressIndicator())
                    : _tree!.children.isEmpty
                    ? const Center(child: Text('Vault 中没有 .md 文件'))
                    : ListView(
                        children: [
                          for (final node in _tree!.children)
                            _buildTreeNode(node, 0),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _selected == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('从右侧文件目录树选择一篇笔记'),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _scaffoldKey.currentState?.openEndDrawer(),
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text('打开文件目录树'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Center(
                    child: MarkdownContentView(
                      data: _selected!.content,
                      selectable: false,
                    ),
                  ),
                ),
                if (_links.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '双链',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final link in _links)
                        ActionChip(
                          label: Text(link),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _jumpToLink(link),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildTreeNode(_Node node, int depth) {
    if (node.file != null) {
      final selected = _selected?.relativePath == node.file!.relativePath;
      return ListTile(
        dense: true,
        leading: const Icon(Icons.description_outlined, size: 16),
        title: Text(
          node.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : null,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
        selected: selected,
        contentPadding: EdgeInsets.only(left: 8.0 + depth * 16, right: 8),
        onTap: () => _select(node.file!),
      );
    }
    return ExpansionTile(
      dense: true,
      leading: const Icon(Icons.folder_rounded, size: 18),
      title: Text(
        node.name,
        style: const TextStyle(fontSize: 13),
      ),
      childrenPadding: EdgeInsets.zero,
      children: [
        for (final child in node.children) _buildTreeNode(child, depth + 1),
      ],
    );
  }
}

class _Node {
  final String name;
  final List<_Node> children;
  final ObsidianFile? file;

  _Node(this.name, List<_Node> children, {this.file})
      : children = List.of(children);

  _Node childOrCreate(String name) {
    for (final c in children) {
      if (c.name == name) return c;
    }
    final node = _Node(name, const []);
    children.add(node);
    return node;
  }
}
