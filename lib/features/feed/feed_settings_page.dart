import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/feed/feed_models.dart';
import 'package:moodiary/features/feed/feed_maintenance.dart';
import 'package:moodiary/features/feed/feed_parser.dart';
import 'package:moodiary/features/feed/feed_saver.dart';
import 'package:moodiary/features/feed/feed_service.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:uuid/uuid.dart';

/// 内容源（RSS/Atom 订阅）管理页：新增 / 启用 / 删除 / 立即刷新。
class FeedSettingsPage extends StatefulWidget {
  const FeedSettingsPage({super.key});

  @override
  State<FeedSettingsPage> createState() => _FeedSettingsPageState();
}

class _FeedSettingsPageState extends State<FeedSettingsPage> {
  List<FeedSource> _sources = [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTargetKb();
  }

  void _load() {
    setState(() {
      _sources = FeedService.loadSources();
      _loading = false;
    });
  }

  Future<void> _persist() => FeedService.saveSources(_sources);

  Future<void> _addSource() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _AddFeedDialog(),
    );
    if (url == null || url.trim().isEmpty) return;
    setState(() {
      _sources.add(
        FeedSource(id: const Uuid().v7(), url: url.trim()),
      );
    });
    await _persist();
    if (mounted) toast.success(message: '已添加订阅源');
  }

  Future<void> _toggle(FeedSource source, bool value) async {
    setState(() => source.enabled = value);
    await _persist();
  }

  Future<void> _remove(FeedSource source) async {
    setState(() => _sources.remove(source));
    await _persist();
    if (mounted) toast.info(message: '已删除订阅源');
  }

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    final targets = _sources.where((s) => s.enabled).toList();
    if (targets.isEmpty) {
      toast.info(message: '没有启用的订阅源');
      return;
    }
    setState(() => _refreshing = true);
    var saved = 0;
    var failed = 0;
    for (final source in targets) {
      final result = await FeedService.fetch(source);
      if (!result.ok) {
        source.lastError = result.error ?? '拉取失败';
        failed++;
        continue;
      }
      final keys = <String>[];
      for (final item in result.items) {
        try {
          await FeedSaver.save(source: source, item: item);
          keys.add(FeedParser.itemKey(item));
          saved++;
        } catch (_) {
          // 单条失败不中断该源
        }
      }
      source.lastItemKeys = FeedService.updatedKeys(
        source.lastItemKeys,
        keys,
      );
      source.lastFetchedAt = DateTime.now().millisecondsSinceEpoch;
      source.lastError = '';
    }
    await _persist();
    if (!mounted) return;
    setState(() => _refreshing = false);
    toast.success(
      message: failed == 0
          ? '订阅刷新完成：新增 $saved 条'
          : '订阅刷新完成：新增 $saved 条，$failed 个源失败',
    );
  }

  String _subtitle(FeedSource s) {
    final lines = <String>[s.url];
    if (s.lastError.trim().isNotEmpty) {
      lines.add('失败：${s.lastError}');
    } else if (s.lastFetchedAt == 0) {
      lines.add('尚未刷新');
    } else {
      final t = DateTime.fromMillisecondsSinceEpoch(s.lastFetchedAt);
      lines.add('上次刷新：${t.toString().split('.').first}');
    }
    return lines.join('\n');
  }

  /// 清理重复订阅条目 + 规范化来源标签（重复进回收站，可恢复）。
  Future<void> _cleanupDuplicates() async {
    final plan = await FeedMaintenance.preview();
    if (!mounted) return;
    if (plan.recycleDiaryIds.isEmpty && plan.tagUpdates.isEmpty) {
      toast.info(message: '没有需要清理的订阅条目');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理重复条目'),
        content: Text(
          '发现 ${plan.recycleDiaryIds.length} 条重复订阅条目（保留最新），'
          '${plan.tagUpdates.length} 条来源标签可规范化为短名。\n'
          '重复条目将移入回收站，可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final recycled = await FeedMaintenance.apply(plan);
    if (!mounted) return;
    // 首页列表可能缓存了旧标签/旧条目，清理后主动刷新
    if (Get.isRegistered<HomeLogic>()) {
      await Get.find<HomeLogic>().refreshDiaryLists();
    }
    toast.success(message: '已清理 $recycled 条重复条目（可在回收站恢复）');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容源'),
        actions: [
          IconButton(
            tooltip: '立即刷新',
            onPressed: _refreshing ? null : _refreshAll,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (v) {
              if (v == 'cleanup') _cleanupDuplicates();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cleanup', child: Text('清理重复条目')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSource,
        tooltip: '添加订阅源',
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildKbTile(context),
                const Divider(height: 1),
                Expanded(
                  child: _sources.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('还没有订阅源，点击右下 + 添加 RSS/Atom 地址'),
                          ),
                        )
                      : ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
              itemCount: _sources.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final source = _sources[index];
                final failed = source.lastError.trim().isNotEmpty;
                return ListTile(
                  leading: Icon(
                    Icons.rss_feed_rounded,
                    color: failed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    source.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _subtitle(source),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: source.enabled,
                        onChanged: (v) => _toggle(source, v),
                      ),
                      PopupMenuButton<String>(
                        tooltip: '更多',
                        onSelected: (v) {
                          if (v == 'refresh') _refreshAll();
                          if (v == 'delete') _remove(source);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'refresh',
                            child: Text('立即刷新全部'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    ],
                  ),
                );
              },
                        ),
                ),
              ],
            ),
    );
  }

  String _kbId = '';
  String _kbName = '';

  Future<void> _loadTargetKb() async {
    _kbId = FeedService.targetKnowledgeBaseId();
    if (_kbId.isEmpty) {
      if (mounted) setState(() => _kbName = '');
      return;
    }
    try {
      final list = await RagService().listKnowledgeBases();
      final hit = list.where((k) => k.id == _kbId);
      if (mounted) {
        setState(() => _kbName = hit.isEmpty ? '(已删除)' : hit.first.name);
      }
    } catch (_) {
      if (mounted) setState(() => _kbName = '');
    }
  }

  Widget _buildKbTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.menu_book_rounded),
      title: const Text('归入知识库'),
      subtitle: Text(
        _kbId.isEmpty ? '未设置（订阅条目仅入库为笔记）' : '新条目自动加入：$_kbName',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _pickKb,
    );
  }

  Future<void> _pickKb() async {
    final bases = await RagService().listKnowledgeBases();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('订阅条目归入知识库'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('不归入'),
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final kb in bases)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(kb.name),
                selected: kb.id == _kbId,
                onTap: () => Navigator.pop(sheetContext, kb.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await PrefUtil.setValue('feedAutoKbId', picked);
    if (!mounted) return;
    if (picked.isEmpty) {
      setState(() {
        _kbId = '';
        _kbName = '';
      });
      toast.success(message: '已取消自动归入');
    } else {
      await _loadTargetKb();
      toast.success(message: '已设置归入：$_kbName');
    }
  }
}

/// 添加订阅源对话框（自管理控制器，避免对话框退场动画期间 dispose 崩溃）。
class _AddFeedDialog extends StatefulWidget {
  const _AddFeedDialog();

  @override
  State<_AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<_AddFeedDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加订阅源'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          hintText: 'https://example.com/feed.xml（RSS / Atom）',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('添加'),
        ),
      ],
    );
  }
}
