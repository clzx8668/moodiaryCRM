import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/view_mode.dart';
import 'package:moodiary/components/base/clipper.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/diary_card/grid_diary_card_view.dart';
import 'package:moodiary/components/diary_card/list_diary_card_view.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import 'diary_tab_view_logic.dart';

class DiaryTabViewComponent extends StatelessWidget {
  const DiaryTabViewComponent({super.key, required this.categoryId});

  final String? categoryId;

  Widget _buildPlaceholder(double height) {
    return SliverToBoxAdapter(
      key: const ValueKey('placeholder'),
      child: SizedBox(height: height, child: const MoodiaryLoading()),
    );
  }

  Widget _buildEmpty(BuildContext context, double height) {
    return SliverToBoxAdapter(
      key: const ValueKey('empty'),
      child: SizedBox(
        height: height,
        child: Center(child: Text(context.l10n.diaryTabViewEmpty)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logicTag = categoryId ?? 'default';
    final barHeight = 46 + kToolbarHeight + MediaQuery.paddingOf(context).top;
    final logic = Get.put(
      DiaryTabViewLogic(categoryId: categoryId),
      tag: logicTag,
    );
    final state = Bind.find<DiaryTabViewLogic>(tag: logicTag).state;
    final size = MediaQuery.sizeOf(context);
    final placeholderHeight =
        size.height -
        barHeight -
        MediaQuery.paddingOf(context).bottom -
        56 -
        46;

    Widget buildGrid() {
      return Obx(() {
        return SliverWaterfallFlow(
          gridDelegate: const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            return GirdDiaryCardComponent(diary: state.diaryList[index]);
          }, childCount: state.diaryList.length),
        );
      }, key: const ValueKey('grid'));
    }

    Widget buildList() {
      return Obx(() {
        return SliverList.separated(
          itemBuilder: (context, index) {
            return ListDiaryCardComponent(
              tag: index.toString(),
              diary: state.diaryList[index],
            );
          },
          separatorBuilder: (context, index) {
            return const SizedBox(height: 8.0);
          },
          itemCount: state.diaryList.length,
        );
      }, key: const ValueKey('list'));
    }

    Widget buildBlock() {
      return FutureBuilder<({List<Diary> diaries, List<Block> blocks})>(
        future: _loadBlockData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildPlaceholder(placeholderHeight);
          }
          final diaryById = {
            for (final d in snapshot.data!.diaries) d.id: d,
          };
          final filtered = snapshot.data!.blocks.where((block) {
            final diary = diaryById[block.diaryId];
            if (diary == null) return false;
            if (categoryId != null && diary.categoryId != categoryId) {
              return false;
            }
            return true;
          }).toList();
          if (filtered.isEmpty) {
            return SliverToBoxAdapter(
              key: const ValueKey('block-empty'),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无 Block 数据（保存速记或执行迁移后可见）',
                    style: context.textTheme.bodySmall,
                  ),
                ),
              ),
            );
          }
          return SliverList.separated(
            key: const ValueKey('block'),
            itemBuilder: (context, index) {
              final block = filtered[index];
              final diary = diaryById[block.diaryId]!;
              return Card.outlined(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(_blockIcon(block.blockType)),
                  title: Text(
                    diary.title.isEmpty ? '未命名日记' : diary.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    block.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${block.blockType.name} · '
                    '${block.updatedAt.toLocal()}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) {
              return const SizedBox(height: 8.0);
            },
            itemCount: filtered.length,
          );
        },
      );
    }

    final sliverHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
      context,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      child: ClipRRect(
        clipper: TopRRectClipper(
          topOffset: sliverHandle.layoutExtent ?? barHeight,
        ),
        child: CustomScrollView(
          cacheExtent: size.height * 2,
          slivers: [
            SliverOverlapInjector(handle: sliverHandle),
            Obx(() {
              return SliverAnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                reverseDuration: const Duration(milliseconds: 100),
                child:
                    state.isFetching.value
                        ? _buildPlaceholder(placeholderHeight)
                        : state.diaryList.isEmpty
                        ? _buildEmpty(context, placeholderHeight)
                        : switch (logic.diaryLogic.state.viewModeType.value) {
                          ViewModeType.list => buildList(),
                          ViewModeType.grid => buildGrid(),
                          ViewModeType.block => buildBlock(),
                        },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<({List<Diary> diaries, List<Block> blocks})> _loadBlockData() async {
    final diaries = await IsarUtil.getAllDiariesSorted();
    final blocks = await IsarUtil.getAllVisibleBlocks();
    return (diaries: diaries, blocks: blocks);
  }

  IconData _blockIcon(BlockType type) {
    switch (type) {
      case BlockType.text:
        return Icons.notes_rounded;
      case BlockType.todo:
        return Icons.check_circle_rounded;
      case BlockType.image:
        return Icons.image_rounded;
      case BlockType.aiStream:
        return Icons.auto_awesome_rounded;
      case BlockType.smartEntity:
        return Icons.widgets_rounded;
      case BlockType.chart:
        return Icons.bar_chart_rounded;
      case BlockType.code:
        return Icons.code_rounded;
    }
  }
}
