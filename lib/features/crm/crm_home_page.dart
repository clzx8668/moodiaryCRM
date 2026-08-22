import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
}
