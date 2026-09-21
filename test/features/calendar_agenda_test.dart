import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/calendar/calendar_agenda.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/todo/todo_item.dart';

void main() {
  final day = DateTime(2026, 9, 22);

  Schedule event({
    required String title,
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    bool floating = false,
    bool draft = false,
    String? calendarId,
  }) => Schedule()
    ..title = title
    ..startTime = start ?? DateTime(2026, 9, 22, 9)
    ..endTime = end
    ..allDay = allDay
    ..floating = floating
    ..draft = draft
    ..calendarId = calendarId;

  TodoItem todo({
    required String text,
    DateTime? due,
    bool done = false,
    TodoSource source = TodoSource.localBlock,
    bool floating = false,
  }) => TodoItem(
    id: text,
    source: source,
    text: text,
    done: done,
    dueDate: due,
    time: DateTime(2026, 9, 22, 8),
    isFloating: floating,
  );

  group('buildAgenda', () {
    test('定时事件落到起始小时槽，全天/跨天进 allDay', () {
      final agenda = buildAgenda(
        day: day,
        events: [
          event(title: '周会', start: DateTime(2026, 9, 22, 9, 30)),
          event(title: '评审', start: DateTime(2026, 9, 22, 14)),
          event(title: '生日', allDay: true),
          event(
            title: '出差',
            start: DateTime(2026, 9, 21, 8),
            end: DateTime(2026, 9, 23, 18),
          ),
        ],
        todos: const [],
      );

      expect(agenda.byHour[9]!.single.title, '周会');
      expect(agenda.byHour[14]!.single.title, '评审');
      expect(agenda.allDay.map((e) => e.title), containsAll(['生日', '出差']));
      expect(agenda.timedEvents, hasLength(2));
      expect(agenda.busyHours, {9, 14});
    });

    test('草案与浮动待办不进日历；别的日子的事件不进本日', () {
      final agenda = buildAgenda(
        day: day,
        events: [
          event(title: '草案', start: DateTime(2026, 9, 22, 10), draft: true),
          event(title: '浮动', start: DateTime(2026, 9, 22, 11), floating: true),
          event(title: '明天的事', start: DateTime(2026, 9, 23, 9)),
        ],
        todos: const [],
      );
      expect(agenda.isEmpty, isTrue);
    });

    test('提醒事项：有时刻的进时间轴，无时刻的进下方列表', () {
      final agenda = buildAgenda(
        day: day,
        events: const [],
        todos: [
          todo(text: '提交设计稿', due: DateTime(2026, 9, 22, 16)),
          todo(text: '买活动物料', due: day),
          todo(text: '无日期提醒'),
          // 日程类待办已由事件卡呈现，不重复出现
          todo(
            text: '日程待办重复',
            due: DateTime(2026, 9, 22, 9),
            source: TodoSource.schedule,
          ),
          // 浮动日程没有卡片，保留成勾选项
          todo(
            text: '浮动日程',
            source: TodoSource.schedule,
            floating: true,
          ),
        ],
      );

      expect(agenda.todosByHour[16]!.single.text, '提交设计稿');
      final untimed = agenda.untimedTodos.map((t) => t.text).toList();
      expect(untimed, containsAll(['买活动物料', '无日期提醒', '浮动日程']));
      expect(untimed, isNot(contains('日程待办重复')));
    });

    test('同一天多个事件按开始时间排序', () {
      final agenda = buildAgenda(
        day: day,
        events: [
          event(title: '晚', start: DateTime(2026, 9, 22, 9, 45)),
          event(title: '早', start: DateTime(2026, 9, 22, 9, 10)),
        ],
        todos: const [],
      );
      expect(agenda.byHour[9]!.map((e) => e.title), ['早', '晚']);
    });
  });

  group('缩放档位', () {
    test('放大升档、缩小降档，两端夹紧', () {
      expect(zoomAfterPinch(CalendarZoom.dots, 1.3), CalendarZoom.bars);
      expect(zoomAfterPinch(CalendarZoom.bars, 1.3), CalendarZoom.titles);
      expect(zoomAfterPinch(CalendarZoom.titles, 1.3), CalendarZoom.titles);
      expect(zoomAfterPinch(CalendarZoom.titles, 0.7), CalendarZoom.bars);
      expect(zoomAfterPinch(CalendarZoom.dots, 0.7), CalendarZoom.dots);
      // 小抖动不改档
      expect(zoomAfterPinch(CalendarZoom.dots, 1.02), CalendarZoom.dots);
      expect(zoomAfterPinch(CalendarZoom.bars, 0.95), CalendarZoom.bars);
    });
  });

  group('日期与文案', () {
    test('月网格整周对齐（2026 年 9 月：8/31 起，5 行）', () {
      final days = monthGridDays(2026, 9);
      expect(days.first, DateTime(2026, 8, 31));
      expect(days, hasLength(35));
      expect(days.last, DateTime(2026, 10, 4));
    });

    test('周首可切换', () {
      final days = monthGridDays(2026, 9, weekStart: 7);
      expect(days.first, DateTime(2026, 8, 30));
    });

    test('相对日期与时间文案', () {
      final now = DateTime(2026, 9, 22, 15);
      expect(relativeDayLabel(DateTime(2026, 9, 22), now: now), '今天');
      expect(relativeDayLabel(DateTime(2026, 9, 23), now: now), '明天');
      expect(relativeDayLabel(DateTime(2026, 9, 20), now: now), '');
      expect(dayLabel(DateTime(2026, 9, 25)), '9月25日 星期五');
      expect(
        eventTimeLabel(
          event(
            title: '会',
            start: DateTime(2026, 9, 22, 9),
            end: DateTime(2026, 9, 22, 10, 30),
          ),
        ),
        '09:00 – 10:30',
      );
      expect(eventTimeLabel(event(title: '全天', allDay: true)), '全天');
      expect(eventTimeLabel(event(title: '单点')), '09:00');
    });

    test('一周七天含当天', () {
      final days = weekDays(DateTime(2026, 9, 25));
      expect(days.first, DateTime(2026, 9, 21));
      expect(days.last, DateTime(2026, 9, 27));
    });
  });

  group('时间轴布局（拖动交互的几何）', () {
    test('单个事件：上边距/高度按当天比例', () {
      final layouts = layoutDayTimeline([
        event(
          title: '周会',
          start: DateTime(2026, 9, 22, 9),
          end: DateTime(2026, 9, 22, 10, 30),
        ),
      ]);
      expect(layouts, hasLength(1));
      expect(layouts.single.topRatio, closeTo(9 * 60 / 1440, 0.0001));
      expect(layouts.single.heightRatio, closeTo(90 / 1440, 0.0001));
      expect(layouts.single.columnCount, 1);
      expect(layouts.single.leftFactor, 0);
      expect(layouts.single.widthFactor, 1);
    });

    test('重叠事件并排分栏，错开的不分栏', () {
      final layouts = layoutDayTimeline([
        event(
          title: 'A',
          start: DateTime(2026, 9, 22, 9),
          end: DateTime(2026, 9, 22, 10),
        ),
        event(
          title: 'B',
          start: DateTime(2026, 9, 22, 9, 30),
          end: DateTime(2026, 9, 22, 10, 30),
        ),
        event(
          title: 'C',
          start: DateTime(2026, 9, 22, 14),
          end: DateTime(2026, 9, 22, 15),
        ),
      ]);
      final a = layouts.firstWhere((l) => l.event.title == 'A');
      final b = layouts.firstWhere((l) => l.event.title == 'B');
      final c = layouts.firstWhere((l) => l.event.title == 'C');
      expect(a.columnCount, 2);
      expect(b.columnCount, 2);
      expect([a.columnIndex, b.columnIndex], containsAll([0, 1]));
      expect(c.columnCount, 1, reason: '14:00 与上午的簇不重叠');
    });

    test('全天/跨天/浮动/草案不进时间轴', () {
      final layouts = layoutDayTimeline([
        event(title: '全天', allDay: true),
        event(
          title: '跨天',
          start: DateTime(2026, 9, 21, 8),
          end: DateTime(2026, 9, 23, 8),
        ),
        event(title: '浮动', floating: true),
        event(title: '草案', draft: true),
        event(title: '正常', start: DateTime(2026, 9, 22, 9)),
      ]);
      expect(layouts.map((l) => l.event.title), ['正常']);
    });

    test('极短事件保底 15 分钟高度', () {
      final layouts = layoutDayTimeline([
        event(
          title: '快闪',
          start: DateTime(2026, 9, 22, 9),
          end: DateTime(2026, 9, 22, 9, 2),
        ),
      ]);
      expect(layouts.single.heightRatio, closeTo(15 / 1440, 0.0001));
    });
  });

  group('拖动几何换算', () {
    test('吸附到 15 分钟档', () {
      expect(snapMinutes(0, 15), 0);
      expect(snapMinutes(7, 15), 0);
      expect(snapMinutes(8, 15), 15);
      expect(snapMinutes(52, 15), 45);
      expect(snapMinutes(53, 15), 60);
      expect(snapMinutes(1439, 15), 1440);
    });

    test('拖动创建：像素区间 → 吸附后的时间区间', () {
      // hourHeight = 60px → 1px = 1分钟，读数最直观
      final day = DateTime(2026, 9, 22);
      final (start, end) = dragRangeToTimes(
        day: day,
        startY: 9 * 60 + 7, // 09:07 → 09:00
        endY: 10 * 60 + 38, // 10:38 → 10:45
        hourHeight: 60,
      );
      expect(start, DateTime(2026, 9, 22, 9));
      expect(end, DateTime(2026, 9, 22, 10, 45));
    });

    test('向上拖也成立，只有一次点击也至少 15 分钟', () {
      final day = DateTime(2026, 9, 22);
      final up = dragRangeToTimes(
        day: day,
        startY: 14 * 60 + 50,
        endY: 14 * 60 + 20,
        hourHeight: 60,
      );
      expect(up.$1.isBefore(up.$2), isTrue);
      expect(up.$1, DateTime(2026, 9, 22, 14, 15));
      expect(up.$2, DateTime(2026, 9, 22, 14, 45));

      final tiny = dragRangeToTimes(
        day: day,
        startY: 8 * 60,
        endY: 8 * 60 + 2,
        hourHeight: 60,
      );
      expect(tiny.$2.difference(tiny.$1), const Duration(minutes: 15));
    });

    test('越界自动夹紧到当天 0:00–24:00', () {
      final day = DateTime(2026, 9, 22);
      final (start, end) = dragRangeToTimes(
        day: day,
        startY: -50,
        endY: 24 * 60 + 90,
        hourHeight: 60,
      );
      expect(start, DateTime(2026, 9, 22, 0));
      expect(end, DateTime(2026, 9, 23, 0));
    });

    test('拖动位移 → 吸附分钟数', () {
      // 52px 一小时：拖 26px ≈ 30 分钟
      expect(dragDeltaMinutes(26, 52), 30);
      expect(dragDeltaMinutes(-26, 52), -30);
      // 拖 8px ≈ 9 分钟 → 吸附到 15
      expect(dragDeltaMinutes(8, 52), 15);
      // 微动不吸附成 0 以外的抖动
      expect(dragDeltaMinutes(1, 52), 0);
    });
  });
}
