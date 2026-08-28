import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/block/block_visuals.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/smart_canvas/widgets/chart_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/code_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/entity_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/image_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/streaming_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/text_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/todo_card.dart';

/// 智能卡片容器（闪念贝壳式）：顶部色条/「已生成卡片」标签 + 内容 + 底部标签/操作。
///
/// - [isAi] = false：笔记区卡片（色条 + 时间 + 内容 + #标签 + 复制/菜单）；
/// - [isAi] = true ：AI 交互区卡片（「已生成卡片：<模板>」 + 标题 + 内容 + 查看更多/复制/删除）。
/// 点击行为由 [onTap] 通过 CardActionRouter 注入，本组件只负责结构。
class SmartCard extends StatelessWidget {
  final Block block;
  final Diary diary;
  final bool expanded;
  final String streamBuffer;
  final bool isStreaming;

  /// 是否属于 AI 交互区（meta.source == ai）
  final bool isAi;

  final VoidCallback? onTap;
  final VoidCallback? onToggleExpand;
  final void Function(Block block)? onToggleTodo;
  final VoidCallback? onAi;
  final VoidCallback? onConvertTodo;
  final VoidCallback? onCopy;
  final VoidCallback? onStop;
  final VoidCallback? onKeepAsChat;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;

  const SmartCard({
    super.key,
    required this.block,
    required this.diary,
    required this.expanded,
    required this.streamBuffer,
    required this.isStreaming,
    required this.isAi,
    this.onTap,
    this.onToggleExpand,
    this.onToggleTodo,
    this.onAi,
    this.onConvertTodo,
    this.onCopy,
    this.onStop,
    this.onKeepAsChat,
    this.onResume,
    this.onDelete,
  });

  String get _relativeTime {
    final diff = DateTime.now().difference(block.updatedAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return DateFormat('M月d日 HH:mm').format(block.updatedAt);
  }

  String get _aiLabel {
    if (block.meta.aiTemplate.isNotEmpty) {
      return AiTemplates.label(block.meta.aiTemplate);
    }
    return blockTypeLabel(block.blockType);
  }

  String get _tagText {
    if (diary.tags.isNotEmpty) {
      return diary.tags.take(3).map((t) => '#$t').join('  ');
    }
    if (block.meta.source == BlockMeta.sourceAi) return '#AI';
    return '#${blockTypeLabel(block.blockType)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card.filled(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: blockBackground(block.blockType, colorScheme),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              isAi ? _buildAiHead(context) : _buildNoteHead(context),
              const SizedBox(height: 10),
              _buildBody(context),
              const SizedBox(height: 2),
              _buildFoot(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 笔记区头部：类型色条 + 来源徽标 + 时间。
  Widget _buildNoteHead(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meta = block.meta;
    return Row(
      children: [
        Text(
          _relativeTime,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (meta.source != BlockMeta.sourceInitial) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              blockSourceLabel(meta.source),
              style: TextStyle(fontSize: 10, color: colorScheme.onSurface),
            ),
          ),
        ],
        ..._statusIcons(colorScheme),
      ],
    );
  }

  /// AI 区头部：「已生成卡片：<模板>」+ 标题。
  Widget _buildAiHead(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = block.meta.title.isNotEmpty ? block.meta.title : _aiLabel;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已生成卡片：$_aiLabel',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Text(
          _relativeTime,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        ..._statusIcons(colorScheme),
      ],
    );
  }

  /// 待同步 / 冲突轻提示图标。
  List<Widget> _statusIcons(ColorScheme colorScheme) {
    final meta = block.meta;
    return [
      if (meta.isPending)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: '待同步',
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      if (meta.isConflict)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: '冲突',
            child: Icon(
              Icons.sync_problem_rounded,
              size: 13,
              color: colorScheme.error,
            ),
          ),
        ),
    ];
  }

  Widget _buildFoot(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isAi) {
      return Row(
        children: [
          if (isStreaming)
            _FootIcon(
              icon: Icons.stop_circle_outlined,
              tooltip: '停止',
              color: colorScheme.error,
              onTap: onStop,
            )
          else if (block.blockType == BlockType.aiStream &&
              !block.streamComplete)
            _FootIcon(
              icon: Icons.play_circle_outline_rounded,
              tooltip: '继续生成',
              onTap: onResume,
            )
          else
            // 展开/收起统一由正文卡片（TextCard）内的按钮控制，避免重复入口
            const SizedBox.shrink(),
          const Spacer(),
          _FootIcon(
            icon: Icons.copy_rounded,
            tooltip: '复制',
            onTap: onCopy,
          ),
          _FootIcon(
            icon: Icons.delete_outline_rounded,
            tooltip: '删除',
            color: colorScheme.error,
            onTap: onDelete,
          ),
        ],
      );
    }

    // 笔记区底部：左 #标签，右 复制 + ⋮ 菜单
    return Row(
      children: [
        Expanded(
          child: Text(
            _tagText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ),
        _FootIcon(
          icon: Icons.copy_rounded,
          tooltip: '复制',
          onTap: onCopy,
        ),
        PopupMenuButton<String>(
          tooltip: '更多',
          padding: EdgeInsets.zero,
          iconSize: 16,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(28, 26),
            maximumSize: const Size(28, 26),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            switch (v) {
              case 'edit':
                onTap?.call();
                break;
              case 'ai':
                onAi?.call();
                break;
              case 'todo':
                onConvertTodo?.call();
                break;
              case 'delete':
                onDelete?.call();
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'ai', child: Text('AI 处理')),
            if (block.blockType != BlockType.todo)
              const PopupMenuItem(value: 'todo', child: Text('转待办')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (block.blockType) {
      case BlockType.text:
        return TextCard(
          content: block.content,
          expanded: expanded,
          onToggleExpand: onToggleExpand ?? () {},
        );
      case BlockType.code:
        return CodeCard(content: block.content);
      case BlockType.todo:
        return TodoCard(block: block, onToggle: onToggleTodo);
      case BlockType.smartEntity:
        return EntityCard(block: block);
      case BlockType.image:
        return ImageCard(imageName: block.content.trim());
      case BlockType.chart:
        return ChartCard(content: block.content);
      case BlockType.aiStream:
        return StreamingCard(
          buffer: streamBuffer,
          streaming: isStreaming,
          onStop: onStop,
        );
    }
  }
}

class _FootIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _FootIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(28, 26),
        maximumSize: const Size(28, 26),
        padding: EdgeInsets.zero,
      ),
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
