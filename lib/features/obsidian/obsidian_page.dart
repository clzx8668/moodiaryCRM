import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/features/block/block_renderer.dart';
import 'package:moodiary/features/obsidian/obsidian_controller.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/utils/notice_util.dart';

/// Obsidian 子页：只负责展示选中笔记（Markdown + 双链）+ 刷新。
/// 文件目录树已迁至首页左侧二级导航抽屉（NavDrawer），选中态走
/// [ObsidianController] 共享。
class ObsidianPage extends StatefulWidget {
  const ObsidianPage({super.key});

  @override
  State<ObsidianPage> createState() => _ObsidianPageState();
}

class _ObsidianPageState extends State<ObsidianPage> {
  final ObsidianService _service = ObsidianService.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _service.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    _service.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    // 首次加载复用 5 秒幂等缓存；「刷新」按钮才强制重扫
    final count = await _service.scan(force: force);
    if (kDebugMode) {
      debugPrintSynchronously(
        '[ObsidianPage._load] force=$force 扫描完成：共 $count 篇；'
        '当前选中=${ObsidianController.instance.selectedFile.value?.relativePath ?? '(无)'}',
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _jumpToLink(String link) {
    final target = _service.findByLink(link);
    if (target == null) {
      toast.info(message: '未找到笔记：$link');
      return;
    }
    ObsidianController.instance.select(target);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = ObsidianController.instance.selectedFile.value;
      final colorScheme = Theme.of(context).colorScheme;
      final links = selected == null
          ? const <String>[]
          : _service.extractLinks(selected.content);
      return Scaffold(
        appBar: AppBar(
          title: Text(
            selected?.linkName ?? 'Obsidian',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          leading: const PageBackButton(),
          actions: [
            IconButton(
              tooltip: '刷新文件树',
              onPressed: () => _load(force: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : selected == null
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
                    const Text('在左侧抽屉选择一篇 Obsidian 笔记'),
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
                        data: selected.content,
                        selectable: false,
                      ),
                    ),
                  ),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('双链', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final link in links)
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
    });
  }
}
