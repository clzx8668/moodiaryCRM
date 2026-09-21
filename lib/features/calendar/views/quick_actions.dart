import 'package:flutter/material.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';

import '../calendar_agenda.dart';
import '../quick_parse.dart';

/// 智能新建：说人话建日程（本地规则解析，离线可用）。
///
/// 例：`明天下午3点在会议室A评审方案` → 标题/时间/地点自动填好，进编辑器确认后才落库。
Future<QuickParseResult?> showSmartAddDialog(BuildContext context) {
  return showModalBottomSheet<QuickParseResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SmartAddSheet(),
  );
}

class _SmartAddSheet extends StatefulWidget {
  const _SmartAddSheet();

  @override
  State<_SmartAddSheet> createState() => _SmartAddSheetState();
}

class _SmartAddSheetState extends State<_SmartAddSheet> {
  final _ctrl = TextEditingController();
  QuickParseResult _parsed = const QuickParseResult(title: '');

  static const _examples = [
    '明天下午3点在会议室A评审方案',
    '周五上午10点虹桥机场接李总',
    '10月1日上午9点出发 2小时',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _parsed = parseQuickAdd(value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parsed = _parsed;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('智能新建日程', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '直接说时间和地点，自动解析后进编辑器确认',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: '例如：明天下午3点在会议室A评审方案',
              border: OutlineInputBorder(),
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final e in _examples)
                ActionChip(
                  label: Text(e, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    _ctrl.text = e;
                    _onChanged(e);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ctrl.text.trim().isNotEmpty) _preview(theme, parsed),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: _ctrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(parsed),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('去确认'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(ThemeData theme, QuickParseResult parsed) {
    final scheme = theme.colorScheme;
    final rows = <String>[
      if (parsed.title.isNotEmpty) '标题：${parsed.title}',
      if (parsed.start != null)
        '时间：${dayLabel(parsed.start!)} ${fmtClock(parsed.start!)}'
            '${parsed.end == null ? '' : ' – ${fmtClock(parsed.end!)}'}',
      if (parsed.location != null) '地点：${parsed.location}',
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                rows.isEmpty
                    ? '没认出时间，会按普通标题处理'
                    : '识别结果（置信度 ${(parsed.confidence * 100).round()}%）',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(r, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// 搜索事件（标题/地点/备注），选中后由调用方跳到那天并打开详情。
Future<Schedule?> showEventSearchSheet(BuildContext context) {
  return showModalBottomSheet<Schedule>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _EventSearchSheet(),
  );
}

class _EventSearchSheet extends StatefulWidget {
  const _EventSearchSheet();

  @override
  State<_EventSearchSheet> createState() => _EventSearchSheetState();
}

class _EventSearchSheetState extends State<_EventSearchSheet> {
  final _ctrl = TextEditingController();
  List<Schedule> _all = const [];
  List<Schedule> _hits = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ScheduleRepository().listActive();
    if (!mounted) return;
    setState(() {
      _all = all.reversed.toList(); // 新的在前
      _hits = _all.take(30).toList();
    });
  }

  void _search(String q) {
    final key = q.trim().toLowerCase();
    setState(() {
      _hits = key.isEmpty
          ? _all.take(30).toList()
          : _all
                .where(
                  (e) =>
                      e.title.toLowerCase().contains(key) ||
                      (e.location ?? '').toLowerCase().contains(key) ||
                      e.notes.toLowerCase().contains(key),
                )
                .take(50)
                .toList();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('搜索日程', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '标题 / 地点 / 备注',
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          _search('');
                        },
                      ),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _hits.isEmpty
                  ? Center(
                      child: Text(
                        '没有匹配的日程',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _hits.length,
                      itemBuilder: (context, index) {
                        final e = _hits[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_rounded, size: 18),
                          title: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${dayLabel(e.startTime)} · ${eventTimeLabel(e)}'
                            '${(e.location ?? '').isEmpty ? '' : ' · ${e.location}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
