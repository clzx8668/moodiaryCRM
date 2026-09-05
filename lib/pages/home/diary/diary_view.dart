import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/view_mode.dart';
import 'package:moodiary/common/values/diary_sort.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/base/sheet.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_page.dart';
import 'package:moodiary/components/diary_tab_view/diary_tab_view_view.dart';
import 'package:moodiary/components/keepalive/keepalive.dart';
import 'package:moodiary/components/scroll/fix_scroll.dart';
import 'package:moodiary/components/search_sheet/search_sheet_view.dart';
import 'package:moodiary/components/sync_dash_board/sync_dash_board_view.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/utils/webdav_util.dart';

import 'diary_logic.dart';
import '../home_logic.dart';
import 'nav_sidebar.dart';

/// 首页筛选弹层：按标签多选（列表/网格/块三视图共用）
class _DiaryFilterSheet extends StatefulWidget {
  final DiaryLogic logic;

  const _DiaryFilterSheet({required this.logic});

  @override
  State<_DiaryFilterSheet> createState() => _DiaryFilterSheetState();
}

class _DiaryFilterSheetState extends State<_DiaryFilterSheet> {
  late final Set<String> _selected;
  List<String>? _allTags;

  @override
  void initState() {
    super.initState();
    _selected = widget.logic.state.filterTags.toSet();
    _load();
  }

  Future<void> _load() async {
    final tags = await widget.logic.collectAllTags();
    if (!mounted) return;
    setState(() => _allTags = tags);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('筛选（按标签）', style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_allTags == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_allTags!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('暂无标签可筛选', style: context.textTheme.bodySmall),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final tag in _allTags!)
                      CheckboxListTile(
                        dense: true,
                        value: _selected.contains(tag),
                        title: Text('#$tag'),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(tag);
                          } else {
                            _selected.remove(tag);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    widget.logic.clearFilter();
                    Navigator.pop(context);
                  },
                  child: const Text('清除'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    widget.logic.applyTagFilter(_selected.toList());
                    Navigator.pop(context);
                  },
                  child: const Text('应用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  Widget _buildSyncingButton({
    required BuildContext context,
    required Function() onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const MoodiarySyncing(),
      ),
    );
  }

  /// 移动端「聊一聊」入口：直达 AI 助手页（对标得到大脑首页）。
  Widget _buildChatEntry(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => Get.find<HomeLogic>().changeNavigator(4),
        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
        label: Text(
          '聊一聊',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(DiaryLogic());
    final state = Bind.find<DiaryLogic>().state;

    //生成TabBar
    Widget buildTabBar() {
      final List<Widget> allTabs = [];
      //默认的全部tab
      allTabs.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Tab(text: context.l10n.categoryAll),
        ),
      );
      //根据分类生成分类Tab
      allTabs.addAll(
        List.generate(state.categoryList.length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Tab(text: state.categoryList[index].categoryName),
          );
        }),
      );
      // Obsidian 子页（配置 Vault 并开启后显示，固定为最后一个 tab）
      if (ObsidianConfig.isReady) {
        allTabs.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Tab(text: 'Obsidian'),
          ),
        );
      }
      return Row(
        children: [
          Expanded(
            child: TabBar(
              controller: logic.tabController,
              isScrollable: true,
              dividerHeight: .0,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              splashFactory: NoSplash.splashFactory,
              dragStartBehavior: DragStartBehavior.start,
              unselectedLabelStyle: context.textTheme.labelSmall,
              labelStyle: context.textTheme.labelMedium,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              indicator: ShapeDecoration(
                shape: const StadiumBorder(),
                color: context.theme.colorScheme.primaryContainer,
              ),
              indicatorWeight: .0,
              unselectedLabelColor: context.theme.colorScheme.onSurface
                  .withValues(alpha: 0.8),
              labelColor: context.theme.colorScheme.onPrimaryContainer,
              labelPadding: EdgeInsets.zero,
              indicatorPadding: const EdgeInsets.symmetric(vertical: 12.0),
              tabs: allTabs,
            ),
          ),
          Obx(() {
            final current = state.sort.value;
            return PopupMenuButton<DiarySort>(
              tooltip: '排序',
              icon: const Icon(Icons.sort_rounded),
              onSelected: logic.changeSort,
              itemBuilder: (context) => [
                for (final s in DiarySort.values)
                  CheckedPopupMenuItem(
                    checked: s == current,
                    value: s,
                    child: Text(s.label),
                  ),
              ],
            );
          }),
          IconButton(
            tooltip: '筛选',
            icon: Icon(
              state.filterActive.value
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
            ),
            onPressed: () {
              showFloatingModalBottomSheet(
                context: context,
                builder: (context) => _DiaryFilterSheet(logic: logic),
              );
            },
          ),
        ],
      );
    }

    // 单个页面
    Widget buildDiaryView(int index, key, String? categoryId) {
      return KeepAliveWrapper(
        child: PrimaryScrollWrapper(
          key: key,
          child: DiaryTabViewComponent(categoryId: categoryId),
        ),
      );
    }

    Widget buildTabBarView() {
      final List<Widget> allViews = [];
      // 添加全部日记页面
      allViews.add(buildDiaryView(0, state.keyMap['default'], null));
      // 添加分类日记页面
      allViews.addAll(
        List.generate(state.categoryList.length, (index) {
          return buildDiaryView(
            index + 1,
            state.keyMap[state.categoryList[index].id],
            state.categoryList[index].id,
          );
        }),
      );
      if (ObsidianConfig.isReady) {
        allViews.add(const KeepAliveWrapper(child: ObsidianPage()));
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.axis == Axis.horizontal) {
            logic.checkPageChange();
          }
          return true;
        },
        child: TabBarView(
          controller: logic.tabController,
          dragStartBehavior: DragStartBehavior.start,
          children: allViews,
        ),
      );
    }

    final title = Obx(() {
      return AdaptiveText(
        state.customTitleName.value.isNotEmpty
            ? state.customTitleName.value
            : context.l10n.appName,
        style: context.textTheme.titleLarge?.copyWith(
          color: context.theme.colorScheme.onSurface,
        ),
      );
    });

    final hitokoto = Obx(() {
      return AdaptiveText(
        state.hitokoto.value,
        style: context.textTheme.labelSmall?.copyWith(
          color: context.theme.colorScheme.onSurfaceVariant,
        ),
      );
    });

    // 通栏固定标题行（标题 + 一言 + 动作），位于二级导航侧栏上方
    Widget buildTitleBar() {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, hitokoto],
                  ),
                ),
                if (MediaQuery.sizeOf(context).width < 600)
                  _buildChatEntry(context),
                Obx(() {
                  return WebDavUtil().syncingDiaries.isNotEmpty
                      ? _buildSyncingButton(
                          context: context,
                          onTap: () {
                            showFloatingModalBottomSheet(
                              context: context,
                              builder: (context) {
                                return const SyncDashBoardComponent();
                              },
                            );
                          },
                        )
                      : IconButton(
                          onPressed: () {
                            showFloatingModalBottomSheet(
                              context: context,
                              builder: (context) {
                                return const SyncDashBoardComponent();
                              },
                            );
                          },
                          tooltip: context.l10n.dataSync,
                          icon: const Icon(Icons.cloud_sync_rounded),
                        );
                }),
                IconButton(
                  onPressed: () {
                    showFloatingModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return const SearchSheetComponent();
                      },
                    );
                  },
                  icon: const Icon(Icons.search_rounded),
                  tooltip: context.l10n.diaryPageSearchButton,
                ),
                PopupMenuButton(
                  offset: const Offset(0, 46),
                  tooltip: context.l10n.diaryPageViewModeButton,
                  icon: const Icon(Icons.more_vert_rounded),
                  itemBuilder: (context) {
                    return <PopupMenuEntry<String>>[
                      CheckedPopupMenuItem(
                        checked: state.viewModeType.value == ViewModeType.list,
                        onTap: () async {
                          await logic.changeViewMode(ViewModeType.list);
                        },
                        child: Text(context.l10n.diaryViewModeList),
                      ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem(
                        checked: state.viewModeType.value == ViewModeType.grid,
                        onTap: () async {
                          await logic.changeViewMode(ViewModeType.grid);
                        },
                        child: Text(context.l10n.diaryViewModeGrid),
                      ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem(
                        checked: state.viewModeType.value == ViewModeType.block,
                        onTap: () async {
                          await logic.changeViewMode(ViewModeType.block);
                        },
                        child: const Text('块视图'),
                      ),
                    ];
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      );
    }

    return GetBuilder<DiaryLogic>(
      builder: (_) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildTitleBar(),
            Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 48,
                  child: IconButton(
                    tooltip: '导航',
                    onPressed: logic.toggleNav,
                    icon: const Icon(Icons.menu_open_rounded),
                  ),
                ),
                Expanded(child: buildTabBar()),
              ],
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NavSidebar(logic: logic),
                  Expanded(
                    child: NestedScrollView(
                      key: state.nestedScrollKey,
                      // 列表视图（diary_tab_view）通过
                      // NestedScrollView.sliverOverlapAbsorberHandleFor + SliverOverlapInjector
                      // 依赖头部存在 SliverOverlapAbsorber；tab 行已在外部控制行，
                      // 故这里提供一个高度 0 的空壳 absorber 满足配对，不占可见空间。
                      headerSliverBuilder: (context, _) => [
                        SliverOverlapAbsorber(
                          handle:
                              NestedScrollView.sliverOverlapAbsorberHandleFor(
                                context,
                              ),
                          // 用真正的 0 高度 SliverToBoxAdapter，避免 SliverAppBar
                          // 因 primary 吸收状态栏高度或未登记 extent，导致列表
                          // topOffset 回退到超大的 barHeight（移动端 ≈130px 空白）。
                          sliver: const SliverToBoxAdapter(
                            child: SizedBox.shrink(),
                          ),
                        ),
                      ],
                      body: buildTabBarView(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
