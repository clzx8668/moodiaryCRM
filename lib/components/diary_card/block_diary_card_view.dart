import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/diary_card/basic_card_logic.dart';
import 'package:moodiary/features/block/block_visuals.dart';
import 'package:moodiary/features/block/models/block.dart';

/// 首页块视图卡片：一条笔记一张卡，顶部色条数量 = 该笔记的子笔记（block）数，
/// 颜色与详情页块背景一致。支持长按/右键激活多选并删除整条记录。
class BlockDiaryCardComponent extends StatelessWidget with BasicCardLogic {
  const BlockDiaryCardComponent({
    super.key,
    required this.diary,
    required this.blocks,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final Diary diary;

  /// 该笔记下所有 block（含子笔记与 AI）
  final List<Block> blocks;

  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onLongPress;

  /// 子笔记（非 AI 的 block），其数量对应顶部色条数
  List<Block> get _noteBlocks =>
      blocks.where((b) => !b.meta.isAi).toList();

  String get _preview {
    if (diary.contentText.trim().isNotEmpty) {
      return diary.contentText.trim().removeLineBreaks();
    }
    if (_noteBlocks.isNotEmpty) {
      return _noteBlocks.first.content.trim().removeLineBreaks();
    }
    if (blocks.isNotEmpty) {
      return blocks.first.content.trim().removeLineBreaks();
    }
    return '';
  }

  String get _tagText {
    if (diary.tags.isNotEmpty) {
      return diary.tags.take(3).map((t) => '#$t').join('  ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeText = DateFormat('M月d日 HH:mm').format(diary.time);
    final strips = _noteBlocks.isEmpty ? 1 : _noteBlocks.length;

    return Card.filled(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppBorderRadius.mediumBorderRadius,
        onTap: selectionMode
            ? onSelectionChanged
            : () => toDiary(diary),
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：选中态圆圈 / 色条（数量 = 子笔记数）
              Row(
                children: [
                  if (selectionMode) ...[
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < strips; i++)
                          Container(
                            width: 28,
                            height: 3,
                            decoration: BoxDecoration(
                              color: blockTypeColor(
                                _noteBlocks.isEmpty
                                    ? BlockType.text
                                    : _noteBlocks[i].blockType,
                                colorScheme,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                timeText,
                style: context.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              if (_preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                EllipsisText(
                  _preview,
                  maxLines: 4,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
              if (_tagText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _tagText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
