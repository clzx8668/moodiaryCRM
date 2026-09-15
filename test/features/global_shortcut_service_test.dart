import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/quick_capture/global_shortcut_service.dart';
import 'package:moodiary/features/quick_capture/shortcut_spec.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 全局快捷键的 Dart 侧接线验证：
/// 开关 → 同步给 native；native 热键回调 → 唤起收集面板（开关为关时静默）。
///
/// native 侧（RegisterHotKey / WM_HOTKEY / 窗口置前）由实机走查验证。
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> platformCalls;
  var opened = 0;

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
    opened = 0;
    GlobalShortcutService.captureOpener = () async => opened++;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      GlobalShortcutService.channel,
      (call) async {
        platformCalls.add(call);
        if (call.method == 'setEnabled' || call.method == 'setShortcut') {
          return true;
        }
        return null;
      },
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      GlobalShortcutService.channel,
      null,
    );
  });

  test('init 把开关同步给 native（默认开）', () async {
    await GlobalShortcutService.init();
    expect(platformCalls, hasLength(1));
    expect(platformCalls.single.method, 'setShortcut');
    final args = platformCalls.single.arguments as Map;
    expect(args['enabled'], true);
    expect(args['modifiers'], ShortcutSpec.defaultSpec.modifiers);
    expect(args['virtualKey'], ShortcutSpec.defaultSpec.virtualKey);
  });

  test('关闭开关：同步 false 且热键不再唤起', () async {
    await GlobalShortcutService.init();
    await GlobalShortcutService.setEnabled(false);
    expect((platformCalls.last.arguments as Map)['enabled'], false);

    await GlobalShortcutService.handleHotkey();
    expect(opened, 0);
  });

  test('自定义组合键：写入 Pref 并同步给 native', () async {
    await GlobalShortcutService.init();
    const spec = ShortcutSpec(
      modifiers: ShortcutSpec.modControl | ShortcutSpec.modAlt,
      virtualKey: 0x4B, // Ctrl+Alt+K
    );
    final ok = await GlobalShortcutService.setSpec(spec);

    expect(ok, isTrue);
    expect(GlobalShortcutService.spec.virtualKey, 0x4B);
    final args = platformCalls.last.arguments as Map;
    expect(args['virtualKey'], 0x4B);
  });

  test('组合键被占用（native 注册失败）→ 回滚到上一个组合键', () async {
    await GlobalShortcutService.init();
    // 第一次注册默认组合成功
    expect(GlobalShortcutService.spec.virtualKey, 0x4D);
    // 之后让 native 一律返回失败，模拟组合键被其它程序占用
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      GlobalShortcutService.channel,
      (call) async {
        platformCalls.add(call);
        return false;
      },
    );
    const busy = ShortcutSpec(
      modifiers: ShortcutSpec.modControl | ShortcutSpec.modAlt,
      virtualKey: 0x4B,
    );
    final ok = await GlobalShortcutService.setSpec(busy);

    expect(ok, isFalse);
    expect(GlobalShortcutService.spec.virtualKey, 0x4D, reason: '应回滚默认组合');
    expect((platformCalls.last.arguments as Map)['virtualKey'], 0x4D);
  });

  test('开启时热键唤起收集面板', () async {
    await GlobalShortcutService.init();
    await GlobalShortcutService.handleHotkey();
    expect(opened, 1);
  });

  test('native 回调 hotkeyPressed 走同一条链路', () async {
    await GlobalShortcutService.init();
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'moodiary/shortcut',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('hotkeyPressed'),
      ),
      (_) {},
    );
    expect(opened, 1);
  });

  test('快捷键文案与开关键固定（设置页与提示共用）', () {
    expect(GlobalShortcutService.prefKey, 'globalHotkeyEnabled');
  });
}
