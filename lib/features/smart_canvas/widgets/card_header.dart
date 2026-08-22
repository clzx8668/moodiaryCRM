import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/features/block/models/block.dart';

/// 智能卡片头部：类型图标 + 来源徽标 + 时间 + 同步状态点 + 展开/收起。
class CardHeader extends StatelessWidget {
  final Block block;
  final bool expanded;
  final VoidCallback? onToggleExpand;

  const CardHeader({
    super.key,
    required this.block,
    required this.expanded,
    this.onToggleExpand,
  });

  static IconData typeIcon(BlockType type) {
    switch (type) {
      case BlockType.text:
        return Icons.notes_rounded;
      case BlockType.smartEntity:
        return Icons.widgets_rounded;
      case BlockType.todo:
        return Icons.check_circle_outline_rounded;
      case BlockType.chart:
        return Icons.bar_chart_rounded;
      case BlockType.aiStream:
        return Icons.auto_awesome_rounded;
      case BlockType.image:
        return Icons.image_rounded;
      case BlockType.code:
        return Icons.code_rounded;
    }
  }

  static String sourceLabel(BlockMeta meta) {
    switch (meta.source) {
      case BlockMeta.sourceInitial:
        return '原始';
      case BlockMeta.sourceAppended:
        return '追加';
      case BlockMeta.sourceAi:
        return 'AI';
      case BlockMeta.sourceImported:
        return '导入';
      default:
        return meta.source;
    }
  }

  static Color? sourceColor(BlockMeta meta, ColorScheme colorScheme) {
    switch (meta.source) {
      case BlockMeta.sourceAppended:
        return colorScheme.tertiaryContainer;
      case BlockMeta.sourceAi:
        return colorScheme.primaryContainer;
      case BlockMeta.sourceImported:
        return colorScheme.secondaryContainer;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meta = block.meta;
    final timeText = DateFormat.yMMMd()
        .add_Hms()
        .format(block.updatedAt)
        .replaceFirst(' ', '\n');

    return Row(
      children: [
        Icon(typeIcon(block.blockType), size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: sourceColor(meta, colorScheme),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            sourceLabel(meta),
            style: TextStyle(fontSize: 10, color: colorScheme.onSurface),
          ),
        ),
        if (meta.aiTemplate.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            meta.aiTemplate,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          timeText,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
            height: 1.2,
          ),
        ),
        const Spacer(),
        if (meta.isPending)
          Tooltip(
            message: '待同步',
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        if (meta.isConflict)
          Tooltip(
            message: '冲突',
            child: Icon(
              Icons.sync_problem_rounded,
              size: 14,
              color: colorScheme.error,
            ),
          ),
        if (onToggleExpand != null)
          IconButton(
            onPressed: onToggleExpand,
            icon: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: expanded ? '收起' : '展开',
          ),
      ],
    );
  }
}
