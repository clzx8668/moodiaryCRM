import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/quick_capture/tray_service.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 托盘常驻的 Dart 侧接线验证：开关同步给 native、隐藏到托盘的提示回调。
/// native 侧（Shell_NotifyIcon / 托盘菜单 / 关闭拦截）由实机走查验证。
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> platformCalls;
  var hiddenHints = 0;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PrefUtil.prefAllowList,
      ),
    );
    PrefUtil.overridePrefsForTest(prefs);
    platformCalls = [];
    hiddenHints = 0;
    TrayService.onHiddenHint = () => hiddenHints++;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      TrayService.channel,
      (call) async {
        platformCalls.add(call);
        return true;
      },
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      TrayService.channel,
      null,
    );
  });

  test('init 把「关闭到托盘」同步给 native（默认开）', () async {
    await TrayService.init();
    expect(platformCalls.single.method, 'setCloseToTray');
    expect(platformCalls.single.arguments, true);
  });

  test('关闭开关：同步 false（点关闭即退出）', () async {
    await TrayService.init();
    await TrayService.setEnabled(false);
    expect(platformCalls.last.arguments, false);
  });

  test('native 通知已隐藏到托盘 → 触发一次提示', () async {
    await TrayService.init();
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'moodiary/tray',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('hiddenToTray'),
      ),
      (_) {},
    );
    expect(hiddenHints, 1);
  });

  test('hideWindow / quit 走平台通道', () async {
    await TrayService.init();
    await TrayService.hideWindow();
    await TrayService.quit();
    expect(
      platformCalls.map((c) => c.method).toList(),
      ['setCloseToTray', 'hideWindow', 'quit'],
    );
  });

  test('Pref 键固定', () {
    expect(TrayService.prefKey, 'closeToTray');
  });
}
