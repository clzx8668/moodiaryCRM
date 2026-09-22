import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/calendar/views/ios_calendar_page.dart';
import 'package:moodiary/features/calendar/calendar_agenda.dart';
import 'package:moodiary/features/calendar/widgets/event_card.dart';
import 'package:moodiary/features/calendar/views/agenda_list_view.dart';
import 'package:moodiary/features/calendar/views/day_timeline.dart';
import 'package:moodiary/features/calendar/views/week_view.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PrefUtil.prefAllowList,
      ),
    );
    PrefUtil.overridePrefsForTest(prefs);
    db = openTestDb();
  });

  tearDown(() async {
    Get.reset();
    closeTestDb(db);
  });

  Future<void> pumpPage(WidgetTester tester, {Size size = const Size(420, 860)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        // 与 main.dart 一致：注册 SmartDialog，才能走通 toast 路径
        navigatorObservers: [FlutterSmartDialog.observer],
        builder: (context, child) => FlutterSmartDialog.init()(context, child),
        home: const Scaffold(body: IosCalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 从「视图与日历」菜单里切月格缩放档位。
  Future<void> setZoom(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('手机端渲染 iOS 风日历页无异常，三档底部胶囊在位', (tester) async {
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
    // 「今天」既是底部胶囊的一项，也可能是日期头的相对日标签
    expect(find.text('今天'), findsWidgets);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('收件箱'), findsOneWidget);
    // 顶栏：月份标题 + 新建入口
    final now = DateTime.now();
    expect(find.text('${now.year}年${now.month}月'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    // 空状态引导：切到「日」视图（整日概览）后是那行精简提示
    await tester.tap(find.byIcon(Icons.view_day_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('长按空白处拖出时间段'), findsOneWidget);
  });

  testWidgets('切到收件箱显示空态；有草案时能加入日历', (tester) async {
    final draft = await ScheduleRepository().create(
      Schedule()
        ..title = '航班：MU583'
        ..location = '上海虹桥 T2'
        ..startTime = DateTime.now().add(const Duration(days: 3))
        ..draft = true,
    );

    await pumpPage(tester);
    await tester.tap(find.text('收件箱'));
    await tester.pumpAndSettle();

    expect(find.text('待确认的日程建议'), findsOneWidget);
    expect(find.text('航班：MU583'), findsOneWidget);

    await tester.tap(find.text('加入日历'));
    await tester.pumpAndSettle();

    final saved = await ScheduleRepository().getById(draft.id);
    expect(saved!.draft, isFalse, reason: '确认后草案要落到日历');
    expect(saved.calendarId, isNotNull, reason: '应归到默认日历');

    // 等 toast 的 2s 定时器走完，否则测试结束时会报 "Timer is still pending"
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('视图菜单可切月格缩放档位（圆点/事件条/标题）', (tester) async {
    await pumpPage(tester);
    // 初始圆点档：日格里只有一个圆点
    expect(find.byType(CalendarEventBar), findsNothing);
    await setZoom(tester, '叠放（纵向色条）');
    expect(find.byType(CalendarEventBar), findsNothing, reason: '这天没有事件');

    await setZoom(tester, '详细信息（标题 + 时间）');
    // 再切回圆点
    await setZoom(tester, '紧凑（横向点阵）');
    expect(tester.takeException(), isNull);
  });

  testWidgets('双指捏合放大：圆点档 → 事件条档（技巧 01）', (tester) async {
    await pumpPage(tester);
    // 起始为圆点档：格子里没有事件条
    expect(find.byType(CalendarEventBar), findsNothing);

    // 两根手指在月网格上向外撑开
    final center = tester.getCenter(find.byKey(const ValueKey('calendar-grid')));
    final left = await tester.startGesture(center - const Offset(20, 0));
    final right = await tester.startGesture(center + const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 20));
    // 指间距 40 → 90（scale 2.25）：要越过点击/拖拽的 slop 才会赢下手势竞技场，
    // 因此步长不能太小（太小会被单元格的 InkWell 一直拖住）。
    await left.moveBy(const Offset(-25, 0));
    await right.moveBy(const Offset(25, 0));
    await tester.pump(const Duration(milliseconds: 16));
    // 步长只走一次，档位只升一级
    await tester.pump(const Duration(milliseconds: 16));
    await left.up();
    await right.up();
    await tester.pumpAndSettle();

    // 升到事件条档后：依旧没有事件条（今天没事件），但不能再报异常
    expect(tester.takeException(), isNull);
  });

  testWidgets('事件卡 → 详情面板 → 编辑 → 删除：日程软删且日历上消失', (tester) async {
    final now = DateTime.now();
    final repo = ScheduleRepository();
    final event = await repo.create(
      Schedule()
        ..title = '待删除事件'
        ..startTime = DateTime(now.year, now.month, now.day, 10)
        ..endTime = DateTime(now.year, now.month, now.day, 11),
    );

    await pumpPage(tester);
    expect(find.text('待删除事件'), findsOneWidget);

    // 点卡片进详情面板，再进编辑页
    await tester.tap(find.text('待删除事件'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑事件'), findsOneWidget);

    // 点删除 → 确认
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('删除事件'), findsOneWidget, reason: '确认弹窗应出现');
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('编辑事件'), findsNothing, reason: '确认后应退出编辑页');

    final saved = await repo.getById(event.id);
    expect(saved!.deleted, isTrue, reason: '确认后应写入软删墓碑');
    expect(find.text('待删除事件'), findsNothing, reason: '日历上不该再显示');
  });

  testWidgets('详情面板信息齐全，可直接删除（iOS 交互）', (tester) async {
    final now = DateTime.now();
    final repo = ScheduleRepository();
    final event = await repo.create(
      Schedule()
        ..title = '详情面板用例'
        ..location = '会议室 A'
        ..startTime = DateTime(now.year, now.month, now.day, 14)
        ..endTime = DateTime(now.year, now.month, now.day, 15),
    );

    await pumpPage(tester);
    await tester.tap(find.text('详情面板用例'));
    await tester.pumpAndSettle();

    // 详情面板信息齐全
    expect(find.text('会议室 A'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    // 面板里删除 → 落库 + 刷新
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect((await repo.getById(event.id))!.deleted, isTrue);
    expect(find.text('详情面板用例'), findsNothing);
  });

  testWidgets('拖动/编辑落库后，切日再回来能看到新时间（不吃旧缓存）', (tester) async {
    final now = DateTime.now();
    final repo = ScheduleRepository();
    final event = await repo.create(
      Schedule()
        ..title = '缓存用例'
        ..startTime = DateTime(now.year, now.month, now.day, 10)
        ..endTime = DateTime(now.year, now.month, now.day, 11),
    );

    await pumpPage(tester);
    expect(find.text('10:00 – 11:00'), findsOneWidget);

    // 模拟"拖动移动"落库
    await repo.update(
      event.clone()
        ..startTime = DateTime(now.year, now.month, now.day, 12)
        ..endTime = DateTime(now.year, now.month, now.day, 13),
    );

    // 切到别的日子再切回来（触发当日重载）
    final otherDay = now.day == 1 ? 2 : 1;
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('calendar-grid')),
            matching: find.text('$otherDay'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('calendar-grid')),
            matching: find.text('${now.day}'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('12:00 – 13:00'), findsOneWidget, reason: '应显示拖动后的新时间');
    expect(find.text('10:00 – 11:00'), findsNothing);
  });

  testWidgets('月格里长按事件拖到别的日子：日期改掉、时刻保留', (tester) async {
    final now = DateTime.now();
    final repo = ScheduleRepository();
    // 挑两个「既不撞今天也不是月末边界」的日子
    final days = monthGridDays(now.year, now.month);
    final sourceDay = DateTime(now.year, now.month, 10);
    final targetDay = DateTime(now.year, now.month, 17);
    final event = await repo.create(
      Schedule()
        ..title = '月格拖动用例'
        ..startTime = DateTime(now.year, now.month, 10, 14)
        ..endTime = DateTime(now.year, now.month, 10, 15),
    );

    await pumpPage(tester);

    // 切到「事件条」档，事件才会以可长按的条形呈现
    await setZoom(tester, '叠放（纵向色条）');

    final body = tester.getRect(find.byKey(const ValueKey('month-grid-body')));
    final cellWidth = body.width / 7;
    final cellHeight = body.height / (days.length ~/ 7);
    Offset centerOf(DateTime d) {
      final index = days.indexWhere((x) => isSameDay(x, d));
      final row = index ~/ 7;
      final col = index % 7;
      // 日格内第一条事件条的位置（日期数字 26 + 间距，条高 9）
      return Offset(
        body.left + col * cellWidth + cellWidth / 2,
        body.top + row * cellHeight + 36,
      );
    }

    final gesture = await tester.startGesture(centerOf(sourceDay));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(centerOf(targetDay));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = await repo.getById(event.id);
    expect(moved!.startTime.day, targetDay.day, reason: '应改到拖到的日子');
    expect(moved.startTime.hour, 14, reason: '时刻要保留');
    expect(moved.endTime!.difference(moved.startTime), const Duration(hours: 1));

    // 撤销提示在位
    expect(find.textContaining('已移到'), findsOneWidget);
  });

  testWidgets('多天/全天事件在月格里画一条跨格连续条', (tester) async {
    final now = DateTime.now();
    // 1~4 号在同一周行内，便于断言「一条连续条横跨多格」
    final start = DateTime(now.year, now.month, 1);
    await ScheduleRepository().create(
      Schedule()
        ..title = '连续条用例'
        ..allDay = true
        ..startTime = start
        ..endTime = DateTime(now.year, now.month, 4, 23, 59),
    );

    await pumpPage(tester);
    // 直接切到标题档（连续条在标题档才显示标题）
    await setZoom(tester, '详细信息（标题 + 时间）');

    final barFinder = find.text('连续条用例');
    expect(barFinder, findsOneWidget, reason: '跨天事件应作为连续条出现');

    final body = tester.getRect(find.byKey(const ValueKey('month-grid-body')));
    final cellWidth = body.width / 7;
    final barRect = tester.getRect(
      find.ancestor(of: barFinder, matching: find.byType(DecoratedBox)).first,
    );
    expect(
      barRect.width,
      greaterThan(cellWidth * 2),
      reason: '4 天的事件应横跨多格',
    );
  });

  testWidgets('视图模式：日 / 周 / 月 / 列表 都能切换并渲染', (tester) async {
    final now = DateTime.now();
    await ScheduleRepository().create(
      Schedule()
        ..title = '模式用例'
        ..startTime = DateTime(now.year, now.month, now.day, 11)
        ..endTime = DateTime(now.year, now.month, now.day, 12),
    );
    await pumpPage(tester);

    // 默认月视图：月格在
    expect(find.byKey(const ValueKey('calendar-grid')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_week_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(WeekView), findsOneWidget, reason: '周视图 = 多日显示');
    expect(find.text('模式用例'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AgendaListView), findsOneWidget);
    expect(find.text('模式用例'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_day_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(WeekView), findsNothing);
    expect(find.byType(AgendaListView), findsNothing);

    await tester.tap(find.byIcon(Icons.calendar_view_month_rounded));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-grid')), findsOneWidget);
  });

  testWidgets('PC 宽屏：侧边栏日历勾选 + 右侧检查器（点事件不弹底部面板）', (tester) async {
    final now = DateTime.now();
    await ScheduleRepository().create(
      Schedule()
        ..title = 'PC 用例'
        ..location = '会议室 B'
        ..startTime = DateTime(now.year, now.month, now.day, 15)
        ..endTime = DateTime(now.year, now.month, now.day, 16),
    );

    await pumpPage(tester, size: const Size(1280, 900));

    // 侧边栏
    expect(find.text('我的日历'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text('工作'), findsWidgets);

    // 点事件 → 右侧检查器
    await tester.tap(find.text('PC 用例').first);
    await tester.pumpAndSettle();
    expect(find.text('日程详情'), findsOneWidget);
    expect(find.text('会议室 B'), findsWidgets);
    expect(find.byType(BottomSheet), findsNothing, reason: 'PC 上不弹底部面板');
  });

  testWidgets('日视图「整日概览」：一屏完整看到 00:00–24:00', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byIcon(Icons.view_day_rounded));
    await tester.pumpAndSettle();

    // 24 小时都在同一块画布里（不是只滚到"当前时间"），且整块压进一屏
    expect(find.byType(DayTimeline), findsOneWidget);
    final timeline = tester.getRect(find.byType(DayTimeline));
    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      timeline.height,
      lessThan(screenHeight),
      reason: '整日概览要把 24 小时压进一屏',
    );
  });

  testWidgets('时间轴上双指捏合（张开）会加大每小时行高', (tester) async {
    await pumpPage(tester);
    // 先切回「月」视图的常规密度（整日概览会压屏）
    await tester.tap(find.byIcon(Icons.calendar_view_month_rounded));
    await tester.pumpAndSettle();

    final before = tester.getRect(find.byType(DayTimeline)).height;
    final area = tester.getRect(find.byKey(const ValueKey('month-grid-body')));
    final center = Offset(area.center.dx, area.bottom + 200);

    final a = await tester.startGesture(center - const Offset(30, 0));
    final b = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await a.moveBy(const Offset(-40, 0));
    await b.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    final after = tester.getRect(find.byType(DayTimeline)).height;
    expect(after, greaterThan(before), reason: '张开手指应把时间轴放大');
  });
}
