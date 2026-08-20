import 'package:flutter/material.dart';
import 'package:moodiary/features/block/models/block.dart';

/// 智能卡片尾部：上下文操作（AI 处理 / 转待办 / 复制 / 停止 / 删除）。
class CardFooter extends StatelessWidget {
  final Block block;
  final VoidCallback? onAi;
  final VoidCallback? onConvertTodo;
  final VoidCallback? onCopy;
  final VoidCallback? onStop;
  final VoidCallback? onKeepAsChat;
  final VoidCallback? onDelete;

  const CardFooter({
    super.key,
    required this.block,
    this.onAi,
    this.onConvertTodo,
    this.onCopy,
    this.onStop,
    this.onKeepAsChat,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isStreaming = block.blockType == BlockType.aiStream &&
        !block.streamComplete;
    final isAiDone =
        block.blockType == BlockType.aiStream && block.streamComplete;

    return Row(
      children: [
        if (isStreaming)
          _FooterButton(
            icon: Icons.stop_circle_outlined,
            label: '停止',
            color: colorScheme.error,
            onTap: onStop,
          ),
        if (isAiDone) ...[
          _FooterButton(
            icon: Icons.auto_awesome_rounded,
            label: 'AI 处理',
            onTap: onAi,
          ),
          _FooterButton(
            icon: Icons.forum_outlined,
            label: '保留对话',
            onTap: onKeepAsChat,
          ),
        ] else if (block.blockType != BlockType.aiStream)
          _FooterButton(
            icon: Icons.auto_awesome_rounded,
            label: 'AI 处理',
            onTap: onAi,
          ),
        if (block.blockType != BlockType.todo &&
            block.blockType != BlockType.aiStream)
          _FooterButton(
            icon: Icons.check_circle_outline_rounded,
            label: '转待办',
            onTap: onConvertTodo,
          ),
        const Spacer(),
        _FooterButton(
          icon: Icons.copy_rounded,
          label: '复制',
          onTap: onCopy,
        ),
        _FooterButton(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          color: colorScheme.error,
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _FooterButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: effectiveColor),
            ),
          ],
        ),
      ),
    );
  }
}
