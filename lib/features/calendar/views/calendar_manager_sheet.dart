import 'package:flutter/material.dart';

import '../calendar_repository.dart';
import '../models/calendar_list.dart';

/// 「日历管理」底部面板（技巧 04/08）：
/// 列出全部日历（色点 / 名称 / 共享人数 / 显示开关），可新建、改色改名、设默认、删除。
Future<void> showCalendarManagerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => const _CalendarManagerSheet(),
  );
}

class _CalendarManagerSheet extends StatefulWidget {
  const _CalendarManagerSheet();

  @override
  State<_CalendarManagerSheet> createState() => _CalendarManagerSheetState();
}

class _CalendarManagerSheetState extends State<_CalendarManagerSheet> {
  final _repo = CalendarRepository();
  List<CalendarList> _calendars = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.listAll();
    if (!mounted) return;
    setState(() {
      _calendars = list;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final draft = await _editCalendar(name: '', color: CalendarColors.palette.first);
    if (draft == null) return;
    await _repo.create(name: draft.$1, color: draft.$2);
    await _load();
  }

  Future<void> _edit(CalendarList calendar) async {
    final result = await _editCalendar(
      name: calendar.name,
      color: calendar.color,
      readOnlySource: calendar.readOnly,
    );
    if (result == null) return;
    calendar
      ..name = result.$1
      ..color = result.$2;
    await _repo.update(calendar);
    await _load();
  }

  Future<void> _delete(CalendarList calendar) async {
    final ok = await _repo.softDelete(calendar.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少要保留一个日历')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除「${calendar.name}」，其中的事件已移到默认日历')),
    );
    await _load();
  }

  Future<(String, int)?> _editCalendar({
    required String name,
    required int color,
    bool readOnlySource = false,
  }) {
    final controller = TextEditingController(text: name);
    var picked = color;
    return showDialog<(String, int)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(name.isEmpty ? '新建日历' : '编辑日历'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: name.isEmpty,
                enabled: !readOnlySource,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '如：工作 / 生活 / 家庭',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              const Text('颜色'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in CalendarColors.palette)
                    InkWell(
                      onTap: readOnlySource
                          ? null
                          : () => setState(() => picked = c),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(c),
                          border: Border.all(
                            color: picked == c
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: picked == c
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                (controller.text.trim(), picked),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('日历', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加日历'),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final c in _calendars)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(c.color),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(c.name),
                      if (c.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '默认',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    [
                      if (c.isShared) '${c.sharedCount} 人共享' else '仅自己',
                      if (c.readOnly) _sourceLabel(c.source),
                    ].join(' · '),
                    style: theme.textTheme.labelSmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: c.visible ? '隐藏这个日历' : '显示这个日历',
                        icon: Icon(
                          c.visible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: c.visible
                              ? scheme.onSurface
                              : scheme.outline,
                        ),
                        onPressed: () async {
                          await _repo.setVisible(c.id, !c.visible);
                          await _load();
                        },
                      ),
                      PopupMenuButton<String>(
                        tooltip: '更多',
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              await _edit(c);
                            case 'default':
                              await _repo.setDefault(c.id);
                              await _load();
                            case 'delete':
                              await _delete(c);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('改名 / 改色')),
                          if (!c.isDefault)
                            const PopupMenuItem(
                              value: 'default',
                              child: Text('设为默认日历'),
                            ),
                          const PopupMenuItem(value: 'delete', child: Text('删除日历')),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _edit(c),
                ),
            const SizedBox(height: 8),
            Text(
              '共享与同步：本地库是主库；把日历共享给家人/同事需要连上 Hermes（设置 → 日历）。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(String source) => switch (source) {
    'hermes' => 'Hermes 同步',
    'icloud' => 'iCloud 订阅',
    _ => '本地',
  };
}
