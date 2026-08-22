import 'package:flutter/material.dart';

/// 代码卡片：等宽字体容器，点击进入代码编辑。
class CodeCard extends StatelessWidget {
  final String content;

  const CodeCard({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
        ),
        maxLines: 12,
      ),
    );
  }
}
