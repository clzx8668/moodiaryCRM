import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/calendar/views/ios_calendar_page.dart';
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

  testWidgets('缩放档位按钮可在圆点/事件条/标题之间轮换', (tester) async {
    await pumpPage(tester);
    // 初始：圆点档（更多…图标）
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_handle_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.drag_handle_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.view_agenda_rounded), findsOneWidget);
    // 再点一次回到圆点
    await tester.tap(find.byIcon(Icons.view_agenda_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  testWidgets('双指捏合放大：圆点档 → 事件条档（技巧 01）', (tester) async {
    await pumpPage(tester);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

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

    expect(
      find.byIcon(Icons.drag_handle_rounded),
      findsOneWidget,
      reason: '捏合放大应升到「事件条」档',
    );
  });

  testWidgets('事件卡 → 编辑页 → 删除：日程确实被软删且日历上消失', (tester) async {
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

    // 点卡片进编辑页
    await tester.tap(find.text('待删除事件'));
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
}
