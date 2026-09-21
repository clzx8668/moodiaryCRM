import 'package:flutter/material.dart';
import 'package:moodiary/features/block/block_renderer.dart';
import 'package:moodiary/features/block/models/block.dart';

/// AI 瀑布流对话气泡（持久化 source=ai 块）。
///
/// 布局约定（批次 122/123）：
/// - **身份标签在气泡上方**（用户「我」/ 助手「AI 助手」+ 图标 + 转圈）；
/// - 气泡本体左右各留 12，**直接占满整行**——不再为左侧头像让出一列宽度，
///   所以左右既对称、又不浪费横向空间；
/// - 左右各自贴边（用户靠右、助手靠左），靠 `CrossAxisAlignment` 控制。
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

  /// 气泡两侧的固定留白：靠边但不贴死屏幕
  static const double sidePad = 12;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = block.meta.role == 'user';
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(
        left: sidePad,
        right: sidePad,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          // ① 身份放在气泡上方（不占左右空间）
          _identityLabel(
            context,
            isUser ? '我' : 'AI 助手',
            isUser ? colorScheme.onSurfaceVariant : colorScheme.primary,
            icon: isUser ? null : Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 4),
          // ② 气泡本体
          isUser ? _userBubble(context) : _assistantBubble(context),
        ],
      ),
    );
  }

  Widget _userBubble(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        block.content,
        style: TextStyle(color: colorScheme.onPrimaryContainer),
      ),
    );
  }

  Widget _assistantBubble(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

  /// 身份标签：放在气泡**上方**。
  ///
  /// 为什么不在左侧放头像：头像会占掉固定一列宽度，气泡左右都得为它让位。
  /// 放到上方后气泡本体左右各留 12 就能用满整行。
  Widget _identityLabel(
    BuildContext context,
    String text,
    Color color, {
    IconData? icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isStreaming) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ],
      ],
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
