import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/l10n/app_localizations.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_controller.dart';
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

    tmp = await Directory.systemTemp.createTemp('vault_test_');
    final sub = Directory('${tmp.path}/日记')..createSync(recursive: true);
    File('${sub.path}/2026-08-30.md').writeAsStringSync('# 你好\n[[目标笔记]]\n正文内容');
    File('${tmp.path}/目标笔记.md').writeAsStringSync('# 目标\n来自双链跳转');
    ObsidianConfig.enabled.value = true;
    ObsidianConfig.vaultPath.value = tmp.path;
  });

  tearDown(() async {
    ObsidianController.instance.selectedFile.value = null;
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  Future<void> preloadVault(WidgetTester tester) async {
    await tester.runAsync(
      () => ObsidianService.instance.scan(vaultPath: tmp.path, force: true),
    );
  }

  Widget wrap() => const GetMaterialApp(
    localizationsDelegates: [...AppLocalizations.localizationsDelegates],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ObsidianPage(),
  );

  testWidgets('Obsidian 页加载 Vault 后显示空态提示', (tester) async {
    await preloadVault(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Obsidian'), findsWidgets);
    expect(find.text('在左侧抽屉选择一篇 Obsidian 笔记'), findsOneWidget);
  });

  testWidgets('选中笔记后渲染 Markdown 与双链，点击双链跳转', (tester) async {
    await preloadVault(tester);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final note = ObsidianService.instance.files.firstWhere(
      (f) => f.linkName == '2026-08-30',
    );
    ObsidianController.instance.select(note);
    await tester.pumpAndSettle();

    expect(find.textContaining('正文内容'), findsOneWidget);
    expect(find.text('双链'), findsOneWidget);
    expect(find.text('目标笔记'), findsOneWidget);

    // 点击双链 chip → 切换到目标笔记
    await tester.tap(find.text('目标笔记'));
    await tester.pumpAndSettle();
    expect(find.textContaining('来自双链跳转'), findsOneWidget);
  });
}
