import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/quick_capture/shortcut_spec.dart';

ShortcutSpec? _from(
  LogicalKeyboardKey key, {
  bool ctrl = false,
  bool alt = false,
  bool shift = false,
  bool meta = false,
}) => ShortcutSpec.fromKeys(
  key: key,
  control: ctrl,
  alt: alt,
  shift: shift,
  meta: meta,
);

void main() {
  group('ShortcutSpec 解析', () {
    test('Ctrl+Alt+M → 默认组合', () {
      final spec = _from(LogicalKeyboardKey.keyM, ctrl: true, alt: true)!;
      expect(spec.modifiers, ShortcutSpec.modControl | ShortcutSpec.modAlt);
      expect(spec.virtualKey, 0x4D);
      expect(spec.label, 'Ctrl + Alt + M');
      expect(spec.isValid, isTrue);
    });

    test('单个修饰键 + 字母/数字/F 键均可', () {
      expect(_from(LogicalKeyboardKey.keyK, ctrl: true)!.virtualKey, 0x4B);
      expect(_from(LogicalKeyboardKey.digit7, alt: true)!.virtualKey, 0x37);
      expect(_from(LogicalKeyboardKey.f9, shift: true)!.virtualKey, 0x78);
      expect(_from(LogicalKeyboardKey.space, meta: true)!.virtualKey, 0x20);
    });

    test('无修饰键 / 纯修饰键 / 非白名单键 → null', () {
      expect(_from(LogicalKeyboardKey.keyM), isNull);
      expect(_from(LogicalKeyboardKey.controlLeft, ctrl: true), isNull);
      expect(_from(LogicalKeyboardKey.comma, ctrl: true), isNull);
      expect(_from(LogicalKeyboardKey.f13, ctrl: true), isNull);
    });

    test('多修饰键组合标签顺序固定为 Ctrl/Alt/Shift/Win', () {
      final spec = _from(
        LogicalKeyboardKey.f5,
        ctrl: true,
        alt: true,
        shift: true,
        meta: true,
      )!;
      expect(spec.label, 'Ctrl + Alt + Shift + Win + F5');
    });
  });

  group('ShortcutSpec 序列化与文案', () {
    test('JSON 往返一致', () {
      const spec = ShortcutSpec(
        modifiers: ShortcutSpec.modControl | ShortcutSpec.modShift,
        virtualKey: 0x4B,
      );
      final restored = ShortcutSpec.fromJson(spec.toJson())!;
      expect(restored.modifiers, spec.modifiers);
      expect(restored.virtualKey, spec.virtualKey);
      expect(restored.label, 'Ctrl + Shift + K');
    });

    test('非法 JSON / 缺字段 / 无修饰键 → null', () {
      expect(ShortcutSpec.fromJson(null), isNull);
      expect(ShortcutSpec.fromJson({'modifiers': 2}), isNull);
      expect(
        ShortcutSpec.fromJson({'modifiers': 0, 'virtualKey': 0x4B}),
        isNull,
      );
    });

    test('未知虚拟键码仍有可读文案', () {
      expect(ShortcutSpec.keyLabel(0x7B), 'F12');
      expect(ShortcutSpec.keyLabel(0xBA), 'VK 0xBA');
    });
  });
}
