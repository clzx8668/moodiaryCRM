import 'package:flutter/services.dart';

/// 全局快捷键「组合键」描述（纯数据 + 纯函数，便于单测）。
///
/// [modifiers] 使用 Windows `RegisterHotKey` 的 MOD_* 位标志，
/// [virtualKey] 为虚拟键码（VK）；`MOD_NOREPEAT` 由 native 注册时附加。
class ShortcutSpec {
  const ShortcutSpec({required this.modifiers, required this.virtualKey});

  final int modifiers;
  final int virtualKey;

  /// 修饰键位标志（与 Win32 一致）
  static const int modAlt = 0x0001;
  static const int modControl = 0x0002;
  static const int modShift = 0x0004;
  static const int modWin = 0x0008;

  /// 默认组合：Ctrl + Alt + M（M = Moodiary / 闪念）
  static const ShortcutSpec defaultSpec = ShortcutSpec(
    modifiers: modControl | modAlt,
    virtualKey: 0x4D,
  );

  /// 必须至少含一个修饰键，且虚拟键码有效。
  bool get isValid => modifiers != 0 && virtualKey != 0;

  /// 展示文案：`Ctrl + Alt + M`
  String get label {
    final parts = <String>[];
    if (modifiers & modControl != 0) parts.add('Ctrl');
    if (modifiers & modAlt != 0) parts.add('Alt');
    if (modifiers & modShift != 0) parts.add('Shift');
    if (modifiers & modWin != 0) parts.add('Win');
    parts.add(keyLabel(virtualKey));
    return parts.join(' + ');
  }

  Map<String, dynamic> toJson() => {
    'modifiers': modifiers,
    'virtualKey': virtualKey,
  };

  static ShortcutSpec? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final modifiers = raw['modifiers'];
    final virtualKey = raw['virtualKey'];
    if (modifiers is! num || virtualKey is! num) return null;
    final spec = ShortcutSpec(
      modifiers: modifiers.toInt(),
      virtualKey: virtualKey.toInt(),
    );
    return spec.isValid ? spec : null;
  }

  /// 解析「按下的一组键」；不合法（无修饰键 / 不支持的键）返回 null。
  static ShortcutSpec? fromKeys({
    required LogicalKeyboardKey key,
    required bool control,
    required bool alt,
    required bool shift,
    required bool meta,
  }) {
    var modifiers = 0;
    if (control) modifiers |= modControl;
    if (alt) modifiers |= modAlt;
    if (shift) modifiers |= modShift;
    if (meta) modifiers |= modWin;
    if (modifiers == 0) return null;

    final virtualKey = virtualKeyOf(key);
    if (virtualKey == 0) return null;
    return ShortcutSpec(modifiers: modifiers, virtualKey: virtualKey);
  }

  /// 逻辑按键 → Windows 虚拟键码；不在白名单内返回 0。
  ///
  /// 白名单刻意收窄为「字母 / 数字 / F1–F12 / 空格」，避免出现难以表达或
  /// 与系统快捷键冲突的组合（如标点、IME 相关键）。
  static int virtualKeyOf(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    if (label.length == 1) {
      final code = label.toUpperCase().codeUnitAt(0);
      final isLetter = code >= 0x41 && code <= 0x5A;
      final isDigit = code >= 0x30 && code <= 0x39;
      if (isLetter || isDigit) return code;
      if (code == 0x20) return 0x20; // 空格
      return 0;
    }
    final match = RegExp(r'^F([1-9]|1[0-2])$').firstMatch(label);
    if (match != null) {
      return 0x70 + int.parse(match.group(1)!) - 1;
    }
    return 0;
  }

  static String keyLabel(int virtualKey) {
    if (virtualKey >= 0x41 && virtualKey <= 0x5A) {
      return String.fromCharCode(virtualKey);
    }
    if (virtualKey >= 0x30 && virtualKey <= 0x39) {
      return String.fromCharCode(virtualKey);
    }
    if (virtualKey >= 0x70 && virtualKey <= 0x7B) {
      return 'F${virtualKey - 0x70 + 1}';
    }
    if (virtualKey == 0x20) return 'Space';
    return 'VK 0x${virtualKey.toRadixString(16).toUpperCase()}';
  }
}
