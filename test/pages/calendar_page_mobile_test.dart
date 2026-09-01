import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/pages/home/calendar/calendar_view.dart';
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
}
