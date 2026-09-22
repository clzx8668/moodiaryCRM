import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/calendar/views/day_timeline.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';

void main() {
  final day = DateTime(2026, 9, 22);

  Schedule event({
    required String title,
    required int startHour,
    int startMinute = 0,
    int endHour = 0,
    int endMinute = 0,
  }) => Schedule()
    ..id = title
    ..title = title
    ..startTime = DateTime(2026, 9, 22, startHour, startMinute)
    ..endTime = DateTime(
      2026,
      9,
      22,
      endHour == 0 ? startHour + 1 : endHour,
      endMinute,
    );

  /// 固定几何：hourHeight = 30 → 24 小时 = 720px，整屏放得下，坐标可精确计算。
  Future<
    ({
      List<(DateTime, DateTime)> created,
      List<(String, DateTime)> moved,
      List<(String, DateTime)> resized,
      List<String> tapped,
    })
  >
  pumpTimeline(WidgetTester tester, List<Schedule> events) async {
    final created = <(DateTime, DateTime)>[];
    final moved = <(String, DateTime)>[];
    final resized = <(String, DateTime)>[];
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DayTimeline(
              day: day,
              events: events,
              hourHeight: 30,
              colorOf: (_) => const Color(0xFF0A84FF),
              onTapEvent: (e) => tapped.add(e.title),
              onCreateRange: (s, e) => created.add((s, e)),
              onMoveEvent: (e, s) => moved.add((e.title, s)),
              onResizeEvent: (e, t) => resized.add((e.title, t)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (created: created, moved: moved, resized: resized, tapped: tapped);
  }

  testWidgets('长按空白处拖出时间段 → 按 15 分钟吸附回调', (tester) async {
    final log = await pumpTimeline(tester, []);
    final rect = tester.getRect(find.byType(DayTimeline));

    // 10:00 位置 = 10 * 30 = 300px；拖到 11:20 位置 ≈ 340px → 吸附 11:15
    final start = Offset(rect.left + 200, rect.top + 300);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600)); // 触发长按
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(log.created, hasLength(1));
    final (from, to) = log.created.single;
    expect(from, DateTime(2026, 9, 22, 10));
    expect(to, DateTime(2026, 9, 22, 11, 15));
  });

  testWidgets('只长按不拖动 → 默认 1 小时整点', (tester) async {
    final log = await pumpTimeline(tester, []);
    final rect = tester.getRect(find.byType(DayTimeline));
    // 07:12 位置 → 就近吸附到 07:00，默认 +1 小时
    final gesture = await tester.startGesture(
      Offset(rect.left + 200, rect.top + 7 * 30 + 6),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(log.created, hasLength(1));
    expect(log.created.single.$1, DateTime(2026, 9, 22, 7));
    expect(
      log.created.single.$2.difference(log.created.single.$1),
      const Duration(hours: 1),
    );
  });

  testWidgets('长按事件卡拖动 → 移动事件（保持时长，30 分钟吸附）', (tester) async {
    final log = await pumpTimeline(tester, [
      event(title: '周会', startHour: 10, endHour: 11),
    ]);
    final rect = tester.getRect(find.byType(DayTimeline));

    // 事件卡在 10:00–11:00（300–330px），往下拖 30px = 1 小时
    final gesture = await tester.startGesture(
      Offset(rect.left + 260, rect.top + 305),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // hourHeight = 30 → 拖 30px = 1 小时
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(log.moved, hasLength(1));
    expect(log.moved.single.$1, '周会');
    expect(log.moved.single.$2, DateTime(2026, 9, 22, 11));
    expect(log.resized, isEmpty);
  });

  testWidgets('长按事件卡底部手柄拖动 → 改结束时间', (tester) async {
    final log = await pumpTimeline(tester, [
      event(title: '周会', startHour: 10, endHour: 11),
    ]);
    final rect = tester.getRect(find.byType(DayTimeline));

    // 卡片底部手柄在 11:00 附近（329px），往下拖 15px = 30 分钟
    final gesture = await tester.startGesture(
      Offset(rect.left + 260, rect.top + 328),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 15));
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(log.resized, hasLength(1));
    expect(log.resized.single.$2, DateTime(2026, 9, 22, 11, 30));
    expect(log.moved, isEmpty);
  });

  testWidgets('点击事件卡 → 回调（详情面板入口）', (tester) async {
    final log = await pumpTimeline(tester, [
      event(title: '周会', startHour: 10, endHour: 11),
    ]);
    await tester.tap(find.text('周会'));
    await tester.pumpAndSettle();
    expect(log.tapped, ['周会']);
  });

  testWidgets('带时刻的提醒事项在时间轴对应位置画空心圆', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DayTimeline(
              day: day,
              events: const [],
              hourHeight: 30,
              colorOf: (_) => const Color(0xFF0A84FF),
              onTapEvent: (_) {},
              onCreateRange: (_, _) {},
              onMoveEvent: (_, _) {},
              onResizeEvent: (_, _) {},
              markers: [
                TimelineMarker(
                  at: DateTime(2026, 9, 22, 16),
                  text: '提交设计稿',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('16:00 提交设计稿'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
  });

  testWidgets('长按拖动时：幽灵块显示时间区间 + 吸附槽展开（标出整点/半点）', (tester) async {
    await pumpTimeline(tester, []);
    final rect = tester.getRect(find.byType(DayTimeline));

    final gesture = await tester.startGesture(
      Offset(rect.left + 200, rect.top + 300),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // 拖 15px = 30 分钟 → 吸附到 10:30（半点）
    await gesture.moveBy(const Offset(0, 15));
    await tester.pump(const Duration(milliseconds: 40));

    // 幽灵块里的时间文案（10:00 → 10:30）
    expect(find.textContaining('10:00'), findsWidgets);
    // 吸附槽：标明这是整点还是半点
    expect(find.textContaining('半点'), findsWidgets);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
