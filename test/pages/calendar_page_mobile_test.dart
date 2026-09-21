import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/pages/home/calendar/calendar_view.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/views/schedule_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
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

  testWidgets('手机端渲染日历页无溢出/异常（上下堆叠布局）', (tester) async {
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CalendarPage())),
    );
    // 触发 CalendarLogic.onReady 的异步加载
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('待办'), findsWidgets);
  });

  testWidgets('周视图保留活跃度圆点（日期键按天归一）', (tester) async {
    final now = DateTime.now();
    await IsarUtil.insertADiary(
      Diary()
        ..id = 'cal-week-dot'
        ..time = DateTime(now.year, now.month, now.day, 10)
        ..content = 'a'
        ..contentText = 'a' * 60
        ..type = 'note',
    );

    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CalendarPage())),
    );
    await tester.pumpAndSettle();

    Finder dots() => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.minWidth == 5 &&
          w.constraints?.maxWidth == 5,
    );

    final grid = find.byKey(const ValueKey('calendar-grid'));
    expect(dots(), findsWidgets, reason: '月视图应显示活跃度圆点');

    await tester.tap(find.text('周视图'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(dots(), findsWidgets, reason: '周视图同样要保留活跃度圆点');
    // 圆点必须落在月历容器内（不能被 AnimatedSize 裁掉）
    final gridRect = tester.getRect(grid);
    for (final element in dots().evaluate()) {
      final box = element.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      expect(
        rect.center.dy,
        lessThanOrEqualTo(gridRect.bottom),
        reason: '圆点应位于日历容器内',
      );
    expect(rect.center.dy, greaterThanOrEqualTo(gridRect.top));
    }
  });

  testWidgets('FAB 快速添加默认落在日历选中的那天', (tester) async {
    final now = DateTime.now();
    // 选一个既不是今天也不是明天的日期，避免与快捷芯片语义混淆
    var pick = 1;
    while (pick == now.day || pick == now.day + 1) {
      pick++;
    }
    final target = DateTime(now.year, now.month, pick);

    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CalendarPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('calendar-grid')),
            matching: find.text('$pick'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final selectedChip = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((c) => c.selected)
        .toList();
    expect(
      (selectedChip.single.label as Text).data,
      '${target.month}月${target.day}日',
      reason: '快捷添加应默认选中日历上选中的那天',
    );

    await tester.enterText(find.byType(TextField).first, '走查用例日程');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final created = await ScheduleRepository().listActive();
    expect(created, hasLength(1));
    expect(created.first.startTime.day, target.day);
    expect(created.first.startTime.month, target.month);
  });

  testWidgets('时间轴上的日程卡可点进详情页', (tester) async {
    final now = DateTime.now();
    await ScheduleRepository().create(
      Schedule()
        ..title = '时间轴点击用例'
        ..startTime = DateTime(now.year, now.month, now.day, 10),
    );

    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CalendarPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('时间轴'));
    await tester.pumpAndSettle();
    expect(find.text('时间轴点击用例'), findsOneWidget);

    await tester.tap(find.text('时间轴点击用例'));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleDetailPage), findsOneWidget);
    expect(find.text('编辑日程'), findsOneWidget);
  });
}
