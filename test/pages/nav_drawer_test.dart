import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_controller.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/components/frosted_glass_overlay/frosted_glass_overlay_logic.dart';
import 'package:moodiary/l10n/app_localizations.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/pages/home/diary/nav_drawer.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/db_test_helper.dart';

/// 测试用 DiaryLogic：跳过 onReady 对 NestedScrollView.innerController 的依赖
/// （真实页面里由 DiaryTabView 注入；测试只需 tab 控制器与分类跳转）。
class _FakeDiaryLogic extends DiaryLogic {
  @override
  // ignore: must_call_super
  void onInit() {
    tabController = TabController(
      length: state.categoryList.length + 1 + (ObsidianConfig.isReady ? 1 : 0),
      vsync: this,
    );
    // 不调用 super.onInit()：不触发 autoSync / onReady / innerController
  }
}

void main() {
  late AppDatabase db;
  late Directory tmp;
  late DiaryLogic logic;

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
    await prefs.setString('customTitleName', '');
    await prefs.setInt('homeViewMode', 0);

    db = openTestDb();
    tmp = await Directory.systemTemp.createTemp('vault_test_');
    final sub = Directory('${tmp.path}/日记')..createSync(recursive: true);
    File('${sub.path}/2026-08-30.md').writeAsStringSync('# 你好\n正文内容');

    // 启用 Obsidian（先于 DiaryLogic 创建，保证 tab 长度含 Obsidian 槽位）
    ObsidianConfig.enabled.value = true;
    ObsidianConfig.vaultPath.value = tmp.path;
    await IsarUtil.insertACategory(Category()..categoryName = '工作');
    await IsarUtil.insertACategory(Category()..categoryName = '生活');

    Get.put(FrostedGlassOverlayLogic());
    Get.put(HomeLogic());
    logic = Get.put<DiaryLogic>(_FakeDiaryLogic());
    await logic.updateCategory();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
    closeTestDb(db);
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  Widget wrap() => MaterialApp(
    localizationsDelegates: const [...AppLocalizations.localizationsDelegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      key: logic.navDrawerKey,
      drawer: NavDrawer(logic: logic),
      body: const SizedBox.expand(),
    ),
  );

  Future<void> openDrawer(WidgetTester tester) async {
    logic.navDrawerKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('抽屉展示分类树，点击分类随动跳 tab 并自动收起（移动端）', (tester) async {
    await tester.runAsync(
      () => ObsidianService.instance.scan(vaultPath: tmp.path, force: true),
    );
    await tester.pumpWidget(wrap());
    await openDrawer(tester);

    expect(find.text('日记分类'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('生活'), findsOneWidget);

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    // tab 随动
    expect(logic.tabController.index, 1);
    // 移动端自动收起（抽屉头部「导航」消失）
    expect(find.text('导航'), findsNothing);
  });

  testWidgets('抽屉 Obsidian 子树选中文件 → 切 tab + 共享选中态', (tester) async {
    await tester.runAsync(
      () => ObsidianService.instance.scan(vaultPath: tmp.path, force: true),
    );
    await tester.pumpWidget(wrap());
    await openDrawer(tester);

    expect(find.text('Obsidian'), findsOneWidget);
    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-08-30.md'));
    await tester.pumpAndSettle();

    expect(
      ObsidianController.instance.selectedFile.value?.linkName,
      '2026-08-30',
    );
    expect(logic.tabController.index, logic.state.categoryList.length + 1);
    expect(find.text('导航'), findsNothing); // 移动端自动收起
  });

  testWidgets('PC 端选择分类后抽屉保持打开，可连续浏览', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.runAsync(
      () => ObsidianService.instance.scan(vaultPath: tmp.path, force: true),
    );
    await tester.pumpWidget(wrap());
    await openDrawer(tester);

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    expect(logic.tabController.index, 1);
    expect(find.text('导航'), findsOneWidget); // PC 端保持打开
    debugDefaultTargetPlatformOverride = null; // 框架校验前必须复位
  });
}
