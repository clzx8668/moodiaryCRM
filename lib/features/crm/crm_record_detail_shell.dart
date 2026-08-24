import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/crm_entity_detail_view.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/crm_record_detail_tabs.dart';
import 'package:moodiary/features/crm/local/crm_attachment_store.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
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

  /// 移动/窄屏整页模式（不合并 Tab，Twenty 移动端五 Tab）
  final bool isMobile;

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

  const CrmRecordDetailShell({
    super.key,
    required this.objectType,
    required this.item,
    required this.fields,
    required this.isRoot,
    required this.isMobile,
    required this.onClose,
    required this.onChanged,
    required this.onDelete,
    this.refreshTick = 0,
    this.onLinkRelated,
    this.onCreateRelated,
    this.onCreateBackRelated,
    this.onOpenRelated,
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

  @override
  Widget build(BuildContext context) {
    final tabs = crmDetailTabsFor(
      inRightDrawer: !widget.isMobile,
      isMobile: widget.isMobile,
    );
    final active = tabs.firstWhere(
      (t) => t.id == _activeTabId,
      orElse: () => tabs.first,
    );
    final theme = Theme.of(context);
    final shell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        const Divider(height: 1),
        _buildSummary(theme),
        const Divider(height: 1),
        if (tabs.length > 1) _buildTabBar(theme, tabs, active.id),
        Expanded(
          child: CrmEntityDetailView(
            objectType: widget.objectType,
            item: widget.item,
            fields: widget.fields,
            cards: active.cards,
            compact: !widget.isMobile,
            onChanged: widget.onChanged,
            refreshTick: widget.refreshTick,
            onLinkRelated: widget.onLinkRelated,
            onCreateRelated: widget.onCreateRelated,
            onCreateBackRelated: widget.onCreateBackRelated,
            onOpenRelated: widget.onOpenRelated,
          ),
        ),
      ],
    );
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: widget.isMobile
          ? SafeArea(bottom: false, child: shell)
          : shell,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
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
          Icon(
            crmTypeIcon(widget.objectType),
            size: 18,
            color: crmTypeColor(widget.objectType),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              crmTypeLabel(widget.objectType),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
