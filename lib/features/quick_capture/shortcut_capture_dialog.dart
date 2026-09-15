import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary/features/quick_capture/shortcut_spec.dart';

/// 录制新的全局快捷键组合（按下即取，需含 Ctrl/Alt/Shift/Win 之一）。
///
/// 返回用户确认的组合键；取消返回 null。
class ShortcutCaptureDialog extends StatefulWidget {
  const ShortcutCaptureDialog({super.key});

  /// 支持的键位提示（与 [ShortcutSpec.virtualKeyOf] 的白名单一致）。
  static const String hint = '按住 Ctrl / Alt / Shift / Win 之一，再按字母、数字或 F1–F12';

  static Future<ShortcutSpec?> show(BuildContext context) {
    return showDialog<ShortcutSpec>(
      context: context,
      builder: (_) => const ShortcutCaptureDialog(),
    );
  }

  @override
  State<ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<ShortcutCaptureDialog> {
  ShortcutSpec? _captured;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('设置全局快捷键'),
      content: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          final spec = ShortcutSpec.fromKeys(
            key: event.logicalKey,
            control: HardwareKeyboard.instance.isControlPressed,
            alt: HardwareKeyboard.instance.isAltPressed,
            shift: HardwareKeyboard.instance.isShiftPressed,
            meta: HardwareKeyboard.instance.isMetaPressed,
          );
          setState(() {
            if (spec == null) {
              _captured = null;
              _error = '请至少按住一个修饰键，并搭配字母/数字/F1–F12';
            } else {
              _captured = spec;
              _error = null;
            }
          });
          return KeyEventResult.handled;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ShortcutCaptureDialog.hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _captured?.label ?? '请按下组合键…',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _captured == null
              ? null
              : () => Navigator.of(context).pop(_captured),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
