import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_content_sync_page.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/crm_sync_page.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/crm_structure_sync_service.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/utils/notice_util.dart';

/// CRM 模块首页：顶部 Tab 分页展示 Twenty CRM 主要对象（客户/联系人/机会/合同等）。
///
/// - 每个 Tab 为智能表格（pluto_grid），支持增删改查、排序筛选、列设置持久化；
/// - Tab 集合与 Twenty 对象名动态对应，可在「设置 → CRM 同步 → 页面显示管理」开关；
/// - 保留全量同步 / 单对象同步 / 内容同步（笔记·待办·认领）入口。
class CrmHomePage extends StatefulWidget {
  const CrmHomePage({super.key});

  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage> {
  bool _syncing = false;
  bool _loaded = false;
  bool _configured = false;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConfig());
  }

  Future<void> _checkConfig() async {
    final baseUrl = await SecureStorageUtil.getValue('twentyBaseUrl');
    final token = await SecureStorageUtil.getValue('twentyApiToken');
    if (mounted) {
      setState(() {
        _loaded = true;
        _configured = baseUrl?.isNotEmpty == true && token?.isNotEmpty == true;
      });
      if (_configured) {
        // 初始化/结构版本升级时后台自动同步结构（不阻塞 UI）
        _ensureStructure();
      }
    }
  }

  Future<void> _ensureStructure() async {
    try {
      final baseUrl = await SecureStorageUtil.getValue('twentyBaseUrl');
      final token = await SecureStorageUtil.getValue('twentyApiToken');
      await CrmStructureSyncService(
        client: CrmSyncService.fromConfig(
          TwentyConfig(
            baseUrl: baseUrl?.isNotEmpty == true
                ? baseUrl!
                : 'http://10.200.245.54:3000',
            apiToken: token ?? '',
          ),
        ).client,
      ).ensureSynced();
    } catch (_) {
      // 后台结构同步失败不打扰（可手动触发）
    }
  }

  Future<void> _syncAll() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final baseUrl = await SecureStorageUtil.getValue('twentyBaseUrl');
      final token = await SecureStorageUtil.getValue('twentyApiToken');
      final service = CrmSyncService.fromConfig(
        TwentyConfig(
          baseUrl: baseUrl?.isNotEmpty == true
              ? baseUrl!
              : 'http://10.200.245.54:3000',
          apiToken: token ?? '',
        ),
      );
      final result = await service.fullSync();
      toast.success(message: '全量同步完成：$result');
      setState(() => _reloadToken++); // 触发各 Tab 重新加载
    } catch (e) {
      toast.error(message: '全量同步失败：$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = visibleCrmTabs();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('CRM', style: context.textTheme.titleLarge),
              if (!_configured && _loaded)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '未配置',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  Get.to(() => const CrmContentSyncPage());
                },
                icon: const Icon(Icons.article_outlined, size: 16),
                label: const Text('内容同步'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _syncing ? null : _syncAll,
                icon: _syncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: const Text('全量同步'),
              ),
              IconButton.filledTonal(
                tooltip: 'CRM 同步管理',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () {
                  Get.to(() => const CrmSyncPage());
                },
              ),
            ],
          ),
        ),
        const Divider(height: 8),
        if (tabs.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_chart_outlined, size: 42),
                  const SizedBox(height: 8),
                  const Text('所有对象页已隐藏'),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Get.to(() => const CrmSyncPage()),
                    child: const Text('去「CRM 同步设置」开启页面'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: DefaultTabController(
              length: tabs.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      for (final tab in tabs)
                        Tab(text: tab.label),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final tab in tabs)
                          CrmObjectTableTab(
                            key: PageStorageKey('crm-tab-${tab.type}'),
                            objectType: tab.type,
                            title: tab.label,
                            reloadToken: _reloadToken,
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
