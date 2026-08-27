import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/view_mode.dart';
import 'package:moodiary/components/base/clipper.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/diary_card/block_diary_card_view.dart';
import 'package:moodiary/components/diary_card/grid_diary_card_view.dart';
import 'package:moodiary/components/diary_card/list_diary_card_view.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import 'diary_tab_view_logic.dart';

class DiaryTabViewComponent extends StatelessWidget {
  const DiaryTabViewComponent({super.key, required this.categoryId});

  final String? categoryId;

  /// 按当前标签筛选过滤（列表/网格共用）
  List<Diary> _visibleDiaries(List<Diary> all, DiaryTabViewLogic logic) {
    final tags = logic.diaryLogic.state.filterTags;
    if (tags.isEmpty) return all;
    return all.where((d) => d.tags.any(tags.contains)).toList();
  }

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
        final items = _visibleDiaries(state.diaryList, logic);
        return SliverWaterfallFlow(
          gridDelegate: const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            return GirdDiaryCardComponent(diary: items[index]);
          }, childCount: items.length),
        );
      }, key: const ValueKey('grid'));
    }

    Widget buildList() {
      return Obx(() {
        final items = _visibleDiaries(state.diaryList, logic);
        return SliverList.separated(
          itemBuilder: (context, index) {
            return ListDiaryCardComponent(
              tag: index.toString(),
              diary: items[index],
            );
          },
          separatorBuilder: (context, index) {
            return const SizedBox(height: 8.0);
          },
          itemCount: items.length,
        );
      }, key: const ValueKey('list'));
    }

    Widget buildBlock(DiaryTabViewLogic logic) {
      return _BlockView(categoryId: categoryId, tabLogic: logic);
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
                          ViewModeType.block => buildBlock(logic),
                        },
              );
            }),
          ],
        ),
      ),
    );
  }

}

/// 块视图：一条笔记一张卡（色条数量=子笔记数），支持长按/右键多选并删除整条记录。
class _BlockView extends StatefulWidget {
  final String? categoryId;
  final DiaryTabViewLogic tabLogic;

  const _BlockView({this.categoryId, required this.tabLogic});

  @override
  State<_BlockView> createState() => _BlockViewState();
}

class _BlockViewState extends State<_BlockView> {
  bool _loading = true;
  bool _selectionMode = false;
  final Set<String> _selected = <String>{};
  Map<String, List<Block>> _blocksByDiary = {};
  StreamSubscription<void>? _listener;
  StreamSubscription<void>? _tagListener;

  @override
  void initState() {
    super.initState();
    // 列表/网格数据（含从详情页返回后的更新）变化时，重载块视图
    _listener = widget.tabLogic.state.diaryList.listen((_) => _load());
    // 标签筛选变化时重绘
    _tagListener = widget.tabLogic.diaryLogic.state.filterTags.listen(
      (_) => setState(() {}),
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _listener?.cancel();
    _tagListener?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final blocks = await IsarUtil.getAllVisibleBlocks();
    final map = <String, List<Block>>{};
    for (final b in blocks) {
      (map[b.diaryId] ??= []).add(b);
    }
    if (!mounted) return;
    setState(() {
      _blocksByDiary = map;
      _loading = false;
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    try {
      for (final id in _selected) {
        Diary? diary;
        for (final d in widget.tabLogic.state.diaryList) {
          if (d.id == id) {
            diary = d;
            break;
          }
        }
        if (diary != null) {
          await IsarUtil.moveDiaryToRecycle(diary.isarId);
        }
        // 同步软删该日记下的子笔记块，避免残留
        await IsarUtil.softDeleteBlocksByDiary(id);
      }
      toast.success(message: '已删除 ${_selected.length} 条记录');
    } catch (e) {
      toast.error(message: '删除失败：$e');
    }
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
    try {
      await Bind.find<DiaryLogic>().refreshAll();
    } catch (_) {
      // 分类/列表刷新失败则忽略（块视图自身已重载）
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final slivers = <Widget>[];
    if (_selectionMode) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                Text(
                  '已选 ${_selected.length} 条',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: _deleteSelected,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('删除'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selectionMode = false;
                    _selected.clear();
                  }),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final all = widget.tabLogic.state.diaryList;
    final tags = widget.tabLogic.diaryLogic.state.filterTags;
    final diaries = tags.isEmpty
        ? all
        : all.where((d) => d.tags.any(tags.contains)).toList();
    if (diaries.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                '还没有内容，点右下角 + 记下第一篇吧',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      );
    } else {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverList.separated(
            key: const ValueKey('block'),
            itemBuilder: (context, index) {
              final diary = diaries[index];
              final blocks = _blocksByDiary[diary.id] ?? <Block>[];
              final selected = _selected.contains(diary.id);
              return BlockDiaryCardComponent(
                diary: diary,
                blocks: blocks,
                selectionMode: _selectionMode,
                selected: selected,
                onSelectionChanged: () => _toggleSelect(diary.id),
                onLongPress: () => setState(() {
                  _selectionMode = true;
                  _selected.add(diary.id);
                }),
              );
            },
            separatorBuilder: (context, index) =>
                const SizedBox(height: 8.0),
            itemCount: diaries.length,
          ),
        ),
      );
    }
    return SliverMainAxisGroup(slivers: slivers);
  }
}
