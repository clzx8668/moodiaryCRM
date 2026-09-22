import 'package:flutter/material.dart';

import '../../schedule/models/schedule.dart';
import '../calendar_agenda.dart';
import '../ios_calendar_theme.dart';

/// 时间轴上的事件卡（iOS 18 风）：左色条 + 淡色底 + 标题 + 地点/时间。
class CalendarEventCard extends StatelessWidget {
  final Schedule event;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onToggleDone;

  /// 紧凑模式：月格放大到标题档时用（单行标题）。
  final bool compact;

  const CalendarEventCard({
    super.key,
    required this.event,
    required this.color,
    this.onTap,
    this.onToggleDone,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = event.done;
    final hasLocation = (event.location ?? '').trim().isNotEmpty;
    final attachments = event.attachments.length;

    return Semantics(
      button: true,
      label: event.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IosCalendarTheme.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: IosCalendarTheme.eventFill(color, scheme.surfaceContainerLow),
            borderRadius: BorderRadius.circular(IosCalendarTheme.cardRadius),
            border: Border.all(
              color: IosCalendarTheme.eventBorder(color),
              width: 0.8,
            ),
            boxShadow: IosCalendarTheme.softShadow(scheme),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(IosCalendarTheme.cardRadius),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10, compact ? 6 : 8, 8, compact ? 6 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (!compact)
                              SizedBox(
                                width: 44,
                                child: Text(
                                  fmtClock(event.startTime),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                event.title,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: done
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                            if (onToggleDone != null)
                              InkWell(
                                onTap: onToggleDone,
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    done
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 18,
                                    color: done ? color : scheme.outline,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (hasLocation) ...[
                                Icon(
                                  Icons.place_outlined,
                                  size: 11,
                                  color: color,
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    event.location!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                eventTimeLabel(event),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (attachments > 0) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                                Text(
                                  '$attachments',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (event.repeatType != RepeatType.none) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.repeat_rounded,
                                  size: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 月格里的「事件条」（缩放档 L1/L2）。
class CalendarEventBar extends StatelessWidget {
  final Schedule event;
  final Color color;
  final bool showTitle;
  final double height;
  final VoidCallback? onTap;
  final void Function(Offset globalPosition)? onLongPressStart;
  final void Function(Offset globalPosition)? onLongPressMoveUpdate;
  final VoidCallback? onLongPressEnd;

  const CalendarEventBar({
    super.key,
    required this.event,
    required this.color,
    this.showTitle = false,
    this.height = 0,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = Container(
      height: height > 0 ? height : (showTitle ? 15 : 6),
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: showTitle
          ? const EdgeInsets.symmetric(horizontal: 4)
          : EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: showTitle
            ? IosCalendarTheme.eventFill(color, theme.colorScheme.surfaceContainerLow)
            : color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: showTitle
          ? Text(
              event.allDay || event.isMultiDay
                  ? event.title
                  : '${fmtClock(event.startTime)} ${event.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                height: 1.1,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
    if (onLongPressStart == null) {
      return GestureDetector(onTap: onTap, child: bar);
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => onLongPressStart!(d.globalPosition),
      onLongPressMoveUpdate: (d) =>
          onLongPressMoveUpdate?.call(d.globalPosition),
      onLongPressEnd: (_) => onLongPressEnd?.call(),
      child: bar,
    );
  }
}

/// 时间轴上的提醒事项行（空心圆 + 文本 + 勾选）。
class ReminderRow extends StatelessWidget {
  final String text;
  final bool done;
  final Color color;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  const ReminderRow({
    super.key,
    required this.text,
    required this.done,
    required this.color,
    this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 已完成：弱化到 60%（文档 §3.4），但不隐藏
    return Opacity(
      opacity: done ? IosCalendarTheme.completedOpacity : 1,
      child: InkWell(
        onTap: onTap ?? onToggle,
        borderRadius: BorderRadius.circular(IosCalendarTheme.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            InkWell(
              onTap: onToggle,
              customBorder: const CircleBorder(),
              child: Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: done ? theme.colorScheme.outline : color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
