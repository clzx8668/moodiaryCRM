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
    with SingleTickerProviderStateMixin {
  List<CrmTabDef> _tabs = List.of(kCrmTabs);
  List<LocalCustomObject> _customObjects = [];
  bool _loaded = false;
  late TabController _tabController;
  final CrmTableController _tableController = CrmTableController();
  final TextEditingController _searchController = TextEditingController();
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != _activeIndex) {
        setState(() => _activeIndex = _tabController.index);
      }
    });
    _loadCustomObjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tableController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomObjects() async {
    final defs = await CrmLocalRepository().listCustomObjects();
    if (mounted) {
      setState(() {
        _customObjects = defs;
        _tabs = [
          ...CrmPrefs.enabledTabs(),
          for (final def in defs)
            CrmTabDef('custom:${def.id}', def.labelPlural),
        ];
        _tabController.dispose();
        _tabController = TabController(
          length: _tabs.length,
          vsync: this,
          initialIndex: _activeIndex.clamp(0, _tabs.length - 1).toInt(),
        );
        _tabController.addListener(() {
          if (_tabController.indexIsChanging ||
              _tabController.index != _activeIndex) {
            setState(() => _activeIndex = _tabController.index);
          }
        });
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    onChanged: (v) => _tableController.query.value = v,
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
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final tab in _tabs) Tab(text: tab.label)],
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
    );
  }
}
