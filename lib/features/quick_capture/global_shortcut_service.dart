import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/quick_capture/global_capture.dart';
import 'package:moodiary/features/quick_capture/shortcut_spec.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 桌面全局快捷键「闪念速记」：默认 Ctrl + Alt + M（可自定义），从任意程序唤起快速收集。
///
/// - 热键在 native runner（Windows 主消息循环）注册，命中后经
///   `moodiary/shortcut` 通道通知 Dart，再由本服务唤起收集面板；
/// - 仅 Windows 生效；开关默认开，可在「设置 → 工具」关闭（关闭时 native 注销热键，
///   不占用系统按键）。
class GlobalShortcutService {
  GlobalShortcutService._();

  static const MethodChannel channel = MethodChannel('moodiary/shortcut');
  static const String prefKey = 'globalHotkeyEnabled';

  /// 自定义组合键的 Pref 键（JSON：{modifiers, virtualKey}）。
  static const String specPrefKey = 'globalHotkeySpec';

  /// 唤起收集面板的实现（测试可替换注入）。
  static Future<void> Function() captureOpener = GlobalCapture.open;

  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get enabled => PrefUtil.getValue<bool>(prefKey) ?? true;

  /// 当前组合键：Pref 有存用存的，否则默认 Ctrl+Alt+M。
  ///
  /// 调试期可用环境变量 `MOODIARY_SHORTCUT_SPEC=3:0x4B` 临时覆盖
  /// （mods:十六进制 VK），便于无 UI 交互时验证注册与冲突路径。
  static ShortcutSpec get spec {
    if (kDebugMode) {
      final override = Platform.environment['MOODIARY_SHORTCUT_SPEC'];
      if (override != null && override.contains(':')) {
        final parts = override.split(':');
        final parsed = ShortcutSpec(
          modifiers: int.tryParse(parts[0].trim()) ?? 0,
          virtualKey:
              int.tryParse(parts[1].trim().replaceAll('0x', ''), radix: 16) ??
                  0,
        );
        if (parsed.isValid) return parsed;
      }
    }
    final raw = PrefUtil.getValue<String>(specPrefKey);
    if (raw == null || raw.trim().isEmpty) return ShortcutSpec.defaultSpec;
    try {
      return ShortcutSpec.fromJson(jsonDecode(raw)) ??
          ShortcutSpec.defaultSpec;
    } catch (_) {
      return ShortcutSpec.defaultSpec;
    }
  }

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

  /// 应用新的组合键：先写 Pref，再交给 native 注册；注册失败（被其它程序占用）
  /// 则回滚 Pref 并提示，返回是否成功。
  static Future<bool> setSpec(ShortcutSpec value) async {
    if (!value.isValid) return false;
    final previous = spec;
    await PrefUtil.setValue<String>(specPrefKey, jsonEncode(value.toJson()));
    if (await syncToNative()) return true;

    await PrefUtil.setValue<String>(
      specPrefKey,
      jsonEncode(previous.toJson()),
    );
    await syncToNative();
    if (_hasUiContext) {
      toast.error(message: '${value.label} 注册失败：可能已被其它程序占用');
    }
    return false;
  }

  /// 是否有可用的 UI 上下文（测试/后台环境 `Get.context` 会抛异常）。
  static bool get _hasUiContext {
    try {
      return Get.context != null;
    } catch (_) {
      return false;
    }
  }

  /// 把开关与组合键同步给 native；返回是否注册成功。
  static Future<bool> syncToNative() async {
    if (!supported) return false;
    try {
      final registered = await channel.invokeMethod<bool>('setShortcut', {
        'enabled': enabled,
        'modifiers': spec.modifiers,
        'virtualKey': spec.virtualKey,
      });
      return registered ?? false;
    } catch (_) {
      // 平台通道不可用（测试/非 Windows 构建）时静默
      return false;
    }
  }

  /// 热键命中：开关开着才唤起收集面板。
  static Future<void> handleHotkey() async {
    if (!enabled) return;
    await captureOpener();
  }
}
