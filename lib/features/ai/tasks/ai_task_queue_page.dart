import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_model.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/features/smart_canvas/widgets/relative_time.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 待处理任务页（批次 88）。
///
/// 背景：离线 / 未配 AI Key 时任务会原地排队等待（批次 83），但此前没有任何入口
/// 能看到「还有多少条在等、为什么在等」。本页把队列摊开：按分组展示、说明该怎么处理，
/// 并支持手动重试与清理。
class AiTaskQueuePage extends StatefulWidget {
  const AiTaskQueuePage({super.key});

  @override
  State<AiTaskQueuePage> createState() => _AiTaskQueuePageState();
}

class _AiTaskQueuePageState extends State<AiTaskQueuePage> {
  final AiTaskRepository _repo = AiTaskRepository();

  List<AiTaskRow> _tasks = const [];
  Map<String, String> _noteTitles = const {};
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // 页面可见期间轻量轮询，便于观察「排队 → 执行 → 完成」的推进
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tasks = await _repo.listAll();
      final titles = await _loadNoteTitles(tasks);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _noteTitles = titles;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 批量取笔记标题（一次查询，任务行里只存 id）。
  Future<Map<String, String>> _loadNoteTitles(List<AiTaskRow> tasks) async {
    final ids = tasks
        .where((t) => t.refType == 'note' && t.refId.isNotEmpty)
        .map((t) => t.refId)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};
    try {
      final db = IsarUtil.database;
      final rows = await (db.select(
        db.diaries,
      )..where((t) => t.id.isIn(ids))).get();
      return {for (final row in rows) row.id: row.title};
    } catch (_) {
      return const {};
    }
  }

  Map<AiTaskGroup, List<AiTaskRow>> _grouped() {
    final map = <AiTaskGroup, List<AiTaskRow>>{};
    for (final task in _tasks) {
      final group = AiTaskQueueModel.groupOf(
        status: task.status,
        retryCount: task.retryCount,
      );
      (map[group] ??= []).add(task);
    }
    return map;
  }

  int _countOf(AiTaskGroup group) => _grouped()[group]?.length ?? 0;

  /// 提示是「锦上添花」：无 UI 上下文（后台/测试）时静默失败即可。
  Future<void> _notify(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // 忽略提示失败，不影响队列操作本身
    }
  }

  Future<void> _requeue(AiTaskRow task) async {
    try {
      await _repo.requeue(task);
      await _notify(
        () => toast.success(
          message: '已重新排队：${AiTaskQueueModel.typeLabel(task.type)}',
        ),
      );
      await _load();
    } catch (e) {
      await _notify(() => toast.error(message: '重试失败：$e'));
    }
  }

  Future<void> _requeueAll(List<AiTaskRow> tasks) async {
    final targets = tasks
        .where(
          (t) => AiTaskQueueModel.canRequeue(
            AiTaskQueueModel.groupOf(
              status: t.status,
              retryCount: t.retryCount,
            ),
          ),
        )
        .toList();
    if (targets.isEmpty) {
      await _notify(() => toast.info(message: '没有需要重试的任务'));
      return;
    }
    await _repo.requeueMany(targets);
    await _notify(() => toast.success(message: '已重新排队 ${targets.length} 条'));
    await _load();
  }

  Future<void> _delete(AiTaskRow task) async {
    await _repo.delete(task.id);
    await _load();
  }

  Future<void> _cleanFinished() async {
    final done = _tasks.where((t) => t.status == AiTaskStatus.done).toList();
    if (done.isEmpty) {
      await _notify(() => toast.info(message: '没有已完成的任务'));
      return;
    }
    final ok = await _confirm(
      title: '清理已完成',
      content: '删除 ${done.length} 条已完成的任务记录？（只清理队列记录，不影响笔记内容）',
    );
    if (ok != true) return;
    final removed = await _repo.deleteByStatuses([AiTaskStatus.done]);
    await _notify(() => toast.success(message: '已清理 $removed 条'));
    await _load();
  }

  Future<void> _cleanFailed() async {
    final failed = _tasks
        .where((t) => t.status == AiTaskStatus.failed)
        .toList();
    if (failed.isEmpty) {
      await _notify(() => toast.info(message: '没有失败的任务'));
      return;
    }
    final ok = await _confirm(
      title: '清空失败任务',
      content:
          '删除 ${failed.length} 条失败的任务记录？\n'
          '（只清队列记录；已经落地的内容或占位卡仍在笔记里）',
    );
    if (ok != true) return;
    final removed = await _repo.deleteByStatuses([AiTaskStatus.failed]);
    await _notify(() => toast.success(message: '已删除 $removed 条失败记录'));
    await _load();
  }

  Future<bool?> _confirm({required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = _grouped();
    final visibleGroups = AiTaskQueueModel.groupOrder
        .where((g) => (grouped[g] ?? const []).isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('待处理任务'),
        actions: [
          IconButton(
            tooltip: '清理已完成',
            onPressed: _cleanFinished,
            icon: const Icon(Icons.cleaning_services_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: visibleGroups.isEmpty
                  ? _buildEmpty(colorScheme)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                      children: [
                        _buildOverview(
                          colorScheme,
                          failed: _countOf(AiTaskGroup.failed),
                          waitingConfig: _countOf(AiTaskGroup.waitingConfig),
                          waitingNetwork: _countOf(AiTaskGroup.waitingNetwork),
                        ),
                        for (final group in visibleGroups) ...[
                          const SizedBox(height: 18),
                          _buildGroupHeader(
                            colorScheme,
                            group,
                            grouped[group]!,
                          ),
                          const SizedBox(height: 6),
                          for (final task in grouped[group]!)
                            _buildTaskCard(colorScheme, group, task),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    // 空态也要能下拉刷新，故用可滚动容器
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 48,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          '队列是空的',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'AI 后台任务会在这里排队；离线或未配置 AI 时也不丢内容',
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildOverview(
    ColorScheme colorScheme, {
    required int failed,
    required int waitingConfig,
    required int waitingNetwork,
  }) {
    final headline = AiTaskQueueModel.headline(
      waitingConfig: waitingConfig,
      waitingNetwork: waitingNetwork,
      failed: failed,
    );
    final pendingCount = _tasks
        .where((t) => t.status != AiTaskStatus.done)
        .length;

    return Card.filled(
      color: colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pendingCount == 0 ? '全部完成' : '待处理 $pendingCount 条',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              headline.isEmpty ? '没有需要处理的异常' : headline,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _requeueAll(_tasks),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('全部重试'),
                ),
                if (failed > 0)
                  TextButton.icon(
                    onPressed: _cleanFailed,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('清空失败'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(
    ColorScheme colorScheme,
    AiTaskGroup group,
    List<AiTaskRow> tasks,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _groupIcon(group),
          size: 18,
          color: _groupColor(colorScheme, group),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AiTaskQueueModel.groupLabel(group)} · ${tasks.length}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                AiTaskQueueModel.groupAdvice(group),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(
    ColorScheme colorScheme,
    AiTaskGroup group,
    AiTaskRow task,
  ) {
    final refText = _refText(task);
    final payload = AiTaskQueueModel.payloadSummary(task.type, task.payload);
    final error = task.errorMessage.trim();

    return Card.filled(
      color: colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        title: Text(
          '${AiTaskQueueModel.typeLabel(task.type)} · $refText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${AiTaskQueueModel.groupLabel(group)} · '
              '更新于 ${relativeTimeLabel(task.updatedAt)}'
              '${task.retryCount > 0 ? ' · 已重试 ${task.retryCount}/${task.maxRetries}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (payload.isNotEmpty)
              Text(
                payload,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (error.isNotEmpty)
              Text(
                error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (AiTaskQueueModel.canRequeue(group))
              IconButton(
                tooltip: '立即重试',
                onPressed: () => _requeue(task),
                icon: const Icon(Icons.refresh_rounded),
              ),
            IconButton(
              tooltip: '删除该记录',
              onPressed: () => _delete(task),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  String _refText(AiTaskRow task) {
    if (task.refType == 'note') {
      final title = _noteTitles[task.refId]?.trim() ?? '';
      if (title.isNotEmpty) return title;
      return '未命名笔记';
    }
    final short = task.refId.length > 10
        ? '${task.refId.substring(0, 10)}…'
        : task.refId;
    return '${AiTaskQueueModel.refTypeLabel(task.refType)} $short';
  }

  IconData _groupIcon(AiTaskGroup group) {
    switch (group) {
      case AiTaskGroup.failed:
        return Icons.error_outline_rounded;
      case AiTaskGroup.waitingConfig:
        return Icons.key_off_rounded;
      case AiTaskGroup.waitingNetwork:
        return Icons.wifi_off_rounded;
      case AiTaskGroup.retrying:
        return Icons.replay_rounded;
      case AiTaskGroup.queued:
        return Icons.schedule_rounded;
      case AiTaskGroup.processing:
        return Icons.autorenew_rounded;
      case AiTaskGroup.done:
        return Icons.check_circle_outline_rounded;
    }
  }

  Color _groupColor(ColorScheme colorScheme, AiTaskGroup group) {
    switch (group) {
      case AiTaskGroup.failed:
        return colorScheme.error;
      case AiTaskGroup.waitingConfig:
        return colorScheme.tertiary;
      case AiTaskGroup.waitingNetwork:
        return colorScheme.secondary;
      case AiTaskGroup.retrying:
        return colorScheme.primary;
      case AiTaskGroup.queued:
        return colorScheme.onSurfaceVariant;
      case AiTaskGroup.processing:
        return colorScheme.primary;
      case AiTaskGroup.done:
        return colorScheme.onSurfaceVariant;
    }
  }
}

/// 设置页入口（带队列概览；返回本页后自动刷新计数）。
class AiTaskQueueTile extends StatefulWidget {
  const AiTaskQueueTile({super.key, this.isFirst, this.isLast});

  final bool? isFirst;
  final bool? isLast;

  @override
  State<AiTaskQueueTile> createState() => _AiTaskQueueTileState();
}

class _AiTaskQueueTileState extends State<AiTaskQueueTile> {
  final AiTaskRepository _repo = AiTaskRepository();
  String _subtitle = '查看排队中的 AI 后台任务';
  bool _hasAttention = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final counts = await _repo.countByStatuses([
        AiTaskStatus.pending,
        AiTaskStatus.processing,
        AiTaskStatus.waitingConfig,
        AiTaskStatus.waitingNetwork,
        AiTaskStatus.failed,
      ]);
      final headline = AiTaskQueueModel.headline(
        waitingConfig: counts[AiTaskStatus.waitingConfig] ?? 0,
        waitingNetwork: counts[AiTaskStatus.waitingNetwork] ?? 0,
        failed: counts[AiTaskStatus.failed] ?? 0,
      );
      final pending =
          (counts[AiTaskStatus.pending] ?? 0) +
          (counts[AiTaskStatus.processing] ?? 0);
      if (!mounted) return;
      setState(() {
        _hasAttention = headline.isNotEmpty;
        _subtitle = headline.isEmpty
            ? (pending > 0 ? '$pending 条排队中（自动执行）' : '队列为空')
            : headline;
      });
    } catch (_) {
      // 数据库未就绪时保持默认文案
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AdaptiveListTile(
      title: const Text('待处理任务'),
      subtitle: Text(_subtitle),
      leading: const Icon(Icons.pending_actions_rounded),
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasAttention)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () async {
        await Get.to(() => const AiTaskQueuePage());
        await _refresh();
      },
    );
  }
}
