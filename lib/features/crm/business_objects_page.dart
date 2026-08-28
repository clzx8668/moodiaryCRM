import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_prefs.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 业务对象管理页：客户/联系人/机会/合同/回款/发票/提成/任务/笔记。
///
/// 复用 [CrmObjectTableTab]（pluto_grid 智能表格 + 增删改查 + 列设置 + 业务下钻），
/// 与 CRM 首页顶部 Tab 保持同一实现，避免两套表格逻辑。
class BusinessObjectsPage extends StatefulWidget {
  const BusinessObjectsPage({super.key});

  @override
  State<BusinessObjectsPage> createState() => _BusinessObjectsPageState();
}

class _BusinessObjectsPageState extends State<BusinessObjectsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final CrmTableController _controller = CrmTableController();
  int _selectedCount = 0;

  @override
  void initState() {
    super.initState();
    final tabs = CrmPrefs.enabledTabs();
    _tab = TabController(length: tabs.length, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _batchDelete() {
    if (_selectedCount == 0) {
      toast.info(message: '请先勾选要删除的记录');
      return;
    }
    _controller.batchAction.value = 'delete';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = CrmPrefs.enabledTabs();
    return Scaffold(
      appBar: AppBar(
        title: const Text('业务对象'),
        actions: [
          IconButton(
            tooltip: '批量删除',
            onPressed: _batchDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final tab in tabs) Tab(text: tab.label)],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          for (var i = 0; i < tabs.length; i++)
            CrmObjectTableTab(
              objectType: tabs[i].type,
              title: tabs[i].label,
              controller: _controller,
              // 仅当前激活 Tab 响应批量操作，避免多 Tab 重复消费
              controllerActive: i == _tab.index,
              onSelectionCountChanged: (n) {
                if (mounted && n != _selectedCount) {
                  setState(() => _selectedCount = n);
                }
              },
            ),
        ],
      ),
    );
  }
}
