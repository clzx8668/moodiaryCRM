import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moodiary/features/quick_capture/global_capture.dart';
import 'package:moodiary/persistence/pref.dart';

/// 桌面全局快捷键「闪念速记」：Ctrl + Alt + M 从任意程序唤起快速收集。
///
/// - 热键在 native runner（Windows 主消息循环）注册，命中后经
///   `moodiary/shortcut` 通道通知 Dart，再由本服务唤起收集面板；
/// - 仅 Windows 生效；开关默认开，可在「设置 → 工具」关闭（关闭时 native 注销热键，
///   不占用系统按键）。
class GlobalShortcutService {
  GlobalShortcutService._();

  static const MethodChannel channel = MethodChannel('moodiary/shortcut');
  static const String prefKey = 'globalHotkeyEnabled';

  /// 唤起收集面板的实现（测试可替换注入）。
  static Future<void> Function() captureOpener = GlobalCapture.open;

  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get enabled => PrefUtil.getValue<bool>(prefKey) ?? true;

  /// 首帧后调用：挂载通道回调，并把当前开关同步给 native。
  static Future<void> init() async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'hotkeyPressed') {
        await handleHotkey();
      }
    });
    await syncToNative();
  }

  /// 开关变更：写 Pref 并同步给 native（native 侧注册/注销热键）。
  static Future<void> setEnabled(bool value) async {
    await PrefUtil.setValue(prefKey, value);
    await syncToNative();
  }

  static Future<void> syncToNative() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<bool>('setEnabled', enabled);
    } catch (e) {
      debugPrintSynchronously('[hotkey] setEnabled 失败：$e');
      // 平台通道不可用（测试/非 Windows 构建）时静默
    }
  }

  /// 热键命中：开关开着才唤起收集面板。
  static Future<void> handleHotkey() async {
    if (!enabled) return;
    await captureOpener();
  }
}
