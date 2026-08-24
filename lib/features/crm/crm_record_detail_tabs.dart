import 'package:flutter/material.dart';

/// 详情内层 Tab 的卡片类型（对应 Twenty `CardType`）。
enum CrmDetailCardType { fields, timeline, tasks, notes, files }

/// 详情内层 Tab 定义（对应 Twenty `RecordLayoutTab`）。
class CrmDetailTab {
  final String id;
  final String title;
  final IconData icon;
  final List<CrmDetailCardType> cards;

  const CrmDetailTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.cards,
  });
}

/// 基础 Tab 集（对应 Twenty `BASE_RECORD_LAYOUT`：fields/timeline/tasks/notes/files）。
const List<CrmDetailTab> kBaseDetailTabs = [
  CrmDetailTab(
    id: 'fields',
    title: '字段',
    icon: Icons.list_alt_rounded,
    cards: [CrmDetailCardType.fields],
  ),
  CrmDetailTab(
    id: 'timeline',
    title: '时间线',
    icon: Icons.timeline_rounded,
    cards: [CrmDetailCardType.timeline],
  ),
  CrmDetailTab(
    id: 'tasks',
    title: '任务',
    icon: Icons.check_circle_outline_rounded,
    cards: [CrmDetailCardType.tasks],
  ),
  CrmDetailTab(
    id: 'notes',
    title: '笔记',
    icon: Icons.article_outlined,
    cards: [CrmDetailCardType.notes],
  ),
  CrmDetailTab(
    id: 'files',
    title: '文件',
    icon: Icons.attach_file_rounded,
    cards: [CrmDetailCardType.files],
  ),
];

/// 按 Twenty 规则生成详情内层 Tab：
/// - 右侧栏（inRightDrawer）：第 1、2 个 Tab（Fields+Timeline）合并为「主页」，随后 Tasks/Notes/Files；
/// - 移动整页：不合并，Fields/Timeline/Tasks/Notes/Files 五个 Tab。
List<CrmDetailTab> crmDetailTabsFor({
  required bool inRightDrawer,
  required bool isMobile,
}) {
  if (inRightDrawer) {
    return [
      const CrmDetailTab(
        id: 'home',
        title: '主页',
        icon: Icons.home_rounded,
        cards: [CrmDetailCardType.fields, CrmDetailCardType.timeline],
      ),
      kBaseDetailTabs[2],
      kBaseDetailTabs[3],
      kBaseDetailTabs[4],
    ];
  }
  return List.of(kBaseDetailTabs);
}
