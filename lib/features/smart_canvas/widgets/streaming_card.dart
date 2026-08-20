import 'package:flutter/material.dart';
import 'package:moodiary/features/block/block_renderer.dart';

/// AI 流式卡片：正在输出时渲染节流文本 + 停止按钮。
class StreamingCard extends StatelessWidget {
  final String buffer;
  final bool streaming;
  final VoidCallback? onStop;

  const StreamingCard({
    super.key,
    required this.buffer,
    required this.streaming,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = buffer.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty) MarkdownContentView(data: text),
        if (streaming)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI 正在处理…',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (onStop != null)
                  IconButton(
                    onPressed: onStop,
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      color: colorScheme.error,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: '停止',
                  ),
              ],
            ),
          )
        else if (text.isEmpty)
          Text(
            'AI 卡片（空）',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
