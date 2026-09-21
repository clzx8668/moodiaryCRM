import 'package:flutter/material.dart';

import '../../schedule/models/schedule.dart';
import '../../schedule/schedule_repository.dart';
import '../calendar_agenda.dart';

/// 事件详情面板（iOS 18：点事件先看详情，再决定编辑/删除）。
///
/// 返回值：`edit` = 用户点了编辑（调用方进编辑器）；`changed` = 已删除/复制（调用方刷新）。
enum EventDetailResult { edit, changed }

Future<EventDetailResult?> showEventDetailSheet(
  BuildContext context, {
  required Schedule event,
  required Color color,
  required String calendarName,
}) {
  return showModalBottomSheet<EventDetailResult>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => _EventDetailSheet(
      event: event,
      color: color,
      calendarName: calendarName,
    ),
  );
}

class _EventDetailSheet extends StatelessWidget {
  final Schedule event;
  final Color color;
  final String calendarName;

  const _EventDetailSheet({
    required this.event,
    required this.color,
    required this.calendarName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasLocation = (event.location ?? '').trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  calendarName,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
                const Spacer(),
                if (event.repeatType != RepeatType.none)
                  Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.repeatType.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                decoration: event.done ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.schedule_rounded,
              text: '${dayLabel(event.startTime)} · ${eventTimeLabel(event)}',
            ),
            if (hasLocation)
              _InfoRow(
                icon: Icons.place_outlined,
                text: event.location!,
              ),
            if (event.timeZoneId != null)
              _InfoRow(
                icon: Icons.public_rounded,
                text: event.timeZoneId!,
              ),
            if (event.remindOffsetMin != null)
              _InfoRow(
                icon: Icons.alarm_rounded,
                text: event.remindOffsetMin == -1
                    ? '出发时间提醒'
                    : event.remindOffsetMin == 0
                    ? '准时提醒'
                    : '提前 ${event.remindOffsetMin} 分钟提醒',
              ),
            if (event.attachments.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final a in event.attachments)
                _InfoRow(
                  icon: Icons.attach_file_rounded,
                  text: '${a.name}  ·  ${a.sizeLabel}',
                ),
            ],
            if (event.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                event.notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(EventDetailResult.edit),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('编辑'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final copied = event.clone()
                        ..id = ''
                        ..title = '${event.title}（副本）'
                        ..done = false;
                      await ScheduleRepository().create(copied);
                      if (context.mounted) {
                        Navigator.of(context).pop(EventDetailResult.changed);
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('复制'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await _confirmDelete(context);
                      if (ok != true) return;
                      await ScheduleRepository().softDelete(event.id);
                      if (context.mounted) {
                        Navigator.of(context).pop(EventDetailResult.changed);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('删除'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '长按时间轴空白处可拖动新建；长按事件卡可拖动改时间，拖底部手柄改时长。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除事件'),
      content: Text('确定删除「${event.title}」吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
