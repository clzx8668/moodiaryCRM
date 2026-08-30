import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/components/frosted_glass_overlay/frosted_glass_overlay_logic.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_controller.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/l10n/app_localizations.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/pages/home/diary/nav_sidebar.dart';
import 'package:moodiary/pages/home/home_logic.dart';
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48, child: Center(child: Text('标题行'))),
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 48,
                child: IconButton(
                  tooltip: '导航',
                  onPressed: logic.toggleNav,
                  icon: const Icon(Icons.menu_open_rounded),
                ),
              ),
              const Expanded(child: SizedBox(height: 48)),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NavSidebar(logic: logic),
                const Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> preloadVault(WidgetTester tester) async {
    await tester.runAsync(
      () => ObsidianService.instance.scan(vaultPath: tmp.path, force: true),
    );
  }

  testWidgets('移动端：默认收起，点图标展开，选分类后随动并自动收起', (tester) async {
    await preloadVault(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 默认收起：只显示展开图标
    expect(logic.state.navExpanded.value, isFalse);
    expect(find.text('日记分类'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu_open_rounded));
    await tester.pumpAndSettle();
    expect(logic.state.navExpanded.value, isTrue);
    expect(find.text('日记分类'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();
    expect(logic.tabController.index, 1);
    expect(logic.state.navExpanded.value, isFalse); // 移动端自动收起
  });

  testWidgets('移动端：Obsidian 树选中文件 → 切 tab + 共享选中态 + 自动收起', (tester) async {
    await preloadVault(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    logic.state.navExpanded.value = true;
    await tester.pumpAndSettle();
    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-08-30.md'));
    await tester.pumpAndSettle();

    expect(
      ObsidianController.instance.selectedFile.value?.linkName,
      '2026-08-30',
    );
    expect(logic.tabController.index, logic.state.categoryList.length + 1);
    expect(logic.state.navExpanded.value, isFalse); // 移动端自动收起
  });

  testWidgets('PC 端：选择分类后侧栏保持展开，可连续浏览', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await preloadVault(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    logic.state.navExpanded.value = true;
    await tester.pumpAndSettle();
    await tester.tap(find.text('生活'));
    await tester.pumpAndSettle();

    expect(logic.tabController.index, 2);
    expect(logic.state.navExpanded.value, isTrue); // PC 端保持展开
    debugDefaultTargetPlatformOverride = null; // 框架校验前必须复位
  });
}
