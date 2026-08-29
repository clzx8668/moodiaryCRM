import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/l10n/app_localizations.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_page.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late Directory tmp;

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

    // 构造带子目录 + 双链的临时 Vault
    tmp = await Directory.systemTemp.createTemp('vault_test_');
    final sub = Directory('${tmp.path}/日记')..createSync(recursive: true);
    File('${sub.path}/2026-08-30.md')
        .writeAsStringSync('# 你好\n[[目标笔记]]\n正文内容');
    File('${tmp.path}/目标笔记.md').writeAsStringSync('# 目标\n来自双链跳转');
    ObsidianConfig.vaultPath.value = tmp.path;
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  /// 预热 Obsidian 服务缓存（真实文件 I/O 放行到 runAsync 区执行）。
  Future<void> preloadVault(WidgetTester tester) async {
    await tester.runAsync(
      () => ObsidianService.instance.scan(vaultPath: tmp.path, force: true),
    );
  }

  testWidgets('Obsidian 页加载 Vault 不崩溃（回归：const [] 树构建）',
      (tester) async {
    await preloadVault(tester);
    await tester.pumpWidget(
      const GetMaterialApp(
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ObsidianPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 默认空态提示（未选文件）
    expect(find.text('Obsidian'), findsWidgets);
    expect(find.text('从右侧文件目录树选择一篇笔记'), findsOneWidget);
  });

  testWidgets('文件树抽屉可打开，显示目录/文件并选中渲染（含反斜杠路径）',
      (tester) async {
    await preloadVault(tester);
    await tester.pumpWidget(
      const GetMaterialApp(
        localizationsDelegates: [
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ObsidianPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 空态「打开文件目录树」按钮弹出右侧抽屉
    await tester.tap(find.text('打开文件目录树'));
    await tester.pumpAndSettle();

    // 目录节点（ExpansionTile 标题）
    expect(find.text('日记'), findsOneWidget);
    expect(find.text('目标笔记.md'), findsOneWidget);
    expect(find.text('2026-08-30.md'), findsNothing); // 折叠在子目录内

    // 展开「日记」目录
    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    expect(find.text('2026-08-30.md'), findsOneWidget);

    // 选中文件：关闭抽屉并渲染 Markdown
    await tester.tap(find.text('2026-08-30.md'));
    await tester.pumpAndSettle();
    expect(find.textContaining('正文内容'), findsOneWidget);
    expect(find.text('双链'), findsOneWidget);
  });
}
