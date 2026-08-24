import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_entity_detail_view.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/crm_record_detail_tabs.dart';
import 'package:moodiary/features/crm/local/crm_attachment_store.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_entity_loader.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 记录详情页（Twenty `ShowPage` 结构）：标题行（原位编辑）+ 二级 Tab + 卡片内容。
/// 桌面右侧栏与移动整页复用同一结构；`isRoot` 决定退出按钮样式（根 ❌ / 子 ←）。
class CrmRecordDetailShell extends StatefulWidget {
  final String objectType;
  final CrmEntityCache item;
  final List<LocalObjectField> fields;

  /// true = 根详情页（❌ 关闭）；false = 子详情页（← 返回上一层）
  final bool isRoot;

  /// 父页面关联上下文（如「来自 客户 · Acme」），子详情页显示
  final String? parentLabel;

  /// 移动/窄屏整页模式（不合并 Tab，Twenty 移动端五 Tab）
  final bool isMobile;

  /// 桌面整页记录视图（Twenty 桌面双栏：左列 Summary+Fields，右侧 Timeline/Tasks/Notes/Files）
  final bool isFullPage;

  /// 显示「打开整页」入口（右抽屉/移动详情页）
  final bool enableFullPage;

  /// 整页模式嵌套深度（根=1）
  final int depth;

  final VoidCallback onClose;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final int refreshTick;

  /// 原位关联已有记录 / 打开新增关联 / 反向新增 / 打开关联记录详情
  final Future<void> Function(String targetType, String targetId)?
  onLinkRelated;
  final void Function(String targetType)? onCreateRelated;
  final void Function(String targetType)? onCreateBackRelated;
  final void Function(String targetType, String targetId)? onOpenRelated;
  final void Function(String targetType)? onShowRelatedList;

  const CrmRecordDetailShell({
    super.key,
    required this.objectType,
    required this.item,
    required this.fields,
    required this.isRoot,
    this.parentLabel,
    required this.isMobile,
    this.isFullPage = false,
    this.enableFullPage = false,
    this.depth = 1,
    required this.onClose,
    required this.onChanged,
    required this.onDelete,
    this.refreshTick = 0,
    this.onLinkRelated,
    this.onCreateRelated,
    this.onCreateBackRelated,
    this.onOpenRelated,
    this.onShowRelatedList,
  });

  @override
  State<CrmRecordDetailShell> createState() => _CrmRecordDetailShellState();
}

class _CrmRecordDetailShellState extends State<CrmRecordDetailShell> {
  late String _activeTabId;
  bool _editingTitle = false;
  TextEditingController? _titleController;
  FocusNode? _titleFocus;

  @override
  void initState() {
    super.initState();
    final tabs = crmDetailTabsFor(
      inRightDrawer: !widget.isMobile,
      isMobile: widget.isMobile,
    );
    _activeTabId = tabs.first.id;
  }

  @override
  void dispose() {
    _titleController?.dispose();
    _titleFocus?.dispose();
    super.dispose();
  }

  /// 标题行可原位编辑：仅当标签字段存在于字段定义且为文本类类型。
  bool get _titleEditable {
    final label = kLocalLabelFields[widget.objectType];
    if (label == null) return false;
    for (final f in widget.fields) {
      if (f.name == label) {
        return f.type == 'text' || f.type == 'number';
      }
    }
    return false;
  }

  String? get _labelField => kLocalLabelFields[widget.objectType];

  void _startEditTitle() {
    if (!_titleEditable) return;
    _titleController = TextEditingController(text: widget.item.name);
    final focus = FocusNode();
    focus.addListener(() {
      if (!focus.hasFocus && _editingTitle) _commitTitle();
    });
    _titleFocus = focus;
    setState(() => _editingTitle = true);
  }

  Future<void> _commitTitle() async {
    final controller = _titleController;
    final label = _labelField;
    if (controller == null || label == null) {
      if (mounted) setState(() => _editingTitle = false);
      return;
    }
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      if (mounted) setState(() => _editingTitle = false);
      return;
    }
    try {
      await CrmEntityFieldUpdater.update(
        objectType: widget.objectType,
        id: widget.item.twentyId,
        field: label,
        value: raw,
      );
      widget.item.setData({...widget.item.data, label: raw});
      widget.item.name = raw;
      if (mounted) setState(() => _editingTitle = false);
      widget.onChanged();
      toast.success(message: '已保存');
    } catch (e) {
      toast.error(message: '保存失败：$e');
      if (mounted) setState(() => _editingTitle = false);
    }
  }

  Future<void> _pickAttachment(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await CrmAttachmentStore.storeAndAttach(
        sourcePath: path,
        relatedType: widget.objectType,
        relatedId: widget.item.twentyId,
      );
      toast.success(message: '附件已添加');
      widget.onChanged();
    } catch (e) {
      toast.error(message: '添加附件失败：$e');
    }
  }

  /// 打开桌面整页记录视图（Twenty「Open record」）。
  void _openFullPage() {
    Get.to(
      () => CrmRecordDetailShell(
        objectType: widget.objectType,
        item: widget.item,
        fields: widget.fields,
        isRoot: true,
        isFullPage: true,
        isMobile: false,
        depth: widget.depth,
        onClose: () => Get.back(),
        onChanged: widget.onChanged,
        onDelete: widget.onDelete,
        refreshTick: widget.refreshTick,
        onLinkRelated: widget.onLinkRelated,
        onCreateRelated: widget.onCreateRelated,
        onCreateBackRelated: widget.onCreateBackRelated,
        onShowRelatedList: widget.onShowRelatedList,
      ),
    );
  }

  /// 整页模式下钻：推入下一级整页详情（父 ← 返回，深度上限同抽屉）。
  Future<void> _openFullPageRelated(String type, String id) async {
    if (widget.depth >= kCrmDetailMaxDepth) {
      toast.info(
        message: '已达最大嵌套层级（$kCrmDetailMaxDepth 层），可在当前详情内就地展开编辑',
      );
      return;
    }
    final cache = await loadCrmEntityCache(type: type, id: id);
    if (cache == null || !mounted) return;
    Get.to(
      () => CrmRecordDetailShell(
        objectType: type,
        item: cache,
        fields: kBaseObjectFields[type] ?? const [],
        isRoot: false,
        parentLabel:
            '来自 ${crmTypeLabel(widget.objectType)} · ${widget.item.name}',
        isFullPage: true,
        isMobile: false,
        depth: widget.depth + 1,
        onClose: () => Get.back(),
        onChanged: widget.onChanged,
        onDelete: widget.onDelete,
        refreshTick: widget.refreshTick,
        onLinkRelated: widget.onLinkRelated,
        onCreateRelated: widget.onCreateRelated,
        onCreateBackRelated: widget.onCreateBackRelated,
        onShowRelatedList: widget.onShowRelatedList,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = crmDetailTabsFor(
      inRightDrawer: !widget.isMobile,
      isMobile: widget.isMobile,
      objectType: widget.objectType,
    );
    final active = tabs.firstWhere(
      (t) => t.id == _activeTabId,
      orElse: () => tabs.first,
    );
    final theme = Theme.of(context);
    if (widget.isFullPage) {
      return _buildFullPage(theme);
    }
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: widget.isMobile
          ? SafeArea(bottom: false, child: _buildDrawerLayout(theme, tabs, active))
          : _buildDrawerLayout(theme, tabs, active),
    );
  }

  Widget _buildDrawerLayout(
    ThemeData theme,
    List<CrmDetailTab> tabs,
    CrmDetailTab active,
  ) {
    final shell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        const Divider(height: 1),
        if (tabs.length > 1) _buildTabBar(theme, tabs, active.id),
        Expanded(
          child: _detailView(active.cards, compact: !widget.isMobile),
        ),
      ],
    );
    return shell;
  }

  /// 桌面整页双栏布局（Twenty ShowPage：左列 Summary+Fields，右侧 Tab 区）。
  Widget _buildFullPage(ThemeData theme) {
    final allTabs = crmDetailTabsFor(
      inRightDrawer: false,
      isMobile: false,
      objectType: widget.objectType,
    );
    final rightTabs = allTabs.where((t) => t.id != 'fields').toList();
    final active = rightTabs.isEmpty
        ? allTabs.first
        : rightTabs.firstWhere(
            (t) => t.id == _activeTabId,
            orElse: () => rightTabs.first,
          );
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummary(theme),
                      const Divider(height: 1),
                      Expanded(
                        child: _detailView(
                          const [CrmDetailCardType.fields],
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rightTabs.length > 1)
                        _buildTabBar(theme, rightTabs, active.id),
                      Expanded(
                        child: _detailView(active.cards, compact: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailView(List<CrmDetailCardType> cards, {required bool compact}) {
    return CrmEntityDetailView(
      objectType: widget.objectType,
      item: widget.item,
      fields: widget.fields,
      cards: cards,
      compact: compact,
      onChanged: widget.onChanged,
      refreshTick: widget.refreshTick,
      onLinkRelated: widget.onLinkRelated,
      onCreateRelated: widget.onCreateRelated,
      onCreateBackRelated: widget.onCreateBackRelated,
      onOpenRelated: widget.isFullPage
          ? (type, id) => _openFullPageRelated(type, id)
          : widget.onOpenRelated,
      onShowRelatedList: widget.onShowRelatedList,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final t = widget.item.updatedAt.toLocal();
    final dateText = '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final meta = [
      if (widget.parentLabel != null) widget.parentLabel!,
      '更新于 $dateText',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: widget.isRoot ? '关闭' : '返回',
            icon: Icon(
              widget.isRoot ? Icons.close_rounded : Icons.arrow_back_rounded,
              size: 20,
            ),
            onPressed: widget.onClose,
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: crmTypeColor(widget.objectType).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              crmTypeIcon(widget.objectType),
              size: 20,
              color: crmTypeColor(widget.objectType),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_editingTitle && _titleController != null)
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    autofocus: true,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      _titleFocus?.unfocus();
                      _commitTitle();
                    },
                  )
                else
                  InkWell(
                    onTap: _startEditTitle,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        widget.item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.enableFullPage && !widget.isFullPage)
            IconButton(
              tooltip: '打开整页',
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              onPressed: _openFullPage,
            ),
          IconButton(
            tooltip: '添加附件',
            icon: const Icon(Icons.attach_file_rounded, size: 20),
            onPressed: () => _pickAttachment(context),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final t = widget.item.updatedAt.toLocal();
    final dateText = '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: crmTypeColor(widget.objectType).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              crmTypeIcon(widget.objectType),
              size: 22,
              color: crmTypeColor(widget.objectType),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editingTitle && _titleController != null)
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    autofocus: true,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      _titleFocus?.unfocus();
                      _commitTitle();
                    },
                  )
                else
                  InkWell(
                    onTap: _startEditTitle,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        widget.item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '更新于 $dateText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(
    ThemeData theme,
    List<CrmDetailTab> tabs,
    String activeId,
  ) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (final tab in tabs) _tabItem(theme, tab, tab.id == activeId),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(ThemeData theme, CrmDetailTab tab, bool active) {
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => setState(() => _activeTabId = tab.id),
      child: Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? theme.colorScheme.primary : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              tab.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
