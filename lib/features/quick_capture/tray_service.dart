import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 桌面托盘常驻：关闭窗口时隐藏到托盘（不退出进程），托盘菜单提供
/// 「打开 Moodiary / 快速收集 / 退出」。
///
/// - 仅桌面端生效；开关 `closeToTray` 默认开（设置 → 工具可关）；
/// - 托盘图标与菜单在 native runner 实现（`windows/runner/flutter_window.cpp`）；
///   「快速收集」复用全局快捷键同一条链路，不做第二套入口；
/// - 隐藏到托盘时给出一次轻提示，避免用户以为 App 退出了。
class TrayService {
  TrayService._();

  static const MethodChannel channel = MethodChannel('moodiary/tray');
  static const String prefKey = 'closeToTray';

  /// 隐藏到托盘时的提示实现（测试可替换注入）。
  static void Function()? onHiddenHint = _defaultHiddenHint;

  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get enabled => PrefUtil.getValue<bool>(prefKey) ?? true;

  static Future<void> init() async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'hiddenToTray') {
        onHiddenHint?.call();
      }
    });
    await syncToNative();
  }

  static Future<void> setEnabled(bool value) async {
    await PrefUtil.setValue(prefKey, value);
    await syncToNative();
  }

  static Future<void> syncToNative() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<bool>('setCloseToTray', enabled);
    } catch (_) {
      // 平台通道不可用（测试/非桌面构建）时静默
    }
  }

  /// 主动隐藏到托盘（native 侧执行 ShowWindow(SW_HIDE)）。
  static Future<void> hideWindow() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('hideWindow');
    } catch (_) {}
  }

  /// 真正退出（托盘菜单「退出」走 native 菜单，这里供设置/命令调用）。
  static Future<void> quit() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('quit');
    } catch (_) {}
  }

  static void _defaultHiddenHint() {
    toast.info(
      message: '已最小化到托盘：双击托盘图标或 Ctrl+Alt+M 唤起，托盘右键可退出',
    );
  }
}
