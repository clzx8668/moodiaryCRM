import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_dashboard_page.dart';
import 'package:moodiary/features/crm/local/crm_demo_data.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';

/// CRM 模块首页（本地优先）：顶部 Tab 展示基础对象 + 自定义对象。
class CrmHomePage extends StatefulWidget {
  const CrmHomePage({super.key});

  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage> {
  List<CrmTabDef> _tabs = List.of(kCrmTabs);
  List<LocalCustomObject> _customObjects = [];
  bool _loaded = false;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _loadCustomObjects();
  }

  Future<void> _loadCustomObjects() async {
    final defs = await CrmLocalRepository().listCustomObjects();
    if (mounted) {
      setState(() {
        _customObjects = defs;
        _tabs = [
          ...kCrmTabs,
          for (final def in defs)
            CrmTabDef('custom:${def.id}', def.labelPlural),
        ];
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('CRM', style: context.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                tooltip: '数据看板',
                icon: const Icon(Icons.dashboard_rounded),
                onPressed: () => Get.to(() => const CrmDashboardPage()),
              ),
              IconButton(
                tooltip: '生成演示数据（每表 5–10 条，验证功能）',
                icon: const Icon(Icons.auto_awesome_rounded),
                onPressed: _seedDemoData,
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: () {
                  setState(() => _reloadToken++);
                  _loadCustomObjects();
                },
                icon: const Icon(Icons.refresh_rounded),
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
            child: DefaultTabController(
              length: _tabs.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [for (final tab in _tabs) Tab(text: tab.label)],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final tab in _tabs)
                          CrmObjectTableTab(
                            key: PageStorageKey('crm-tab-${tab.type}'),
                            objectType: tab.type,
                            title: tab.label,
                            reloadToken: _reloadToken,
                            customObject: tab.type.startsWith('custom:')
                                ? _customObjects.firstWhere(
                                    (o) => 'custom:${o.id}' == tab.type,
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _seedDemoData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('生成演示数据'),
        content: const Text(
          '将为每个 CRM 表追加 5–10 条带关联的演示数据'
          '（不删除现有数据），用于功能验证。确认继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('生成'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final counts = await CrmDemoData.seed(CrmLocalRepository());
      if (mounted) {
        setState(() {
          _reloadToken++;
        });
        await _loadCustomObjects();
        Get.snackbar(
          '演示数据已生成',
          counts.entries.map((e) => '${e.key}:${e.value}').join(' · '),
          snackPosition: SnackPosition.bottom,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar('生成失败', '$e', snackPosition: SnackPosition.bottom);
    }
  }
}
