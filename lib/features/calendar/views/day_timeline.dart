import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../schedule/models/schedule.dart';
import '../calendar_agenda.dart';
import '../ios_calendar_theme.dart';

/// 24 小时时间轴画布（iOS 18 风交互）：
///
/// - **长按空白处**（可继续拖动）→ 拉出一段「幽灵块」，松手即按该时间段新建事件；
/// - **长按事件卡拖动**→ 移动事件（15 分钟吸附），松手落库；
/// - **长按事件卡底部手柄拖动**→ 改结束时间（15 分钟吸附）；
/// - **点击事件卡**→ 详情面板。
///
/// 事件用绝对定位（重叠时自动并排分栏），因此手势能直接拿到纵向像素 → 分钟。
class DayTimeline extends StatefulWidget {
  final DateTime day;
  final List<Schedule> events;
  final Color Function(Schedule) colorOf;
  final double hourHeight;
  /// 拖到边缘时自动滚动（跟随拖动上下滚动）
  final ScrollController? scrollController;
  /// 时间轴所在视口（用于算边缘）
  final GlobalKey? viewportKey;
  final void Function(Schedule event) onTapEvent;
  final void Function(DateTime start, DateTime end) onCreateRange;
  final void Function(Schedule event, DateTime newStart) onMoveEvent;
  final void Function(Schedule event, DateTime newEnd) onResizeEvent;
  final List<TimelineMarker> markers;
  final bool showNowLine;

  const DayTimeline({
    super.key,
    required this.day,
    required this.events,
    required this.colorOf,
    required this.onTapEvent,
    required this.onCreateRange,
    required this.onMoveEvent,
    required this.onResizeEvent,
    this.markers = const [],
    this.hourHeight = 52,
    this.showNowLine = false,
    this.scrollController,
    this.viewportKey,
  });

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

/// 正在拖动的东西（新建/移动/改时长共用一套幽灵块渲染）。
enum _DragKind { create, move, resize }

/// 时间轴上的提醒事项标记（技巧 02：带时刻的待办画空心圆）。
class TimelineMarker {
  final DateTime at;
  final String text;
  final bool done;
  final VoidCallback? onToggle;

  const TimelineMarker({
    required this.at,
    required this.text,
    this.done = false,
    this.onToggle,
  });
}

class _DayTimelineState extends State<DayTimeline> {
  static const double _gutter = 48; // 左侧时间栏宽度

  _DragKind? _kind;
  double _startY = 0;
  double _currentY = 0;
  Schedule? _dragged;

  /// 拖动时吸附到的目标时刻（分钟），用于「展开变宽」的吸附槽
  int? _dragSlotMinutes;

  /// 拖动到视口边缘时自动滚动
  void _autoScroll(Offset globalPosition) {
    final controller = widget.scrollController;
    final viewport = widget.viewportKey?.currentContext?.findRenderObject();
    if (controller == null ||
        viewport is! RenderBox ||
        controller.positions.length != 1) {
      return;
    }
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    const edge = 72.0;
    const maxStep = 14.0;
    final y = globalPosition.dy;
    if (y < top + edge) {
      final f = ((top + edge - y) / edge).clamp(0.0, 1.0);
      controller.jumpTo(
        (controller.offset - maxStep * f).clamp(
          0.0,
          controller.position.maxScrollExtent,
        ),
      );
    } else if (y > bottom - edge) {
      final f = ((y - (bottom - edge)) / edge).clamp(0.0, 1.0);
      controller.jumpTo(
        (controller.offset + maxStep * f).clamp(
          0.0,
          controller.position.maxScrollExtent,
        ),
      );
    }
  }

  /// 当前拖动落在哪个吸附槽（15 分钟）
  void _updateDragSlot(double y) {
    final minutes = (y / widget.hourHeight * 60).round();
    _dragSlotMinutes = snapMinutes(minutes, _snapMin).clamp(0, 24 * 60);
  }

  double get _totalHeight => 24 * widget.hourHeight;

  int get _snapMin => 15;

  // ------------------------------------------------------------ 新建（拖动拉块）

  void _createStart(LongPressStartDetails d) {
    HapticFeedback.mediumImpact(); // 长按进入拖动（文档 §5.2：长按 + 震动反馈）
    setState(() {
      _kind = _DragKind.create;
      _startY = d.localPosition.dy;
      _currentY = d.localPosition.dy;
      _updateDragSlot(d.localPosition.dy);
    });
  }

  void _createUpdate(LongPressMoveUpdateDetails d) {
    if (_kind != _DragKind.create) return;
    _autoScroll(d.globalPosition);
    setState(() {
      _currentY = d.localPosition.dy;
      _updateDragSlot(d.localPosition.dy);
    });
  }

  void _createEnd(LongPressEndDetails d) {
    if (_kind != _DragKind.create) return;
    final startY = _startY;
    final endY = _currentY;
    setState(() => _kind = null);
    setState(() => _dragSlotMinutes = null);

    final dragged = (endY - startY).abs() >= widget.hourHeight / 4; // ≥15 分钟
    final (start, end) = dragRangeToTimes(
      day: widget.day,
      startY: dragged ? startY : _snapToGrid(startY),
      endY: dragged ? endY : _snapToGrid(startY) + widget.hourHeight,
      hourHeight: widget.hourHeight,
      snapMin: _snapMin,
    );
    widget.onCreateRange(start, end);
  }

  /// 单击不拖：落点对齐到整点/半小时，默认 1 小时。
  double _snapToGrid(double y) {
    final minutes = y / widget.hourHeight * 60;
    return snapMinutes(minutes.round(), 30) / 60 * widget.hourHeight;
  }

  // ------------------------------------------------------------ 移动 / 改时长

  void _eventStart(Schedule e, _DragKind kind, Offset local) {
    HapticFeedback.mediumImpact();
    setState(() {
      _kind = kind;
      _dragged = e;
      _startY = local.dy;
      _currentY = local.dy;
      _updateDragSlot(
        (e.startTime.hour * 60 + e.startTime.minute).toDouble(),
      );
    });
  }

  void _eventUpdate(Offset local, [Offset? global]) {
    if (_kind == null || _dragged == null) return;
    if (global != null) _autoScroll(global);
    setState(() {
      _currentY = local.dy;
      _updateDragSlot(local.dy);
    });
  }

  void _eventEnd() {
    final kind = _kind;
    final e = _dragged;
    final deltaPx = _currentY - _startY;
    setState(() {
      _kind = null;
      _dragged = null;
      _dragSlotMinutes = null;
    });
    if (kind == null || e == null) return;
    if (deltaPx.abs() < 6) return; // 手抖不算拖动
    final deltaMin = dragDeltaMinutes(deltaPx, widget.hourHeight, snapMin: _snapMin);
    if (deltaMin == 0) return;
    if (kind == _DragKind.move) {
      widget.onMoveEvent(e, e.startTime.add(Duration(minutes: deltaMin)));
    } else {
      final base = e.endTime ?? e.startTime.add(const Duration(hours: 1));
      var newEnd = base.add(Duration(minutes: deltaMin));
      if (!newEnd.isAfter(e.startTime)) {
        newEnd = e.startTime.add(Duration(minutes: _snapMin));
      }
      widget.onResizeEvent(e, newEnd);
    }
  }

  // ------------------------------------------------------------ 幽灵块

  /// 返回幽灵块的 (top, height) 像素区间；没有拖动时返回 null。
  (double, double)? _ghost() {
    final kind = _kind;
    if (kind == null) return null;
    if (kind == _DragKind.create) {
      final top = _startY < _currentY ? _startY : _currentY;
      final bottom = _startY < _currentY ? _currentY : _startY;
      final height = (bottom - top).abs() < widget.hourHeight / 4
          ? widget.hourHeight
          : bottom - top;
      return (top.clamp(0.0, _totalHeight), height.clamp(8.0, _totalHeight));
    }
    final e = _dragged!;
    final deltaMin = dragDeltaMinutes(
      _currentY - _startY,
      widget.hourHeight,
      snapMin: _snapMin,
    );
    final pxPerMin = widget.hourHeight / 60;
    final startMin = minutesOfDay(e.startTime);
    final durationMin = _endMinutesOf(e) - startMin;
    final top = kind == _DragKind.move
        ? (startMin + deltaMin) * pxPerMin
        : startMin * pxPerMin;
    final height = kind == _DragKind.move
        ? durationMin * pxPerMin
        : (durationMin + deltaMin) * pxPerMin;
    return (
      top.clamp(0.0, _totalHeight),
      height.clamp(10.0, _totalHeight),
    );
  }

  int _endMinutesOf(Schedule e) {
    final start = minutesOfDay(e.startTime);
    final end = e.endTime == null ? start + 60 : minutesOfDay(e.endTime!);
    return end > start ? end : start + 30;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final layouts = layoutDayTimeline(widget.events);
    final ghost = _ghost();

    return SizedBox(
      height: _totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1) 整点分隔线 + 时间标签
          for (var h = 0; h <= 24; h++)
            if (!_nearNow(h * widget.hourHeight))
            Positioned(
              // 行高给足 14px：否则 text 会被 1px 的紧约束裁没
              // （整日概览把每小时压到 ~30px 时就看不见时间标签了）
              top: h * widget.hourHeight - 7,
              left: 0,
              right: 0,
              height: 14,
              child: Row(
                children: [
                  SizedBox(
                    width: _gutter - 6,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: h == 24
                          ? const SizedBox.shrink()
                          : Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        height: 0.6,
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 1.5) 半小时虚线（文档 §3.3：整点实线、半点虚线）
          for (var h = 0; h < 24; h++)
            if (!_nearNow(h * widget.hourHeight + widget.hourHeight / 2))
            Positioned(
              top: h * widget.hourHeight + widget.hourHeight / 2,
              left: _gutter,
              right: 10,
              height: 1,
              child: CustomPaint(
                painter: _DashedLinePainter(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),

          // 2) 拖动创建手势层（在事件卡下面，卡片手势优先命中）
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: _gutter),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressStart: _createStart,
                onLongPressMoveUpdate: _createUpdate,
                onLongPressEnd: _createEnd,
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // 3) 事件卡（绝对定位 + 重叠分栏）
          for (final layout in layouts)
            Positioned(
              top: layout.topRatio * _totalHeight,
              height: (layout.heightRatio * _totalHeight).clamp(22.0, _totalHeight),
              left:
                  _gutter +
                  2 +
                  layout.leftFactor * (MediaQuery.sizeOf(context).width - _gutter - 8),
              width:
                  (MediaQuery.sizeOf(context).width - _gutter - 8) *
                      layout.widthFactor -
                  2,
              child: _TimelineEventCard(
                event: layout.event,
                color: widget.colorOf(layout.event),
                onTap: () => widget.onTapEvent(layout.event),
                onDragStart: (kind, local) =>
                    _eventStart(layout.event, kind, local),
                onDragUpdate: _eventUpdate,
                onDragEnd: _eventEnd,
              ),
            ),

          // 3.5) 提醒事项：带时刻的待办在对应位置画空心圆
          for (final m in widget.markers)
            Positioned(
              top: minutesOfDay(m.at) / 60 * widget.hourHeight,
              left: _gutter + 2,
              right: 8,
              child: IgnorePointer(
                ignoring: m.onToggle == null,
                child: InkWell(
                  onTap: m.onToggle,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          m.done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 13,
                          color: m.done
                              ? scheme.outline
                              : scheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${fmtClock(m.at)} ${m.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: m.done
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                              decoration: m.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4) 幽灵块（新建/移动/改时长的实时预览）
          if (ghost != null)
            Positioned(
              top: ghost.$1,
              height: ghost.$2,
              left: _gutter + 2,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(
                      IosCalendarTheme.radiusEvent,
                    ),
                    border: Border.all(color: scheme.primary, width: 1),
                  ),
                  // 拖动时把时间写在块里，一眼知道拖到了几点
                  child: Text(
                    _ghostLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // 4.5) 吸附槽：拖动到哪个时间段，哪一段就展开变宽（带整点/半点标识）
          if (_kind != null && _dragSlotMinutes != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              top: _dragSlotMinutes! / 60 * widget.hourHeight - 13,
              left: 0,
              right: 8,
              height: 26,
              child: IgnorePointer(child: _slotBand(theme)),
            ),

          // 5) 当前时间红线
          if (widget.showNowLine) _nowLine(theme),
        ],
      ),
    );
  }

  Widget _nowLine(ThemeData theme) {
    final now = DateTime.now();
    final top = minutesOfDay(now) / 60 * widget.hourHeight;
    final scheme = theme.colorScheme;
    // 「现在」所在区域整体展开成一条带，嵌进固定时间线里；
    // 与整点/半点重合时固定线会被隐藏（见 _nearNow），不会两条线叠着。
    return Positioned(
      top: top - 11,
      left: 0,
      right: 8,
      height: 22,
      child: Row(
        children: [
          SizedBox(
            width: _gutter - 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: IosCalendarTheme.today.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  fmtClock(now),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: IosCalendarTheme.today,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: IosCalendarTheme.today,
            ),
          ),
          Expanded(
            child: Container(
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: IosCalendarTheme.today.withValues(
                  alpha: 0.10,
                ),
                border: Border(
                  top: BorderSide(
                    color: IosCalendarTheme.today.withValues(alpha: 0.5),
                    width: 0.6,
                  ),
                  bottom: BorderSide(
                    color: IosCalendarTheme.today.withValues(alpha: 0.5),
                    width: 0.6,
                  ),
                ),
              ),
              child: Container(height: 1.6, color: IosCalendarTheme.today),
            ),
          ),
          // scheme 只为保持主题引用（避免未使用告警）
          if (scheme.brightness == Brightness.dark) const SizedBox.shrink(),
        ],
      ),
    );
  }

  /// 现在时间是否紧贴某条固定线（±12px 内则隐藏那条线，避免双线）
  bool _nearNow(double y) {
    if (!widget.showNowLine) return false;
    final nowTop = minutesOfDay(DateTime.now()) / 60 * widget.hourHeight;
    return (y - nowTop).abs() < 12;
  }

  /// 拖动吸附槽的说明文案：整点/半点/刻钟一眼可分
  String _slotLabel() {
    final minutes = _dragSlotMinutes ?? 0;
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final clock = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    final kind = switch (m) {
      0 => '整点',
      30 => '半点',
      15 || 45 => '一刻',
      _ => '',
    };
    return kind.isEmpty ? clock : '$clock · $kind';
  }

  Widget _slotBand(ThemeData theme) {
    final scheme = theme.colorScheme;
    final minutes = _dragSlotMinutes ?? 0;
    final onHour = minutes % 60 == 0;
    final color = onHour ? scheme.primary : scheme.primary.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(left: _gutter + 2),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: onHour ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: onHour ? 1.4 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              _slotLabel(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: onHour ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              onHour ? '整点线' : '半点/刻钟',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ghostLabel() {
    final kind = _kind;
    if (kind == _DragKind.create) {
      final (start, end) = dragRangeToTimes(
        day: widget.day,
        startY: _startY,
        endY: _currentY,
        hourHeight: widget.hourHeight,
      );
      return '${fmtClock(start)} – ${fmtClock(end)}';
    }
    final e = _dragged;
    if (e == null) return '';
    final deltaMin = dragDeltaMinutes(
      _currentY - _startY,
      widget.hourHeight,
      snapMin: _snapMin,
    );
    if (kind == _DragKind.move) {
      final start = e.startTime.add(Duration(minutes: deltaMin));
      final end = e.endTime?.add(Duration(minutes: deltaMin));
      return end == null
          ? fmtClock(start)
          : '${fmtClock(start)} – ${fmtClock(end)}';
    }
    final base = e.endTime ?? e.startTime.add(const Duration(hours: 1));
    return '${fmtClock(e.startTime)} – ${fmtClock(base.add(Duration(minutes: deltaMin)))}';
  }
}

/// 时间轴上的可拖动事件卡。
class _TimelineEventCard extends StatelessWidget {
  final Schedule event;
  final Color color;
  final VoidCallback onTap;
  final void Function(_DragKind kind, Offset local) onDragStart;
  final void Function(Offset local, Offset global) onDragUpdate;
  final VoidCallback onDragEnd;

  const _TimelineEventCard({
    required this.event,
    required this.color,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxHeight < 40;
        final hasLocation = (event.location ?? '').trim().isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPressStart: (d) => onDragStart(_DragKind.move, d.localPosition),
          onLongPressMoveUpdate: (d) =>
              onDragUpdate(d.localPosition, d.globalPosition),
          onLongPressEnd: (_) => onDragEnd(),
          child: Container(
            decoration: BoxDecoration(
              // 文档 §3.3：事件块圆角 6pt、底色 20% 透明 + 左侧 3pt 实色边
              color: IosCalendarTheme.eventFill20(
                color,
                scheme.surfaceContainerLow,
              ),
              borderRadius: BorderRadius.circular(
                IosCalendarTheme.radiusEvent,
              ),
              border: Border.all(
                color: IosCalendarTheme.eventBorder(color),
                width: 0.8,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(3, dense ? 2 : 5, 6, 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              event.title,
                              maxLines: dense ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                decoration: event.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (!dense)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  '${eventTimeLabel(event)}'
                                  '${hasLocation ? ' · ${event.location}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 底部改时长手柄（长按拖动）
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 14,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (d) =>
                        onDragStart(_DragKind.resize, d.localPosition),
                    onLongPressMoveUpdate: (d) =>
                        onDragUpdate(d.localPosition, d.globalPosition),
                    onLongPressEnd: (_) => onDragEnd(),
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 3,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 半小时刻度用的虚线。
class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const dash = 3.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, 0.5),
        Offset((x + dash).clamp(0, size.width), 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}
