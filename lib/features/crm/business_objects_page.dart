import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';

/// 业务对象管理页：客户/联系人/机会/合同/回款/发票/提成/任务/笔记。
///
/// 复用 [CrmObjectTableTab]（pluto_grid 智能表格 + 增删改查 + 列设置 + 业务下钻），
/// 与 CRM 首页顶部 Tab 保持同一实现，避免两套表格逻辑。
class BusinessObjectsPage extends StatelessWidget {
  const BusinessObjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: kCrmTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('业务对象'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in kCrmTabs) Tab(text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in kCrmTabs)
              CrmObjectTableTab(objectType: tab.type, title: tab.label),
          ],
        ),
      ),
    );
  }
}
