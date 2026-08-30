import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_controller.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/features/obsidian/obsidian_tree.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 首页二级导航侧栏（内嵌于主框架、与 tab 行并排，非遮盖抽屉）：
/// - 展开态 300px：日记分类树（含内嵌增/改/删）+ Obsidian 文件树；
/// - 收起态 44px：仅保留一个展开图标（与 tab 行边上的原菜单钮形态一致）；
/// - 宽度动画过渡，主内容（tab 行 + TabBarView）始终占满剩余空间。
///
/// 交互：PC 端选择后保持展开（连续浏览）；移动端选择后自动收起。
class NavSidebar extends StatefulWidget {
  final DiaryLogic? logic;

  const NavSidebar({super.key, this.logic});

  @override
  State<NavSidebar> createState() => _NavSidebarState();
}

class _NavSidebarState extends State<NavSidebar> {
  static const double expandedWidth = 300;
  static const double collapsedWidth = 44;

  late final DiaryLogic _logic = widget.logic ?? Get.find<DiaryLogic>();
  final ObsidianService _obsidianService = ObsidianService.instance;

  List<Category> _categories = [];
  bool _loadingCategories = true;
  ObsidianTreeNode? _obsidianTree;
  bool _loadingObsidian = false;

  /// 按目标平台判断（而非宿主平台）：移动端选择后自动收起。
  bool get _isMobile {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadObsidian();
    _logic.tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _logic.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    _categories = await IsarUtil.getAllCategoryAsync();
    if (!mounted) return;
    setState(() => _loadingCategories = false);
  }

  Future<void> _loadObsidian({bool force = false}) async {
    if (!ObsidianConfig.isReady) {
      if (mounted) setState(() => _obsidianTree = null);
      return;
    }
    setState(() => _loadingObsidian = true);
    await _obsidianService.scan(force: force);
    if (!mounted) return;
    setState(() {
      _obsidianTree = buildObsidianTree(_obsidianService.files);
      _loadingObsidian = false;
    });
  }

  // ==================== 分类导航与管理 ====================

  void _selectCategory(String? categoryId) {
    _logic.jumpToCategory(categoryId: categoryId);
    if (_isMobile) _logic.collapseNav();
  }

  Future<void> _addCategory() async {
    final res = await showTextInputDialog(
      context: context,
      title: context.l10n.categoryManageAdd,
      textFields: [DialogTextField(hintText: context.l10n.categoryManageName)],
    );
    if (res == null || res.first.trim().isEmpty) {
      toast.info(message: '分类名称不能为空');
      return;
    }
    await IsarUtil.insertACategory(Category()..categoryName = res.first.trim());
    await _logic.updateCategory();
    await _loadCategories();
  }

  Future<void> _editCategory(Category category) async {
    final res = await showTextInputDialog(
      context: context,
      title: context.l10n.categoryManageEdit,
      textFields: [
        DialogTextField(
          hintText: context.l10n.categoryManageName,
          initialText: category.categoryName,
        ),
      ],
    );
    if (res == null || res.first.trim().isEmpty) {
      toast.info(message: '分类名称不能为空');
      return;
    }
    await IsarUtil.updateACategory(
      Category()
        ..id = category.id
        ..categoryName = res.first.trim(),
    );
    await _logic.updateCategory();
    await _loadCategories();
  }

  Future<void> _deleteCategory(Category category) async {
    final ok = await IsarUtil.deleteACategory(category.id);
    if (!ok) {
      toast.error(message: '删除失败，当前分类下还有日记');
      return;
    }
    toast.success(message: '删除成功');
    await _logic.updateCategory();
    await _loadCategories();
  }

  // ==================== Obsidian 导航 ====================

  void _selectObsidianFile(ObsidianFile file) {
    ObsidianController.instance.select(file);
    _logic.jumpToObsidian();
    if (_isMobile) _logic.collapseNav();
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final expanded = _logic.state.navExpanded.value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: expanded ? expandedWidth : collapsedWidth,
        color: theme.colorScheme.surfaceContainerLow,
        clipBehavior: Clip.hardEdge,
        // 内容恒定按展开宽度 300 布局（Positioned 覆盖约束），
        // 外部裁剪：收起动画的中间宽度不会触发溢出
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: expandedWidth,
              child: expanded ? _buildExpanded(theme) : _buildCollapsed(theme),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCollapsed(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: IconButton(
            tooltip: '展开导航',
            onPressed: _logic.expandNav,
            icon: Icon(
              Icons.menu_open_rounded,
              size: 22,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
          child: Row(
            children: [
              Text('导航', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: '收起导航',
                onPressed: _logic.collapseNav,
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildCategorySection(),
              Obx(() {
                if (!ObsidianConfig.isReady) {
                  return const SizedBox.shrink();
                }
                return _buildObsidianSection();
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Icon(
                Icons.folder_copy_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text('日记分类', style: theme.textTheme.labelLarge),
              const Spacer(),
              IconButton(
                tooltip: context.l10n.categoryManageAdd,
                onPressed: _addCategory,
                icon: const Icon(Icons.add_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        if (_loadingCategories)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _CategoryTile(
            name: context.l10n.categoryAll,
            selected: _logic.tabController.index == 0,
            onTap: () => _selectCategory(null),
          ),
          for (var i = 0; i < _categories.length; i++)
            _CategoryTile(
              name: _categories[i].categoryName,
              selected: _logic.tabController.index == i + 1,
              onTap: () => _selectCategory(_categories[i].id),
              onEdit: () => _editCategory(_categories[i]),
              onDelete: () => _deleteCategory(_categories[i]),
            ),
        ],
      ],
    );
  }

  Widget _buildObsidianSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text('Obsidian', style: theme.textTheme.labelLarge),
              const Spacer(),
              IconButton(
                tooltip: '刷新文件树',
                onPressed: () => _loadObsidian(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        if (_loadingObsidian)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_obsidianTree == null || _obsidianTree!.children.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Vault 中没有 .md 文件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final node in _obsidianTree!.children) _buildTreeNode(node, 0),
      ],
    );
  }

  Widget _buildTreeNode(ObsidianTreeNode node, int depth) {
    if (node.file != null) {
      final file = node.file!;
      return Obx(() {
        final selected =
            ObsidianController.instance.selectedFile.value?.relativePath ==
            file.relativePath;
        return ListTile(
          dense: true,
          leading: const Icon(Icons.description_outlined, size: 16),
          title: Text(
            node.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Theme.of(context).colorScheme.primary : null,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
          ),
          selected: selected,
          contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 8),
          onTap: () => _selectObsidianFile(file),
        );
      });
    }
    return ExpansionTile(
      dense: true,
      leading: const Icon(Icons.folder_rounded, size: 18),
      title: Text(node.name, style: const TextStyle(fontSize: 13)),
      childrenPadding: EdgeInsets.zero,
      children: [
        for (final child in node.children) _buildTreeNode(child, depth + 1),
      ],
    );
  }
}

/// 分类树节点（含行尾管理操作）。
class _CategoryTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryTile({
    required this.name,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? Icons.folder_rounded : Icons.folder_outlined,
        size: 18,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      selected: selected,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      trailing: onEdit == null || onDelete == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '重命名',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_forever_rounded,
                    size: 17,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
              ],
            ),
      onTap: onTap,
    );
  }
}
