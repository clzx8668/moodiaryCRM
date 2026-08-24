import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_dashboard_page.dart';
import 'package:moodiary/features/crm/local/crm_prefs.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';

/// CRM 模块首页（本地优先）：顶部 Tab 展示基础对象 + 自定义对象。
class CrmHomePage extends StatefulWidget {
  const CrmHomePage({super.key});

  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage>
    with TickerProviderStateMixin {
  List<CrmTabDef> _tabs = List.of(kCrmTabs);
  List<LocalCustomObject> _customObjects = [];
  bool _loaded = false;
  late TabController _tabController;
  final CrmTableController _tableController = CrmTableController();
  final TextEditingController _searchController = TextEditingController();
  int _activeIndex = 0;
  final List<_GlobalHit> _globalResults = [];
  bool _globalOpen = false;
  Timer? _globalDebounce;
  final Map<String, int> _selectionCounts = {};

  int get _currentSelectionCount {
    if (_tabs.isEmpty || _activeIndex < 0 || _activeIndex >= _tabs.length) {
      return 0;
    }
    return _selectionCounts[_tabs[_activeIndex].type] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCustomObjects();
  }

  @override
  void dispose() {
    _globalDebounce?.cancel();
    _tabController.dispose();
    _tableController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index != _activeIndex) {
      setState(() => _activeIndex = _tabController.index);
      // 切 Tab 时刷新目标表（帧后触发，确保新 Tab 已绑定控制器）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tableController.refreshTick.value++;
      });
    }
  }

  Future<void> _loadCustomObjects() async {
    final defs = await CrmLocalRepository().listCustomObjects();
    if (mounted) {
      final newTabs = [
        ...CrmPrefs.enabledTabs(),
        for (final def in defs) CrmTabDef('custom:${def.id}', def.labelPlural),
      ];
      final tabsChanged = newTabs.length != _tabs.length ||
          [
            for (var i = 0; i < newTabs.length && i < _tabs.length; i++)
              newTabs[i].type != _tabs[i].type,
          ].contains(true);
      setState(() {
        _customObjects = defs;
        _tabs = newTabs;
        _activeIndex = _activeIndex.clamp(0, _tabs.length - 1);
        _loaded = true;
      });
      if (tabsChanged) {
        final old = _tabController;
        final fresh = TabController(
          length: _tabs.length,
          vsync: this,
          initialIndex: _activeIndex,
        );
        fresh.addListener(_onTabChanged);
        setState(() => _tabController = fresh);
        // 旧 controller 在下一帧（widget 树已解绑后）安全释放
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && old != _tabController) old.dispose();
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _tableController.query.value = value;
    _onGlobalQuery(value);
  }

  Future<void> _onGlobalQuery(String keyword) async {
    _globalDebounce?.cancel();
    final q = keyword.trim();
    if (q.isEmpty) {
      if (_globalOpen) setState(() => _globalOpen = false);
      return;
    }
    _globalDebounce = Timer(const Duration(milliseconds: 300), () async {
      final repo = CrmLocalRepository();
      final results = <_GlobalHit>[];
      for (final type in const [
        'account',
        'contact',
        'opportunity',
        'contract',
        'quote',
      ]) {
        if (results.length >= 15) break;
        final records = switch (type) {
          'account' => await repo.listAccounts(keyword: q),
          'contact' => await repo.listContacts(keyword: q),
          'opportunity' => await repo.listOpportunities(keyword: q),
          'contract' => await repo.listContracts(keyword: q),
          _ => await repo.listQuotes(keyword: q),
        };
        for (final record in records.take(3)) {
          final label = switch (type) {
            'account' => (record as LocalAccount).name,
            'contact' => (record as LocalContact).name,
            'opportunity' => (record as LocalOpportunity).name,
            'contract' => (record as LocalContract).name,
            _ => (record as LocalQuote).quoteNo,
          };
          if (label.isEmpty) continue;
          results.add(_GlobalHit(type: type, label: label));
        }
      }
      if (mounted) {
        setState(() {
          _globalResults
            ..clear()
            ..addAll(results);
          _globalOpen = results.isNotEmpty;
        });
      }
    });
  }

  void _gotoTab(String type, String query) {
    final index = _tabs.indexWhere((t) => t.type == type);
    if (index >= 0 && _tabController.index != index) {
      _tabController.animateTo(index);
    }
    setState(() {
      _activeIndex = index;
      _globalOpen = false;
    });
    _searchController.text = query;
    _tableController.query.value = query;
  }

  /// Tab 导航行右侧的批量操作条（勾选后显示，靠右对齐；与 Tab 卡片页分割）。
  Widget _buildBatchBar() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '已选 $_currentSelectionCount 条',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () => _tableController.batchAction.value = 'delete',
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('删除'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          TextButton.icon(
            onPressed: () => _tableController.batchAction.value = 'export',
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('导出'),
          ),
          TextButton(
            onPressed: () => _tableController.batchAction.value = 'clear',
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
              child: Row(
                children: [
                  Text('CRM', style: context.textTheme.titleLarge),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: '搜索当前表…',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '列字段设置',
                    onPressed: () => _tableController.columnsTick.value++,
                    icon: const Icon(Icons.view_column_outlined),
                  ),
                  IconButton(
                    tooltip: '导出 CSV',
                    onPressed: () => _tableController.exportTick.value++,
                    icon: const Icon(Icons.file_download_outlined),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: () {
                      _tableController.refreshTick.value++;
                      _loadCustomObjects();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: '数据看板',
                    icon: const Icon(Icons.dashboard_rounded),
                    onPressed: () => Get.to(() => const CrmDashboardPage()),
                  ),
                ],
              ),
            ),
            const Divider(height: 8),
            if (!_loaded)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: [
                              for (final tab in _tabs) Tab(text: tab.label),
                            ],
                          ),
                        ),
                        if (_currentSelectionCount > 0)
                          _buildBatchBar(),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          for (var i = 0; i < _tabs.length; i++)
                            CrmObjectTableTab(
                              key: PageStorageKey('crm-tab-${_tabs[i].type}'),
                              objectType: _tabs[i].type,
                              title: _tabs[i].label,
                              controller: _tableController,
                              onRequestObjectView: _gotoTab,
                              onSelectionCountChanged: (count) => setState(
                                () => _selectionCounts[_tabs[i].type] = count,
                              ),
                              controllerActive: i == _activeIndex,
                              customObject: _tabs[i].type.startsWith('custom:')
                                  ? _customObjects.firstWhere(
                                      (o) => 'custom:${o.id}' == _tabs[i].type,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (_globalOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _globalOpen = false),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: 58,
            left: 16,
            right: 16,
            child: _buildGlobalSearchPanel(),
          ),
        ],
      ],
    );
  }

  Widget _buildGlobalSearchPanel() {
    return Card(
      elevation: 6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                '全局搜索（点击跳转对应对象页）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final hit in _globalResults)
              ListTile(
                dense: true,
                leading: Icon(
                  crmTypeIcon(hit.type),
                  size: 18,
                  color: crmTypeColor(hit.type),
                ),
                title: Text(hit.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(crmTypeLabel(hit.type)),
                onTap: () => _gotoTab(hit.type, hit.label),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlobalHit {
  final String type;
  final String label;

  const _GlobalHit({required this.type, required this.label});
}
