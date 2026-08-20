import 'package:flutter/material.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/smart_canvas/widgets/card_footer.dart';
import 'package:moodiary/features/smart_canvas/widgets/card_header.dart';
import 'package:moodiary/features/smart_canvas/widgets/chart_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/code_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/entity_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/image_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/streaming_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/text_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/todo_card.dart';

/// 智能卡片容器（Blinko 式）：统一壳 + 按类型委托内容卡。
///
/// 点击行为由 [onTap] 回调决定（页面层通过 CardActionRouter 注入），
/// 本组件只负责结构，不写业务路由。
class SmartCard extends StatelessWidget {
  final Block block;
  final bool expanded;
  final String streamBuffer;
  final bool isStreaming;

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
    required this.expanded,
    required this.streamBuffer,
    required this.isStreaming,
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeader(
                block: block,
                expanded: expanded,
                onToggleExpand: onToggleExpand,
              ),
              const SizedBox(height: 8),
              _buildBody(context),
              const SizedBox(height: 4),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 2),
              CardFooter(
                block: block,
                onAi: onAi,
                onConvertTodo: onConvertTodo,
                onCopy: onCopy,
                onStop: onStop,
                onKeepAsChat: onKeepAsChat,
                onResume: onResume,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
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
