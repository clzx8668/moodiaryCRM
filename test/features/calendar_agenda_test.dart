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
}
