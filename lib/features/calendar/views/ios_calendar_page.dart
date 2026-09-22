import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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
import 'agenda_list_view.dart';
import 'event_detail_sheet.dart';
import 'event_editor_page.dart';
import 'quick_actions.dart';
import 'week_view.dart';

/// 底部三档（iOS 18）：今天 / 日历 / 收件箱。
enum CalendarBottomTab { today, calendar, inbox }

/// 视图模式：**日（两日时间线）/ 月 / 列表**。
///
/// 原来的「周」与「日」重复，已合并：日视图一次显示两天，左右滑动换日期，
/// 顶部日期头随页面一起滑（见 `_twoDayBody`）。
enum CalendarViewMode { day, month, list }

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
  CalendarViewMode _viewMode = CalendarViewMode.month;

  /// PC 端右侧检查器当前展示的事件（空 = 不显示检查器）
  Schedule? _inspected;

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

  /// 日视图「整日概览」：把 24 小时压进一屏，完整看到一整天
  bool _fitWholeDay = true;

  /// 当前时间轴实际使用的每小时像素（整日概览时会变小，定位要用同一个值）
  double _timelineHourHeight = 52;

  /// 时间轴视口（自动滚动与捏合缩放要用它的矩形）
  final GlobalKey _timelineViewportKey = GlobalKey();

  /// 双指捏合改时间轴行高（原始指针自己算：不跟滚动视图抢手势竞技场）
  final Map<int, Offset> _pointers = {};
  double? _pinchBaseSpan;
  double _pinchBaseHeight = 52;

  /// 时间轴行高的实时值：捏合时只动这个 notifier，
  /// 避免在指针派发过程中重建整棵子树（会触发 RenderObject 已释放的断言）。
  final ValueNotifier<double> _hourHeightLive = ValueNotifier<double>(52);

  /// 「整日概览」开合的实时值：同样用 notifier，捏合时不在指针派发中 setState
  final ValueNotifier<bool> _fitWholeDayLive = ValueNotifier<bool>(true);
  double _pendingHourHeight = 52;
  bool _heightCommitScheduled = false;

  /// 日视图（两日）分页：以 2020-01-01 为锚，一页两天
  static final DateTime _pagerEpoch = DateTime(2020, 1, 1);
  final PageController _pager = PageController(
    initialPage: (DateTime.now().difference(_pagerEpoch).inDays / 2).floor(),
  );

  /// 切换视图档位时的浮层提示（对齐 iOS：捏合后短暂显示模式名）
  String? _modeHud;
  Timer? _modeHudTimer;

  /// 月格是否折叠成「周」条（单指上下滑动切换）
  bool _weekMode = false;

  /// 月格里正在拖动的事件与悬停的目标日
  Schedule? _gridDragEvent;
  DateTime? _gridDragHover;
  final GlobalKey _gridBodyKey = GlobalKey();

  double _lastScale = 1.0;

  // 月格单指上下滑动切月的原始指针跟踪
  Offset? _swipeFrom;
  DateTime? _swipeAt;
  bool _swipeMultiTouch = false;

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
    _hourHeightLive.value = _hourHeight;
    _viewMode = CalendarViewMode.values.firstWhere(
      (m) => m.name == PrefUtil.getValue<String>('calendarViewMode'),
      orElse: () => CalendarViewMode.month,
    );
    _fitWholeDay = PrefUtil.getValue<bool>('calendarFitWholeDay') ?? true;
    _fitWholeDayLive.value = _fitWholeDay;
    _reload();
  }

  @override
  void dispose() {
    _modeHudTimer?.cancel();
    _pager.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showModeHud(String label) {
    _modeHudTimer?.cancel();
    setState(() => _modeHud = label);
    _modeHudTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _modeHud = null);
    });
  }

  /// 月格三档的苹果叫法：紧凑（点阵）/ 叠放（色条）/ 详细信息（标题时间）
  String _zoomTierLabel(CalendarZoom zoom) => switch (zoom) {
    CalendarZoom.dots => '紧凑',
    CalendarZoom.bars => '叠放',
    CalendarZoom.titles => '详细信息',
  };

  // ---------------------------------------------------------------- 数据

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);

    final calendars = await _calendarRepo.listAll();
    final colors = {for (final c in calendars) c.id: c.color};
    final visible = calendars.where((c) => c.visible).map((c) => c.id).toSet();

    // 一次把「月格 + 当前周 + 列表滚动窗口(前 7 天 ~ 后 60 天)」都装进来
    final gridDays = monthGridDays(_month.year, _month.month, weekStart: _weekStart);
    final week = weekDays(_selected, weekStart: _weekStart);
    final today = DateTime.now();
    final candidates = <DateTime>[
      gridDays.first,
      week.first,
      today.subtract(const Duration(days: 7)),
    ];
    final ends = <DateTime>[
      gridDays.last,
      week.last,
      today.add(const Duration(days: 60)),
    ];
    final from = candidates.reduce((a, b) => a.isBefore(b) ? a : b);
    final to = ends
        .reduce((a, b) => a.isAfter(b) ? a : b)
        .add(const Duration(days: 1));
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
      // AnimatedSwitcher 过渡期间会同时挂着两个 ScrollView，
      // 这时用同一个 controller 定位会命中"一控多视图"的断言
      if (!mounted || _scroll.positions.length != 1) return;
      final agenda = _agenda;
      final now = DateTime.now();
      final anchorHour = agenda.busyHours.isNotEmpty
          ? agenda.busyHours.reduce((a, b) => a < b ? a : b)
          : (isSameDay(_selected, now) ? now.hour : 8);
      const headerHeight = 46.0;
      final allDayHeight = agenda.allDay.isEmpty
          ? 0.0
          : 26 + agenda.allDay.length * 54;
      // 日视图「整日概览」：一整天已经压在一屏里，直接回到 00:00 顶部
      // （只有当天真有日程时才滚到第一条，方便一眼看到事）
      if (_compactDayFit) {
        // 一整天已经压进视口 → 直接回到顶部，保证 00:00 可见
        const target = 0.0;
        final clamped = target.clamp(0.0, _scroll.position.maxScrollExtent);
        if ((_scroll.offset - clamped).abs() > 1) {
          _scroll.jumpTo(clamped);
        }
        return;
      }
      final target =
          // 上方留 1.5 小时上下文，避免首个日程贴在吸顶日期头底下
          headerHeight + allDayHeight + (anchorHour - 1.5) * _timelineHourHeight;
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
    // 日视图（两日）同步翻到对应页
    if (_viewMode == CalendarViewMode.day && _pager.hasClients) {
      _syncPagerTo(d);
    }
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
    _syncPagerTo(_selected);
    await _reload();
  }

  /// 日视图（两日）翻到包含 [day] 的那一页。
  void _syncPagerTo(DateTime day) {
    if (_viewMode != CalendarViewMode.day || !_pager.hasClients) return;
    final target = _pagerPageFor(day);
    if ((_pager.page ?? target).round() != target) {
      _pager.jumpToPage(target);
    }
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
    // PC：走右侧检查器（像 Mac 日历），不弹底部面板
    if (_isDesktop) {
      setState(() => _inspected = event);
      return;
    }
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

  /// 智能新建：自然语言 → 预填编辑器（确认后才落库）。
  Future<void> _openSmartAdd() async {
    final parsed = await showSmartAddDialog(context);
    if (parsed == null || !mounted) return;
    final created = await Get.to<bool>(
      () => EventEditorPage(
        initialStart: parsed.start,
        initialEnd: parsed.end,
        initialDay: parsed.start ?? _selected,
        initialTitle: parsed.title.isEmpty ? null : parsed.title,
        initialLocation: parsed.location,
        autofocusTitle: parsed.title.isEmpty,
        calendars: _calendars,
      ),
    );
    if (created == true) await _reload();
  }

  /// 搜索日程 → 跳到那天并打开详情。
  Future<void> _openSearch() async {
    final hit = await showEventSearchSheet(context);
    if (hit == null || !mounted) return;
    await _selectDay(hit.startTime);
    if (!mounted) return;
    await _openDetail(hit);
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
    // 月格上捏合 = 在 列表 ↔ 月 ↔ 日 之间切换（对齐 iOS 18 连续缩放）
    if (ratio > 1.15) {
      final next = _stepMode(1);
      if (next != null) {
        _lastScale = details.scale;
        _setViewMode(next);
      }
    } else if (ratio < 0.87) {
      final next = _stepMode(-1);
      if (next != null) {
        _lastScale = details.scale;
        _setViewMode(next);
      }
    }
  }

  /// 视图详细程度阶梯：列表 → 月 → 日
  static const List<CalendarViewMode> _modeLadder = [
    CalendarViewMode.list,
    CalendarViewMode.month,
    CalendarViewMode.day,
  ];

  CalendarViewMode? _stepMode(int delta) {
    final index = _modeLadder.indexOf(_viewMode);
    final next = index + delta;
    if (index < 0 || next < 0 || next >= _modeLadder.length) return null;
    return _modeLadder[next];
  }

  // ------------------------------------------------ 月格：单指上下滑动切月/周

  void _swipeDown(PointerDownEvent e) {
    if (_swipeFrom != null) {
      _swipeMultiTouch = true; // 第二根手指落下 → 交给捏合
      return;
    }
    _swipeFrom = e.position;
    _swipeAt = DateTime.now();
    _swipeMultiTouch = false;
  }

  void _swipeMove(PointerMoveEvent e) {}

  void _swipeUp(PointerUpEvent e) {
    final from = _swipeFrom;
    final at = _swipeAt;
    final multi = _swipeMultiTouch;
    _swipeFrom = null;
    _swipeAt = null;
    _swipeMultiTouch = false;
    if (from == null || at == null || multi) return;
    if (_gridDragEvent != null) return; // 正在拖事件，不当成滑动
    final dy = e.position.dy - from.dy;
    final dx = (e.position.dx - from.dx).abs();
    final fast = DateTime.now().difference(at).inMilliseconds < 400;
    if (!fast || dx > 40 || dy.abs() < 40) return;
    setState(() {
      if (dy < 0 && !_weekMode) {
        _weekMode = true; // 上滑：收起成周
      } else if (dy > 0 && _weekMode) {
        _weekMode = false; // 下滑：展开成月
      }
    });
  }

  // ------------------------------------------- 时间轴：双指捏合改行高（40–120）

  double _spanOfPointers() {
    final pts = _pointers.values.toList();
    if (pts.length < 2) return 0;
    return (pts[0] - pts[1]).distance;
  }

  void _pinchDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _pinchBaseSpan = _spanOfPointers();
      _pinchBaseHeight = _hourHeight;
    }
  }

  void _pinchMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final baseSpan = _pinchBaseSpan;
    if (baseSpan == null || baseSpan <= 0 || _pointers.length < 2) return;
    final factor = _spanOfPointers() / baseSpan;
    if (factor.isNaN || factor <= 0) return;
    final next = (_pinchBaseHeight * factor).clamp(24.0, 120.0);
    if ((next - _hourHeightLive.value).abs() < 1) return;
    // 手动捏合 = 用户自己定密度，退出「整日概览」（只改 notifier，避免派发中重建）
    if (_fitWholeDayLive.value) {
      _fitWholeDayLive.value = false;
      _fitWholeDay = false;
      PrefUtil.setValue<bool>('calendarFitWholeDay', false);
    }
    _hourHeight = next;
    // 关键：不在指针派发过程中重建时间轴（否则命中记录会被释放 → 框架断言），
    // 延到下一帧再提交。
    _pendingHourHeight = next;
    if (!_heightCommitScheduled) {
      _heightCommitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _heightCommitScheduled = false;
        _hourHeightLive.value = _pendingHourHeight;
        PrefUtil.setValue<double>(
          'calendarHourHeight',
          _pendingHourHeight.roundToDouble(),
        );
      });
    }
  }

  void _pinchUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchBaseSpan = null;
  }

  // ---------------------------------------------------------------- 视图

  @override
  Widget build(BuildContext context) {
    // 日历页套一层 iOS 色系（主色 #007AFF/#0A84FF、次级文字、分隔线按文档 Token）
    final themed = IosCalendarTheme.scoped(Theme.of(context));
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Theme(
      data: themed,
      child: isDesktop ? _desktopLayout() : _phoneLayout(),
    );
  }

  Widget _phoneLayout() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _topBar(),
          Expanded(
            child: Stack(
              children: [
                // 说明：这里刻意不用 AnimatedSwitcher —— 过渡期两棵子树会同时
                // 持有同一个 ScrollController（时间轴），触发"一控多视图"断言。
                // 视图切换的淡入交给各视图内部的 AnimatedSize/AnimatedContainer。
                Positioned.fill(child: _bodyForMode()),
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(child: _modeHudBadge()),
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

  bool get _isDesktop => MediaQuery.sizeOf(context).width >= 900;

  /// 「整日概览」是否正在生效（只有日视图会压屏）
  bool get _compactDayFit =>
      _viewMode == CalendarViewMode.day && _fitWholeDay;

  // ------------------------------------------------------------ PC 三栏布局

  /// PC（宽屏）：侧边栏（迷你月 + 日历勾选） + 主区 + 右侧检查器。
  Widget _desktopLayout() {
    final inspected = _inspected;
    // ESC 收起右侧检查器（文档 §4.4）
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _inspected != null) {
          setState(() => _inspected = null);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SafeArea(
        child: Row(
        children: [
          // 侧边栏 240 / 详情 320（对齐需求文档 §4.1）
          SizedBox(width: IosCalendarTheme.sidebarWidth, child: _sidebar()),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _bodyForMode()),
                      Positioned(
                        top: 6,
                        left: 0,
                        right: 0,
                        child: Center(child: _modeHudBadge()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (inspected != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: IosCalendarTheme.detailPanelWidth,
              child: _inspector(inspected),
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _sidebar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 迷你月
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Text(
                  '${_month.year}年${_month.month}月',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '上一月',
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _shiftMonth(-1),
                ),
                IconButton(
                  tooltip: '下一月',
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
          ),
          _miniMonth(),
          const Divider(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
            child: Row(
              children: [
                Text('我的日历', style: theme.textTheme.labelMedium),
                const Spacer(),
                IconButton(
                  tooltip: '新建日历',
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _openManager,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final c in _calendars)
                  InkWell(
                    onTap: () async {
                      await _calendarRepo.setVisible(c.id, !c.visible);
                      await _reload();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: c.visible,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (_) async {
                              await _calendarRepo.setVisible(c.id, !c.visible);
                              await _reload();
                            },
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 2, right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(c.color),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              c.name,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.isShared)
                            Icon(
                              Icons.people_alt_outlined,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              '提示：点日历改显示/隐藏；「列表」视图会把这些日历的日程按天排好。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMonth() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = monthGridDays(_month.year, _month.month, weekStart: _weekStart);
    final labels = ['一', '二', '三', '四', '五', '六', '日'];
    final orderedLabels = [
      for (var i = 0; i < 7; i++) labels[(_weekStart - 1 + i) % 7],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final l in orderedLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var i = 0; i < days.length; i += 7)
            Row(
              children: [
                for (var j = 0; j < 7; j++)
                  Expanded(
                    child: _MiniDay(
                      day: days[i + j],
                      inMonth: days[i + j].month == _month.month,
                      selected: isSameDay(days[i + j], _selected),
                      hasEvent: (_eventsByDay[days[i + j]] ?? const []).isNotEmpty,
                      onTap: () => _selectDay(days[i + j]),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _inspector(Schedule event) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
            child: Row(
              children: [
                Text('日程详情', style: theme.textTheme.labelLarge),
                const Spacer(),
                IconButton(
                  tooltip: '关闭',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _inspected = null),
                ),
              ],
            ),
          ),
          Expanded(
            child: EventDetailContent(
              event: event,
              color: _colorOf(event),
              calendarName: _calendarNameOf(event),
              showHint: false,
              onEdit: () => _openEditor(event: event),
              onCopy: () async {
                final copied = event.clone()
                  ..id = ''
                  ..title = '${event.title}（副本）';
                await _scheduleRepo.create(copied);
                if (mounted) await _reload();
              },
              onDelete: () async {
                await _scheduleRepo.softDelete(event.id);
                if (!mounted) return;
                setState(() => _inspected = null);
                await _reload();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 手机端：顶栏 + 模式条 + 内容（底部胶囊悬浮）。
  Widget _bodyForMode() {
    if (_loading && _calendars.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tab == CalendarBottomTab.inbox) return _inboxBody();
    return switch (_viewMode) {
      CalendarViewMode.day => _twoDayBody(),
      CalendarViewMode.month => _dayBody(showMonthGrid: true),
      CalendarViewMode.list => _listBody(),
    };
  }

  int _pagerPageFor(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return (d.difference(_pagerEpoch).inDays / 2).floor();
  }

  DateTime _pagerStartFor(int page) =>
      _pagerEpoch.add(Duration(days: page * 2));

  /// 日视图＝**两天时间线**：左右滑动换日期，顶部日期头随页一起滑。
  Widget _twoDayBody() {
    final width = MediaQuery.sizeOf(context).width;
    final columnWidth = (width - 44) / 2;
    final visibleIds = _calendars
        .where((c) => c.visible)
        .map((c) => c.id)
        .toSet();
    return Listener(
      onPointerDown: _pinchDown,
      onPointerMove: _pinchMoveToMonth,
      onPointerUp: _pinchUp,
      onPointerCancel: _pinchUp,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 让掉两日视图自己的日期头 + 底部悬浮胶囊，保证 00:00–24:00 一屏可见
          final fit = ((constraints.maxHeight - 280) / 24).clamp(14.0, 60.0);
          final hourHeight = _fitWholeDayLive.value ? fit : _hourHeightLive.value;
          return PageView.builder(
            controller: _pager,
            onPageChanged: (page) {
              final start = _pagerStartFor(page);
              if (!isSameDay(start, _selected)) {
                setState(() => _selected = start);
                _reloadDay();
              }
            },
            itemBuilder: (context, page) {
              final start = _pagerStartFor(page);
              final days = [start, start.add(const Duration(days: 1))];
              return WeekView(
                days: days,
                eventsByDay: {
                  for (final day in days)
                    day: (_eventsByDay[day] ?? const <Schedule>[])
                        .where(
                          (e) =>
                              !e.deleted &&
                              !e.draft &&
                              (e.calendarId == null ||
                                  visibleIds.contains(e.calendarId)),
                        )
                        .toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime)),
                },
                colorOf: _colorOf,
                selectedDay: _selected,
                hourHeight: hourHeight,
                columnWidth: columnWidth,
                onTapEvent: _openDetail,
                onSelectDay: (day) => _selectDay(day),
                onCreateRange: (day, s, e) async {
                  await _selectDay(day);
                  if (mounted) await _createFromRange(s, e);
                },
              );
            },
          );
        },
      ),
    );
  }

  /// 日视图里捏合收拢 → 回月视图（展开已是最详细档，保持不动）。
  void _pinchMoveToMonth(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final baseSpan = _pinchBaseSpan;
    if (baseSpan == null || baseSpan <= 0 || _pointers.length < 2) return;
    final factor = _spanOfPointers() / baseSpan;
    if (factor.isNaN || factor <= 0) return;
    if (factor < 0.85) {
      _pinchBaseSpan = null;
      _setViewMode(CalendarViewMode.month);
    }
  }

  /// 视图模式条（日 / 周 / 月 / 列表）——手机与 PC 共用。
  Widget _modeHudBadge() {
    final label = _modeHud;
    if (label == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 多日（周）视图。
  /// 列表视图：往后 60 天的日程清单。
  Widget _listBody() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 7));
    final visibleIds = _calendars
        .where((c) => c.visible)
        .map((c) => c.id)
        .toSet();
    final days = [
      for (var i = 0; i < 68; i++) start.add(Duration(days: i)),
    ];
    final byDay = <DateTime, List<Schedule>>{};
    for (final entry in _eventsByDay.entries) {
      final events = entry.value
          .where(
            (e) =>
                !e.deleted &&
                !e.draft &&
                !e.floating &&
                (e.calendarId == null || visibleIds.contains(e.calendarId)),
          )
          .toList();
      if (events.isEmpty) continue;
      byDay[DateTime(entry.key.year, entry.key.month, entry.key.day)] = events
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    // 列表视图 = 紧凑月格（点阵）+ 日程清单（对齐文档：列表视图 = 点阵 + 清单）
    return Column(
      children: [
        _monthGrid(),
        Expanded(
          child: AgendaListView(
            days: days,
            eventsByDay: byDay,
            colorOf: _colorOf,
            onTapEvent: _openDetail,
            onTapDay: (day) => _selectDay(day),
          ),
        ),
      ],
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
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Row(
                children: [
                  Text(
                    _tab == CalendarBottomTab.today
                        ? dayLabel(_selected)
                        : '${_month.year}年${_month.month}月',
                    style: theme.textTheme.titleSmall?.copyWith(
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
          // 视图模式：一个按钮菜单（日=两日时间线 / 月 / 列表），捏合也能切
          _modeButton(scheme),
          _barIcon(
            tooltip: '智能新建（说人话建日程）',
            icon: Icons.auto_awesome_rounded,
            color: scheme.primary,
            onPressed: _openSmartAdd,
          ),
          _barIcon(
            tooltip: '搜索日程',
            icon: Icons.search_rounded,
            onPressed: _openSearch,
          ),
          // 视图与日历管理收进「更多」，避免顶栏挤爆（iOS 也是这个思路）
          _viewMenu(scheme),
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
      constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
    );
  }

  String get _viewModeLabel => switch (_viewMode) {
    CalendarViewMode.day => '日',
    CalendarViewMode.month => '月',
    CalendarViewMode.list => '列表',
  };

  /// 顶栏的视图模式按钮：一个按钮搞定日/月/列表（原来整行模式条已移除）。
  Widget _modeButton(ColorScheme scheme) {
    final theme = Theme.of(context);
    return PopupMenuButton<CalendarViewMode>(
      tooltip: '视图模式（可双指捏合切换）',
      onSelected: (mode) => _setViewMode(mode),
      itemBuilder: (_) => [
        for (final mode in CalendarViewMode.values)
          CheckedPopupMenuItem(
            value: mode,
            checked: _viewMode == mode,
            child: Text(
              switch (mode) {
                CalendarViewMode.day => '日（两天时间线）',
                CalendarViewMode.month => '月',
                CalendarViewMode.list => '列表',
              },
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _viewModeLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _setViewMode(CalendarViewMode mode) {
    if (_viewMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() => _viewMode = mode);
    PrefUtil.setValue<String>('calendarViewMode', mode.name);
    _showModeHud(_viewModeLabel);
  }

  Widget _viewMenu(ColorScheme scheme) {
    return PopupMenuButton<String>(
      tooltip: '视图与日历',
      icon: Icon(Icons.tune_rounded, color: scheme.onSurfaceVariant),
      onSelected: (value) async {
        switch (value) {
          case 'zoom.dots':
            setState(() => _zoom = CalendarZoom.dots);
            _showModeHud(_zoomTierLabel(CalendarZoom.dots));
          case 'zoom.bars':
            setState(() => _zoom = CalendarZoom.bars);
            _showModeHud(_zoomTierLabel(CalendarZoom.bars));
          case 'zoom.titles':
            setState(() => _zoom = CalendarZoom.titles);
            _showModeHud(_zoomTierLabel(CalendarZoom.titles));
          case 'hour.40':
            _setHourHeight(40);
          case 'hour.52':
            _setHourHeight(52);
          case 'hour.84':
            _setHourHeight(84);
          case 'week.mon':
            setState(() => _weekStart = 1);
            PrefUtil.setValue<int>('calendarWeekStart', 1);
          case 'week.sun':
            setState(() => _weekStart = 7);
            PrefUtil.setValue<int>('calendarWeekStart', 7);
          case 'calendars':
            await _openManager();
          case 'fitWholeDay':
            setState(() => _fitWholeDay = !_fitWholeDay);
            _fitWholeDayLive.value = _fitWholeDay;
            PrefUtil.setValue<bool>('calendarFitWholeDay', _fitWholeDay);
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'fitWholeDay',
          checked: _fitWholeDay,
          child: const Text('日视图整日概览（一屏看全天）'),
        ),
        const PopupMenuDivider(),
        _menuHeader('月格显示（也可双指捏合）'),
        CheckedPopupMenuItem(
          value: 'zoom.dots',
          checked: _zoom == CalendarZoom.dots,
          child: const Text('紧凑（横向点阵）'),
        ),
        CheckedPopupMenuItem(
          value: 'zoom.bars',
          checked: _zoom == CalendarZoom.bars,
          child: const Text('叠放（纵向色条）'),
        ),
        CheckedPopupMenuItem(
          value: 'zoom.titles',
          checked: _zoom == CalendarZoom.titles,
          child: const Text('详细信息（标题 + 时间）'),
        ),
        _menuHeader('时间轴行高'),
        CheckedPopupMenuItem(
          value: 'hour.40',
          checked: _hourHeight == 40,
          child: const Text('紧凑'),
        ),
        CheckedPopupMenuItem(
          value: 'hour.52',
          checked: _hourHeight == 52,
          child: const Text('标准'),
        ),
        CheckedPopupMenuItem(
          value: 'hour.84',
          checked: _hourHeight == 84,
          child: const Text('宽松'),
        ),
        _menuHeader('每周起始'),
        CheckedPopupMenuItem(
          value: 'week.mon',
          checked: _weekStart == 1,
          child: const Text('周一'),
        ),
        CheckedPopupMenuItem(
          value: 'week.sun',
          checked: _weekStart == 7,
          child: const Text('周日'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'calendars',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calendar_month_rounded, size: 18),
            title: Text('日历管理'),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuHeader(String text) => PopupMenuItem<String>(
    enabled: false,
    height: 28,
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  void _setHourHeight(double value) {
    setState(() => _hourHeight = value);
    PrefUtil.setValue<double>('calendarHourHeight', value);
  }

  Widget _dayBody({bool showMonthGrid = true}) {
    final grid = (!showMonthGrid ||
            _tab == CalendarBottomTab.today ||
            _weekMode)
        ? _weekStrip()
        : _monthGrid();
    return _dayTimelineColumn(
      grid: grid,
      hourHeight: _hourHeight,
      // 日视图「整日概览」：按时间轴自己的视口高度精确压屏，保证 00:00–24:00 全在屏内
      fitWholeDay: !showMonthGrid && _compactDayFit,
    );
  }

  /// 日/月视图的骨架：网格（可折叠） + 吸顶日期头 + 时间轴（+ 提醒事项）。
  ///
  /// [scroll] = true 时用滚动视图包住整块（整日概览压屏后仍可在内容多时滚动）。
  Widget _dayTimelineColumn({
    required Widget grid,
    required double hourHeight,
    bool fitWholeDay = false,
  }) {
    _timelineHourHeight = hourHeight;
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
          child: Listener(
            onPointerDown: _pinchDown,
            onPointerMove: _pinchMove,
            onPointerUp: _pinchUp,
            onPointerCancel: _pinchUp,
            child: LayoutBuilder(
              builder: (context, constraints) => ValueListenableBuilder<double>(
                valueListenable: _hourHeightLive,
                builder: (context, liveHeight, _) =>
                    ValueListenableBuilder<bool>(
                  valueListenable: _fitWholeDayLive,
                  builder: (context, liveFit, __) {
              final effective = (fitWholeDay && liveFit)
                  // 再让出底部悬浮胶囊（约 72dp），保证 23:00 也完整可见
                  ? ((constraints.maxHeight - 80) / 24).clamp(16.0, 60.0)
                  : liveHeight;
              _timelineHourHeight = effective;
              return CustomScrollView(
                key: _timelineViewportKey,
                controller: _scroll,
                physics: const ClampingScrollPhysics(),
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
                  ..._agendaSlivers(hourHeight: effective),
                  SliverToBoxAdapter(
                    child: SizedBox(height: fitWholeDay ? 8 : 96),
                  ),
                ],
              );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _agendaSlivers({double? hourHeight}) {
    final agenda = _agenda;
    final timelineHourHeight = hourHeight ?? _hourHeight;
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

    // 空状态引导：这一天什么都没安排时，教一遍拖动交互（iOS 的"点一点就有"）。
    // 整日概览模式下不占位，保证一整天完整可见。
    if (agenda.isEmpty && !_compactDayFit) {
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(IosCalendarTheme.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '这一天还没有安排',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '· 长按时间轴空白处上下拖动 → 直接拉出一个时间段\n'
                  '· 长按已有日程拖动 → 改时间；拖底部手柄 → 改时长\n'
                  '· 顶栏 ✨ → 说人话建日程（明天下午3点在会议室A评审）',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // 整日概览 + 空日程：给一条不占位的提示
    if (agenda.isEmpty && _compactDayFit) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(52, 8, 12, 0),
            child: Text(
              '长按空白处拖出时间段 · 顶栏 ✨ 可以说人话建日程',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    // 24 小时时间轴：绝对定位画布（长按拖动新建/移动/改时长都在这里）
    slivers.add(
      SliverToBoxAdapter(
        child: DayTimeline(
          key: ValueKey('timeline-${_selected.toIso8601String()}'),
          day: _selected,
          events: _dayEvents,
          colorOf: _colorOf,
          hourHeight: timelineHourHeight,
          scrollController: _scroll,
          viewportKey: _timelineViewportKey,
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
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: _DayCell(
                      day: d,
                      zoom: CalendarZoom.dots,
                      cellHeight: 48,
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
          ),
          _gridModeToggle(toWeek: false),
        ],
      ),
    );
  }

  /// 月/周切换的可见入口（与上下滑动等价，避免只能靠手势发现）。
  Widget _gridModeToggle({required bool toWeek}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => setState(() => _weekMode = toWeek),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: toWeek ? 0 : 0.5,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              toWeek ? '周视图' : '月视图',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthGrid() {
    final theme = Theme.of(context);
    final days = monthGridDays(_month.year, _month.month, weekStart: _weekStart);
    final rowCount = days.length ~/ 7;
    final cellHeight = _cellHeightForZoom(_zoom);
    final barHeight = _barHeightForZoom(_zoom);
    final canSpan = _zoom != CalendarZoom.dots;

    return Container(
      key: const ValueKey('calendar-grid'),
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(IosCalendarTheme.panelRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 7;
          return Column(
            children: [
              Row(
                children: [
                  for (final w in _weekLabels()) _weekdayLabel(theme, w),
                ],
              ),
              const SizedBox(height: 4),
              // 整块月格一个手势层：长按拖动改期 + 单指上下滑动切换月/周
              // 上下滑动切月/周：用 Listener 原始指针自己做，
              // 不注册拖拽识别器（否则会和双指捏合抢手势竞技场）。
              Listener(
                onPointerDown: _swipeDown,
                onPointerMove: _swipeMove,
                onPointerUp: _swipeUp,
                child: Column(
                  children: [
                    // 只有「周行」在 keyed 盒子里，便于用坐标反查日格
                    KeyedSubtree(
                      key: _gridBodyKey,
                      child: Column(
                        key: const ValueKey('month-grid-body'),
                        children: [
                          for (var row = 0; row < rowCount; row++)
                            SizedBox(
                              height: cellHeight,
                              child: _buildWeekRow(
                                week: days.sublist(row * 7, row * 7 + 7),
                                cellWidth: cellWidth,
                                cellHeight: cellHeight,
                                barHeight: barHeight,
                                canSpan: canSpan,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _gridModeToggle(toWeek: true),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _weekLabels() => [
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

  Widget _weekdayLabel(ThemeData theme, String label) => Expanded(
    child: Center(
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );

  double _cellHeightForZoom(CalendarZoom zoom) => switch (zoom) {
    CalendarZoom.dots => 46,
    CalendarZoom.bars => 62,
    CalendarZoom.titles => 88,
  };

  double _barHeightForZoom(CalendarZoom zoom) =>
      zoom == CalendarZoom.titles ? 17 : 9;

  /// 一周一行：底层 7 个日格 + 上层跨天连续条 + 拖动悬停高亮。
  Widget _buildWeekRow({
    required List<DateTime> week,
    required double cellWidth,
    required double cellHeight,
    required double barHeight,
    required bool canSpan,
  }) {
    final spans = canSpan
        ? layoutWeekSpans(week: week, events: _eventsOfWeek(week))
        : const <MonthSpanBar>[];
    final lanes = spans.isEmpty
        ? 0
        : spans.map((b) => b.lane).reduce((a, b) => a > b ? a : b) + 1;

    return Stack(
      children: [
        Row(
          children: [
            for (final day in week)
              Expanded(
                child: _DayCell(
                  day: day,
                  zoom: _zoom,
                  cellHeight: cellHeight,
                  reservedTop: lanes * barHeight,
                  inMonth: day.month == _month.month && day.year == _month.year,
                  selected: isSameDay(day, _selected),
                  hovered: _gridDragHover != null &&
                      isSameDay(day, _gridDragHover!),
                  events: _eventsByDay[day] ?? const [],
                  colorOf: _colorOf,
                  hasDiary: _diaryDays.contains(day),
                  // 跨天事件由上层「连续条」统一画，避免一屏两份
                  hideMultiDay: canSpan,
                  onTap: () => _selectDay(day),
                  onLongPress: () => _openEditor(day: day),
                  onEventDragStart: _eventDragStart,
                  onEventDragUpdate: _eventDragUpdate,
                  onEventDragEnd: _eventDragEnd,
                ),
              ),
          ],
        ),
        for (final bar in spans)
          Positioned(
            left: bar.startCol * cellWidth + 4,
            width: bar.span * cellWidth - 8,
            top: 32 + bar.lane * barHeight,
            height: barHeight,
            child: _MonthSpanBarView(
              event: bar.event,
              color: _colorOf(bar.event),
              showTitle: _zoom == CalendarZoom.titles,
              isDragging: _gridDragEvent?.id == bar.event.id,
              onDragStart: (g) => _eventDragStart(bar.event, g),
              onDragUpdate: _eventDragUpdate,
              onDragEnd: _eventDragEnd,
            ),
          ),
      ],
    );
  }

  /// 一行周内涉及的事件（含跨天条需要的事件）。
  List<Schedule> _eventsOfWeek(List<DateTime> week) {
    final result = <Schedule>[];
    for (final day in week) {
      result.addAll(_eventsByDay[day] ?? const []);
    }
    final seen = <String>{};
    return [
      for (final e in result)
        if (seen.add(e.id)) e,
    ];
  }

  // ---------------------------------------------------- 月格：长按事件条拖动改期
  //
  // 长按「事件条 / 跨天条」= 拖到别的日子；长按「空白日格」= 那天新建。
  // 两者分别落在各自的 widget 上，避免长按识别器互相抢。

  void _eventDragStart(Schedule event, Offset globalPosition) {
    setState(() {
      _gridDragEvent = event;
      _gridDragHover = _dayAtGlobal(globalPosition) ?? event.day;
    });
  }

  void _eventDragUpdate(Offset globalPosition) {
    if (_gridDragEvent == null) return;
    final day = _dayAtGlobal(globalPosition);
    if (day == null) return;
    if (_gridDragHover != null && isSameDay(_gridDragHover!, day)) return;
    setState(() => _gridDragHover = day);
  }

  /// 全局坐标 → 月格里的日子。
  DateTime? _dayAtGlobal(Offset globalPosition) {
    final box = _gridBodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(globalPosition);
    final days = monthGridDays(
      _month.year,
      _month.month,
      weekStart: _weekStart,
    );
    final rows = days.length ~/ 7;
    final cell = gridCellAt(
      dx: local.dx,
      dy: local.dy,
      cellWidth: box.size.width / 7,
      cellHeight: box.size.height / rows,
      rows: rows,
    );
    if (cell == null) return null;
    return days[cell.$1 * 7 + cell.$2];
  }

  Future<void> _eventDragEnd() async {
    final event = _gridDragEvent;
    final target = _gridDragHover;
    setState(() {
      _gridDragEvent = null;
      _gridDragHover = null;
    });
    if (event == null || target == null) return;
    if (isSameDay(event.day, target)) return;
    final moved = moveScheduleToDay(event, target);
    await _scheduleRepo.update(moved);
    if (mounted) await _reload();
    _toastUndo(
      '已移到 ${target.month}月${target.day}日',
      () async {
        final back = moveScheduleToDay(moved, event.day, keepHour: event.startTime.hour);
        await _scheduleRepo.update(back);
        if (mounted) await _reload();
      },
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
class _MiniDay extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool hasEvent;
  final VoidCallback onTap;

  const _MiniDay({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.hasEvent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = isSameDay(day, DateTime.now());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 26,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? IosCalendarTheme.today
                    : selected
                    ? scheme.primaryContainer
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: isToday
                      ? Colors.white
                      : inMonth
                      ? scheme.onSurface
                      : scheme.outline,
                  fontWeight: (isToday || selected) ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (hasEvent)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final CalendarZoom zoom;
  final double cellHeight;

  /// 顶部为「跨天连续条」预留的高度
  final double reservedTop;
  /// 是否隐藏跨天事件（它们由月格的连续条统一渲染）
  final bool hideMultiDay;
  final bool inMonth;
  final bool selected;
  final bool hovered;
  final List<Schedule> events;
  final Color Function(Schedule) colorOf;
  final bool hasDiary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(Schedule, Offset)? onEventDragStart;
  final void Function(Offset)? onEventDragUpdate;
  final VoidCallback? onEventDragEnd;
  final bool compact;

  const _DayCell({
    required this.day,
    required this.zoom,
    required this.cellHeight,
    this.reservedTop = 0,
    this.hideMultiDay = false,
    required this.inMonth,
    required this.selected,
    this.hovered = false,
    required this.events,
    required this.colorOf,
    required this.hasDiary,
    required this.onTap,
    required this.onLongPress,
    this.onEventDragStart,
    this.onEventDragUpdate,
    this.onEventDragEnd,
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
    final barHeight = showTitle ? 17.0 : 9.0;
    final cellEvents = hideMultiDay
        ? events.where((e) => !e.isMultiDay).toList()
        : events;
    // 日格内可放下的事件条数量（扣掉日期数字、跨天条与「+N」占位）
    final maxBars = showBars
        ? ((cellHeight - 32 - reservedTop - 14) / barHeight).floor().clamp(
            0,
            showTitle ? 3 : 4,
          )
        : 0;
    final hidden = showBars && cellEvents.length > maxBars
        ? cellEvents.length - maxBars
        : 0;

    return SizedBox(
      height: cellHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hovered
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: showTitle ? 4 : 3,
              horizontal: 2,
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
                      fontWeight: (isToday || selected)
                          ? FontWeight.w600
                          : null,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (reservedTop > 0) SizedBox(height: reservedTop),
                if (!showBars)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in cellEvents.take(3))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
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
                else ...[
                  const SizedBox(height: 2),
                  for (final e in cellEvents.take(maxBars))
                    CalendarEventBar(
                      event: e,
                      color: colorOf(e),
                      showTitle: showTitle,
                      height: barHeight,
                      onTap: onTap,
                      onLongPressStart: onEventDragStart == null
                          ? null
                          : (global) => onEventDragStart!(e, global),
                      onLongPressMoveUpdate: onEventDragUpdate,
                      onLongPressEnd: onEventDragEnd,
                    ),
                  if (hidden > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, top: 1),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+$hidden',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 月格里的「跨天连续条」。
class _MonthSpanBarView extends StatelessWidget {
  final Schedule event;
  final Color color;
  final bool showTitle;
  final bool isDragging;
  final void Function(Offset globalPosition) onDragStart;
  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;

  const _MonthSpanBarView({
    required this.event,
    required this.color,
    required this.showTitle,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => onDragStart(d.globalPosition),
      onLongPressMoveUpdate: (d) => onDragUpdate(d.globalPosition),
      onLongPressEnd: (_) => onDragEnd(),
      child: Container(
        padding: showTitle
            ? const EdgeInsets.symmetric(horizontal: 4)
            : EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDragging ? 0.45 : 0.28),
          borderRadius: BorderRadius.circular(3),
        ),
        child: showTitle
            ? Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  height: 1.1,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
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
