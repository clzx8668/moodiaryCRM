import 'package:flutter/material.dart';
import 'package:moodiary/features/block/block_renderer.dart';
import 'package:moodiary/features/block/models/block.dart';

/// AI 瀑布流对话气泡（持久化 source=ai 块）：用户（右）/ 助手（左，可 复制/更多·重新生成）。
class ChatBubble extends StatelessWidget {
  final Block block;
  final bool isStreaming;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onStop;

  const ChatBubble({
    super.key,
    required this.block,
    this.isStreaming = false,
    this.onCopy,
    this.onRegenerate,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = block.meta.role == 'user';
    // 气泡两侧的安全边距固定为 12，保证"左右对称、不贴死屏幕"；
    // 可用空间小的时候（窄屏/分栏）自动收窄对侧的空白，
    // 这样窄屏也能把内容用满，而不是被固定的 48/24 挤扁。
    const sidePad = 12.0;
    const bubbleMaxFraction = 0.78;
    final available = MediaQuery.sizeOf(context).width;
    final bubbleMax = available * bubbleMaxFraction;
    // 对侧最小留白：让气泡看起来是"靠边但没贴死"
    const oppositeMin = 12.0;
    final oppositeMax = isUser ? 48.0 : 24.0;
    final opposite = (available - bubbleMax - sidePad).clamp(
      oppositeMin,
      oppositeMax,
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: EdgeInsets.only(
            left: opposite,
            right: sidePad,
            bottom: 8,
          ),
          constraints: BoxConstraints(maxWidth: bubbleMax),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            block.content,
            style: TextStyle(color: colorScheme.onPrimaryContainer),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(
        left: sidePad,
        right: opposite,
        bottom: 8,
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'AI',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (isStreaming)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (block.content.isNotEmpty)
            MarkdownContentView(data: block.content),
          if (isStreaming && block.content.isEmpty)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                'AI 正在思考…',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              _BubbleAction(
                icon: Icons.copy_rounded,
                tooltip: '复制',
                onTap: onCopy,
              ),
              if (isStreaming)
                _BubbleAction(
                  icon: Icons.stop_circle_outlined,
                  tooltip: '停止',
                  onTap: onStop,
                  color: colorScheme.error,
                )
              else
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz_rounded, size: 18),
                  tooltip: '更多',
                  onSelected: (v) {
                    if (v == 'regen') onRegenerate?.call();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'regen', child: Text('重新生成')),
                  ],
                ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubbleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _BubbleAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
