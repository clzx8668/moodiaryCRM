import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/todo/todo_aggregator.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/features/todo/todo_toggle_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

import '../calendar_agenda.dart';
import '../calendar_repository.dart';
import '../ios_calendar_theme.dart';
import '../models/calendar_list.dart';
import '../widgets/event_card.dart';
import '../widgets/frosted_panel.dart';
import 'calendar_manager_sheet.dart';
import 'day_timeline.dart';
import 'event_detail_sheet.dart';
import 'event_editor_page.dart';

/// 底部三档（iOS 18）：今天 / 日历 / 收件箱。
enum CalendarBottomTab { today, calendar, inbox }

/// iOS 18 风日历页。
///
/// 设计要点（详见 `docs/日历-iOS18改造方案.md`）：
/// - 毛玻璃顶栏（月份导航 + 日历管理 + 新建）；
/// - 月网格支持**双指捏合缩放**：圆点 → 事件条 → 标题+时间；
/// - 日视图 = 吸顶日期头 + 24 小时时间轴 + 全天行 + 提醒事项区；
/// - 事件按所属日历着色；
/// - 底部胶囊切换「今天 / 日历 / 收件箱」。
class IosCalendarPage extends StatefulWidget {
  const IosCalendarPage({super.key});

  @override
  State<IosCalendarPage> createState() => _IosCalendarPageState();
}

class _IosCalendarPageState extends State<IosCalendarPage> {
  final _calendarRepo = CalendarRepository();
  final _scheduleRepo = ScheduleRepository();
  final _toggleService = TodoToggleService();

  final ScrollController _scroll = ScrollController();

  late DateTime _month; // 显示中的月份（1 号）
  late DateTime _selected; // 选中的一天（零点）
  CalendarZoom _zoom = CalendarZoom.dots;
  CalendarBottomTab _tab = CalendarBottomTab.calendar;

  List<CalendarList> _calendars = [];
  Map<String, int> _colors = {};
  Map<DateTime, List<Schedule>> _eventsByDay = {};
  Set<DateTime> _diaryDays = {};
  List<Schedule> _dayEvents = [];
  List<Schedule> _drafts = [];
  List<TodoItem> _todos = [];
  bool _loading = true;
  int _weekStart = 1;

  /// 时间轴行高（每小时的像素高度）：拖动几何与视觉密度都依赖它
  double _hourHeight = 52;

  double _lastScale = 1.0;

  CalendarAgenda get _agenda => buildAgenda(
    day: _selected,
    events: _dayEvents,
    todos: _todos,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selected = DateTime(now.year, now.month, now.day);
    _weekStart = PrefUtil.getValue<int>('calendarWeekStart') ?? 1;
    _hourHeight = PrefUtil.getValue<double>('calendarHourHeight') ?? 52;
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 数据

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);

    final calendars = await _calendarRepo.listAll();
    final colors = {for (final c in calendars) c.id: c.color};
    final visible = calendars.where((c) => c.visible).map((c) => c.id).toSet();

    // 月网格覆盖的范围（含前后补位日）
    final gridDays = monthGridDays(_month.year, _month.month, weekStart: _weekStart);
    final from = gridDays.first;
    final to = gridDays.last.add(const Duration(days: 1));
    final events = (await _scheduleRepo.byRange(from, to))
        .where((e) => !e.deleted && !e.draft && !e.floating)
        .where((e) => e.calendarId == null || visible.contains(e.calendarId))
        .toList();

    final byDay = <DateTime, List<Schedule>>{};
    for (final e in events) {
      for (var d = e.day; !d.isAfter(e.endDay); d = d.add(const Duration(days: 1))) {
        byDay.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(e);
      }
    }

    final diaries = await IsarUtil.getDiariesByDateRange(
      from,
      to.subtract(const Duration(seconds: 1)),
    );
    final diaryDays = {
      for (final Diary d in diaries) DateTime(d.time.year, d.time.month, d.time.day),
    };

    final all = await _scheduleRepo.listActive();
    final drafts = all.where((e) => e.draft && !e.deleted).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final todos = await TodoAggregator.load(date: _selected, includeDone: true);

    if (!mounted) return;
    setState(() {
      _calendars = calendars;
      _colors = colors;
      _eventsByDay = byDay;
      _diaryDays = diaryDays;
      _dayEvents = byDay[_selected] ?? const [];
      _drafts = drafts;
      _todos = todos;
      _loading = false;
    });
    _scheduleAnchor();
  }

  /// 切日 / 拖动落库后刷新：**必须回库重读当天的日程**
  /// （曾经只读 `_eventsByDay` 缓存，导致"已移到 05:00"但卡片不动）。
  Future<void> _reloadDay() async {
    final todos = await TodoAggregator.load(date: _selected, includeDone: true);
    final events = await _visibleEventsOfDay(_selected);
    if (!mounted) return;
    setState(() {
      _dayEvents = events;
      _eventsByDay[_selected] = events; // 同步月格上的圆点/事件条
      _todos = todos;
    });
    _scheduleAnchor();
  }

  Future<List<Schedule>> _visibleEventsOfDay(DateTime day) async {
    final visible = _calendars.where((c) => c.visible).map((c) => c.id).toSet();
    final events = await _scheduleRepo.byDay(day);
    return events
        .where(
          (e) =>
              !e.deleted &&
              !e.draft &&
              !e.floating &&
              (e.calendarId == null || visible.contains(e.calendarId)),
        )
        .toList();
  }

  /// 定位到"现在"或第一个有内容的时段（估计偏移，时间轴是等高的绝对画布）。
  void _scheduleAnchor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final agenda = _agenda;
      final now = DateTime.now();
      final anchorHour = agenda.busyHours.isNotEmpty
          ? agenda.busyHours.reduce((a, b) => a < b ? a : b)
          : (isSameDay(_selected, now) ? now.hour : 8);
      const headerHeight = 46.0;
      final allDayHeight = agenda.allDay.isEmpty
          ? 0.0
          : 26 + agenda.allDay.length * 54;
      final target =
          // 上方留 1.5 小时上下文，避免首个日程贴在吸顶日期头底下
          headerHeight + allDayHeight + (anchorHour - 1.5) * _hourHeight;
      _scroll.animateTo(
        target.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _selectDay(DateTime day) async {
    final d = DateTime(day.year, day.month, day.day);
    final monthChanged = d.year != _month.year || d.month != _month.month;
    setState(() {
      _selected = d;
      if (monthChanged) _month = DateTime(d.year, d.month, 1);
    });
    if (monthChanged) {
      await _reload();
    } else {
      await _reloadDay();
    }
  }

  Future<void> _shiftMonth(int delta) async {
    final m = DateTime(_month.year, _month.month + delta, 1);
    setState(() => _month = m);
    await _reload();
  }

  Future<void> _goToday() async {
    final now = DateTime.now();
    setState(() {
      _tab = CalendarBottomTab.today;
      _selected = DateTime(now.year, now.month, now.day);
      _month = DateTime(now.year, now.month, 1);
    });
    await _reload();
  }

  Future<void> _toggleTodo(TodoItem item) async {
    await _toggleService.toggle(item);
    await _reloadDay();
  }

  Color _colorOf(Schedule e) =>
      IosCalendarTheme.colorOf(e.calendarId, _colors, Theme.of(context).colorScheme);

  // ---------------------------------------------------------------- 交互

  Future<void> _openEditor({Schedule? event, DateTime? day}) async {
    final created = await Get.to<bool>(
      () => EventEditorPage(
        event: event,
        initialDay: day ?? _selected,
        calendars: _calendars,
      ),
    );
    if (created == true) await _reload();
  }

  /// 拖动出的时间段 → 直接进编辑器（预填起止 + 自动聚焦标题）。
  Future<void> _createFromRange(DateTime start, DateTime end) async {
    final created = await Get.to<bool>(
      () => EventEditorPage(
        initialStart: start,
        initialEnd: end,
        autofocusTitle: true,
        calendars: _calendars,
      ),
    );
    if (created == true) await _reload();
  }

  /// 点事件卡 → 详情面板（可编辑/复制/删除）。
  Future<void> _openDetail(Schedule event) async {
    final color = _colorOf(event);
    final result = await showEventDetailSheet(
      context,
      event: event,
      color: color,
      calendarName: _calendarNameOf(event),
    );
    if (!mounted || result == null) return;
    if (result == EventDetailResult.edit) {
      await _openEditor(event: event);
    } else {
      await _reload();
    }
  }

  String _calendarNameOf(Schedule e) {
    final id = e.calendarId;
    for (final c in _calendars) {
      if (c.id == id) return c.name;
    }
    return _calendars.isEmpty ? '默认日历' : _calendars.first.name;
  }

  /// 长按拖动移动事件：保持时长，只改起始时间（15 分钟吸附，已由时间轴算好）。
  Future<void> _moveEvent(Schedule event, DateTime newStart) async {
    final duration = event.endTime == null
        ? const Duration(hours: 1)
        : event.endTime!.difference(event.startTime);
    final oldStart = event.startTime;
    final oldEnd = event.endTime;
    final moved = event.clone()
      ..startTime = newStart
      ..endTime = oldEnd == null ? null : newStart.add(duration);
    await _scheduleRepo.update(moved);
    if (mounted) await _reloadDay();
    _toastUndo(
      '已移到 ${fmtClock(moved.startTime)}',
      () async {
        final back = moved.clone()
          ..startTime = oldStart
          ..endTime = oldEnd;
        await _scheduleRepo.update(back);
        if (mounted) await _reloadDay();
      },
    );
  }

  /// 长按拖底部手柄改结束时间。
  Future<void> _resizeEvent(Schedule event, DateTime newEnd) async {
    final oldEnd = event.endTime;
    final resized = event.clone()..endTime = newEnd;
    await _scheduleRepo.update(resized);
    if (mounted) await _reloadDay();
    _toastUndo(
      '${event.title} 改为 ${eventTimeLabel(resized)}',
      () async {
        final back = resized.clone()..endTime = oldEnd;
        await _scheduleRepo.update(back);
        if (mounted) await _reloadDay();
      },
    );
  }

  void _toastUndo(String message, Future<void> Function() undo) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: '撤销', onPressed: () => undo()),
        ),
      );
  }

  Future<void> _openManager() async {
    await showCalendarManagerSheet(context);
    if (mounted) await _reload();
  }

  /// 收件箱草案 → 加入日历。
  Future<void> _acceptDraft(Schedule draft) async {
    final fallback = await _calendarRepo.defaultCalendar();
    final saved = draft.clone()
      ..draft = false
      ..calendarId = draft.calendarId ?? fallback?.id;
    await _scheduleRepo.update(saved);
    if (!mounted) return;
    toast.success(message: '已加入日历');
    await _reload();
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<(int, int)>(
      context: context,
      builder: (_) => _MonthYearPickerDialog(
        initialYear: _month.year,
        initialMonth: _month.month,
      ),
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.$1, picked.$2, 1));
    await _reload();
  }

  void _onScaleStart(ScaleStartDetails details) => _lastScale = 1.0;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) {
      _lastScale = details.scale;
      return;
    }
    final ratio = details.scale / _lastScale;
    final next = zoomAfterPinch(_zoom, ratio);
    if (next != _zoom) {
      _lastScale = details.scale;
      setState(() => _zoom = next);
    }
  }

  void _cycleZoom() => setState(() {
    const levels = CalendarZoom.values;
    _zoom = levels[(levels.indexOf(_zoom) + 1) % levels.length];
  });

  // ---------------------------------------------------------------- 视图

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _topBar(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _loading && _calendars.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _tab == CalendarBottomTab.inbox
                      ? _inboxBody()
                      : _dayBody(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(child: _bottomPill()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FrostedTopBar(
      child: Row(
        children: [
          _barIcon(
            tooltip: '上一月',
            icon: Icons.chevron_left_rounded,
            onPressed: () => _shiftMonth(-1),
          ),
          InkWell(
            onTap: _pickMonth,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Text(
                    _tab == CalendarBottomTab.today
                        ? dayLabel(_selected)
                        : '${_month.year}年${_month.month}月',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          _barIcon(
            tooltip: '下一月',
            icon: Icons.chevron_right_rounded,
            onPressed: () => _shiftMonth(1),
          ),
          const Spacer(),
          _barIcon(
            tooltip: '缩放档位：${_zoomLabel()}（可双指捏合）',
            icon: switch (_zoom) {
              CalendarZoom.dots => Icons.more_horiz_rounded,
              CalendarZoom.bars => Icons.drag_handle_rounded,
              CalendarZoom.titles => Icons.view_agenda_rounded,
            },
            onPressed: _cycleZoom,
          ),
          PopupMenuButton<double>(
            tooltip: '时间轴行高',
            icon: const Icon(Icons.height_rounded),
            initialValue: _hourHeight,
            onSelected: (v) {
              setState(() => _hourHeight = v);
              PrefUtil.setValue<double>('calendarHourHeight', v);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 40.0, child: Text('紧凑（每小时 40）')),
              PopupMenuItem(value: 52.0, child: Text('标准（每小时 52）')),
              PopupMenuItem(value: 84.0, child: Text('宽松（每小时 84）')),
            ],
          ),
          _barIcon(
            tooltip: '日历管理',
            icon: Icons.calendar_month_rounded,
            onPressed: _openManager,
          ),
          _barIcon(
            tooltip: '新建事件',
            icon: Icons.add_circle_outline_rounded,
            color: scheme.primary,
            onPressed: () => _openEditor(day: _selected),
          ),
        ],
      ),
    );
  }

  /// 顶栏图标按钮：紧凑密度（手机上要放下 6 个按钮 + 月份标题）。
  Widget _barIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
    );
  }

  String _zoomLabel() => switch (_zoom) {
    CalendarZoom.dots => '圆点',
    CalendarZoom.bars => '事件条',
    CalendarZoom.titles => '标题时间',
  };

  Widget _dayBody() {
    final grid = _tab == CalendarBottomTab.today
        ? _weekStrip()
        : _monthGrid();
    // 月网格必须放在任何滚动视图**外面**：放进 CustomScrollView /
    // SingleChildScrollView 时，滚动的拖拽识别器会赢下手势竞技场，
    // 双指捏合永远收不到回调（已用最小用例复现）。
    // 因此三档高度按「整屏也放得下」来设计（见 _DayCell 的尺寸推导）。
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: grid,
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _DayHeaderDelegate(
                  day: _selected,
                  colors: _colors,
                  calendars: _calendars,
                  agenda: _agenda,
                ),
              ),
              ..._agendaSlivers(),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _agendaSlivers() {
    final agenda = _agenda;
    final slivers = <Widget>[];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (agenda.allDay.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 8, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '全天',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                for (final e in agenda.allDay)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: CalendarEventCard(
                      event: e,
                      color: _colorOf(e),
                      onTap: () => _openEditor(event: e),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final isToday = isSameDay(_selected, now);

    // 24 小时时间轴：绝对定位画布（长按拖动新建/移动/改时长都在这里）
    slivers.add(
      SliverToBoxAdapter(
        child: DayTimeline(
          key: ValueKey('timeline-${_selected.toIso8601String()}'),
          day: _selected,
          events: _dayEvents,
          colorOf: _colorOf,
          hourHeight: _hourHeight,
          showNowLine: isToday,
          markers: [
            for (final entry in agenda.todosByHour.entries)
              for (final t in entry.value)
                TimelineMarker(
                  at: t.dueDate ?? t.time,
                  text: t.text,
                  done: t.done,
                  onToggle: () => _toggleTodo(t),
                ),
          ],
          onTapEvent: _openDetail,
          onCreateRange: _createFromRange,
          onMoveEvent: _moveEvent,
          onResizeEvent: _resizeEvent,
        ),
      ),
    );

    slivers.add(
      SliverToBoxAdapter(
        child: _reminderSection(),
      ),
    );
    return slivers;
  }

  Widget _reminderSection() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = _agenda.untimedTodos;
    return Container(
      margin: const EdgeInsets.fromLTRB(52, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(IosCalendarTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 2),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  '提醒事项',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
              child: Text(
                '这一天没有提醒事项',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final t in items)
              ReminderRow(
                text: t.text,
                done: t.done,
                color: scheme.primary,
                onToggle: () => _toggleTodo(t),
              ),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    final days = weekDays(_selected, weekStart: _weekStart);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: _DayCell(
                day: d,
                zoom: CalendarZoom.dots,
                inMonth: true,
                selected: isSameDay(d, _selected),
                events: _eventsByDay[d] ?? const [],
                colorOf: _colorOf,
                hasDiary: _diaryDays.contains(d),
                onTap: () => _selectDay(d),
                onLongPress: () => _openEditor(day: d),
                compact: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthGrid() {
    final theme = Theme.of(context);
    final days = monthGridDays(_month.year, _month.month, weekStart: _weekStart);
    final labels = [
      for (var i = 0; i < 7; i++)
        switch ((_weekStart - 1 + i) % 7) {
          0 => '一',
          1 => '二',
          2 => '三',
          3 => '四',
          4 => '五',
          5 => '六',
          _ => '日',
        },
    ];
    return Container(
      key: const ValueKey('calendar-grid'),
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(IosCalendarTheme.panelRadius),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in labels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < days.length; i += 7)
            Row(
              children: [
                for (var j = 0; j < 7; j++)
                  Expanded(
                    child: _DayCell(
                      day: days[i + j],
                      zoom: _zoom,
                      inMonth:
                          days[i + j].month == _month.month &&
                          days[i + j].year == _month.year,
                      selected: isSameDay(days[i + j], _selected),
                      events: _eventsByDay[days[i + j]] ?? const [],
                      colorOf: _colorOf,
                      hasDiary: _diaryDays.contains(days[i + j]),
                      onTap: () => _selectDay(days[i + j]),
                      onLongPress: () => _openEditor(day: days[i + j]),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _bottomPill() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FrostedPanel(
      radius: IosCalendarTheme.pillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shadow: IosCalendarTheme.softShadow(scheme),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pillItem('今天', CalendarBottomTab.today, () => _goToday()),
          _pillItem(
            '日历',
            CalendarBottomTab.calendar,
            () => setState(() => _tab = CalendarBottomTab.calendar),
          ),
          _pillItem(
            '收件箱',
            CalendarBottomTab.inbox,
            () => setState(() => _tab = CalendarBottomTab.inbox),
          ),
        ],
      ),
    );
  }

  Widget _pillItem(String label, CalendarBottomTab tab, VoidCallback onTap) {
    final theme = Theme.of(context);
    final selected = _tab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IosCalendarTheme.pillRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(IosCalendarTheme.pillRadius),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inboxBody() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_drafts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 52,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              '收件箱是空的',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'AI 从笔记/邮件里识别出的日程建议会先到这里',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Text('待确认的日程建议', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final d in _drafts)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                Icons.auto_awesome_rounded,
                color: scheme.primary,
              ),
              title: Text(d.title),
              subtitle: Text(
                '${dayLabel(d.startTime)} · ${eventTimeLabel(d)}'
                '${(d.location ?? '').isEmpty ? '' : ' · ${d.location}'}',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _acceptDraft(d),
                child: const Text('加入日历'),
              ),
              onTap: () => _openEditor(event: d),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 子组件

/// 月格单元：日期数字 + 活跃度/事件（按缩放档位变化）。
class _DayCell extends StatelessWidget {
  final DateTime day;
  final CalendarZoom zoom;
  final bool inMonth;
  final bool selected;
  final List<Schedule> events;
  final Color Function(Schedule) colorOf;
  final bool hasDiary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool compact;

  const _DayCell({
    required this.day,
    required this.zoom,
    required this.inMonth,
    required this.selected,
    required this.events,
    required this.colorOf,
    required this.hasDiary,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = isSameDay(day, DateTime.now());

    final Color fg = selected
        ? (isToday ? Colors.white : scheme.onPrimaryContainer)
        : isToday
        ? IosCalendarTheme.today
        : inMonth
        ? scheme.onSurface
        : scheme.outline;

    final Color? bg = selected
        ? (isToday ? IosCalendarTheme.today : scheme.primaryContainer)
        : null;

    final showBars = zoom != CalendarZoom.dots;
    final showTitle = zoom == CalendarZoom.titles;
    final maxBars = showTitle ? 2 : (compact ? 1 : 3);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: showTitle ? 4 : 3,
          horizontal: 1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
              child: Text(
                '${day.day}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: (isToday || selected) ? FontWeight.w600 : null,
                  fontSize: 14,
                ),
              ),
            ),
            if (!showBars)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in events.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorOf(e),
                            ),
                          ),
                        ),
                      if (hasDiary)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2EB872),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  children: [
                    for (final e in events.take(maxBars))
                      CalendarEventBar(
                        event: e,
                        color: colorOf(e),
                        showTitle: showTitle,
                        onTap: onTap,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 吸顶日期头（SliverPersistentHeader）。
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime day;
  final Map<String, int> colors;
  final List<CalendarList> calendars;
  final CalendarAgenda agenda;

  _DayHeaderDelegate({
    required this.day,
    required this.colors,
    required this.calendars,
    required this.agenda,
  });

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final relative = relativeDayLabel(day);
    final count = agenda.timedEvents.length + agenda.allDay.length;
    return Container(
      height: 46,
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            dayLabel(day),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSameDay(day, DateTime.now())
                  ? IosCalendarTheme.today
                  : scheme.onSurface,
            ),
          ),
          if (relative.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (isSameDay(day, DateTime.now())
                        ? IosCalendarTheme.today
                        : scheme.primary)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                relative,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSameDay(day, DateTime.now())
                      ? IosCalendarTheme.today
                      : scheme.primary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (count > 0)
            Text(
              '$count 个日程',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate old) =>
      old.day != day ||
      old.colors != colors ||
      old.calendars.length != calendars.length ||
      old.agenda.day != agenda.day;
}

/// 年/月选择（点顶栏月份标题）。
class _MonthYearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;

  const _MonthYearPickerDialog({
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year = widget.initialYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _year--),
          ),
          Expanded(
            child: Center(
              child: Text('$_year年', style: theme.textTheme.titleLarge),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setState(() => _year++),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            for (var m = 1; m <= 12; m++)
              InkWell(
                onTap: () => Navigator.of(context).pop((_year, m)),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        (_year == widget.initialYear && m == widget.initialMonth)
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$m月'),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
