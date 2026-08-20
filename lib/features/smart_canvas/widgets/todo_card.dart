import 'package:flutter/material.dart';
import 'package:moodiary/features/block/models/block.dart';

/// 待办卡片：复选框 + 文本，点击原地勾选。
class TodoCard extends StatelessWidget {
  final Block block;
  final void Function(Block block)? onToggle;

  const TodoCard({super.key, required this.block, this.onToggle});

  static bool isDone(Block block) => block.content.trim().startsWith('[x]');

  static String textOf(Block block) => block.content
      .replaceFirst(RegExp(r'^\[[ xX]\]\s*'), '')
      .trim();

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: isDone(block),
      onChanged: onToggle == null ? null : (_) => onToggle!(block),
      title: Text(
        textOf(block),
        style: TextStyle(
          decoration: isDone(block)
              ? TextDecoration.lineThrough
              : TextDecoration.none,
          color: isDone(block)
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}
