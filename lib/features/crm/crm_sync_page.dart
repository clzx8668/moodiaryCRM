import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_content_sync_page.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/business_objects_page.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/utils/notice_util.dart';

/// CRM 同步页面：配置 Twenty 连接、测试、全量拉取、缓存搜索、同步日志
class CrmSyncPage extends StatelessWidget {
  const CrmSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(CrmSyncController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM 同步（Twenty）'),
        actions: [
          IconButton(
            tooltip: '内容同步',
            icon: const Icon(Icons.article_outlined),
            onPressed: () {
              Get.to(() => const CrmContentSyncPage());
            },
          ),
          IconButton(
            tooltip: '业务对象',
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: () {
              Get.to(() => const BusinessObjectsPage());
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConfigCard(context, logic),
          const SizedBox(height: 16),
          _buildActionCard(context, logic),
          const SizedBox(height: 16),
          _buildDisplayCard(context, logic),
          const SizedBox(height: 16),
          _buildCacheCard(context, logic),
          const SizedBox(height: 16),
          _buildLogCard(context, logic),
        ],
      ),
    );
  }

  Widget _buildDisplayCard(BuildContext context, CrmSyncController logic) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('页面显示管理', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '控制 CRM 首页顶部 Tab 分页展示哪些对象页（与 Twenty 对象动态对应）',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Obx(
              () => Column(
                children: [
                  for (final tab in kCrmTabs)
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: logic.tabVisibility[tab.type] ?? true,
                      title: Text(tab.label),
                      secondary: Icon(crmTypeIcon(tab.type), size: 20),
                      onChanged: (v) => logic.setTabVisibility(tab.type, v),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard(BuildContext context, CrmSyncController logic) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('连接配置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: logic.baseUrlController,
              decoration: const InputDecoration(
                labelText: '服务地址',
                hintText: 'http://10.200.245.54:3000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => TextField(
                controller: logic.tokenController,
                obscureText: !logic.tokenVisible.value,
                decoration: InputDecoration(
                  labelText: 'API Token',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      logic.tokenVisible.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: logic.toggleTokenVisible,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: logic.saveConfig,
                    child: const Text('保存配置'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: logic.importLocalConfig,
                  icon: const Icon(Icons.file_open_outlined, size: 16),
                  label: const Text('导入本地配置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, CrmSyncController logic) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('同步操作', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Obx(
              () => Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: logic.testing.value ? null : logic.testConnection,
                      icon: logic.testing.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: const Text('测试连接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: logic.syncing.value ? null : logic.fullSync,
                      icon: logic.syncing.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('全量同步'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: logic.reconciling.value
                          ? null
                          : logic.reconcile,
                      icon: logic.reconciling.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.rule_rounded),
                      label: const Text('对账'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              final result = logic.connectionResult.value;
              final sync = logic.syncResult.value;
              final reconcile = logic.reconcileResult.value;
              final stats = logic.stats.value;
              if (result != null ||
                  sync != null ||
                  reconcile != null ||
                  stats.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result != null)
                      Text(
                        '${result.ok ? "✅" : "❌"} ${result.message ?? ""}',
                        style: TextStyle(
                          color: result.ok
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    if (sync != null)
                      Text('上次全量拉取：${sync.totalPulled} 条 ${sync.pulledByObject}'),
                    if (reconcile != null)
                      Text(
                        reconcile.totalDiff == 0
                            ? '✅ 对账完成：本地与远端一致'
                            : '⚠️ 对账差异 ${reconcile.totalDiff} 项'
                                  '（缺失 ${reconcile.missingLocal}，'
                                  '过期 ${reconcile.staleLocal}）',
                      ),
                    if (stats.isNotEmpty)
                      Text('本地缓存：${stats.entries.map((e) => "${e.key}:${e.value}").join(" / ")}'),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheCard(BuildContext context, CrmSyncController logic) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('本地缓存', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: logic.refreshCache,
                  child: const Text('刷新'),
                ),
                TextButton(
                  onPressed: logic.clearCache,
                  child: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in CrmSyncController.browseTypes)
                    ChoiceChip(
                      label: Text(_typeLabel(type)),
                      selected: logic.selectedType.value == type,
                      onSelected: (_) => logic.selectType(type),
                    ),
                ],
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: logic.searchController,
              onChanged: (_) => logic.search(),
              decoration: const InputDecoration(
                hintText: '搜索客户/合同/回款/发票…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              final items = logic.cacheItems.value;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('暂无缓存数据，请先执行全量同步'),
                );
              }
              return Column(
                children: [
                  for (final item in items.take(50))
                    ListTile(
                      dense: true,
                      leading: Icon(_typeIcon(item.entityType)),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.entityType} · ${item.twentyId} · '
                        '同步于 ${item.lastSyncedAt.toLocal()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _showEntityDetail(context, item),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, CrmSyncController logic) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('同步日志', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: logic.refreshLog,
                  child: const Text('刷新'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              final logs = logic.logEntries.value;
              if (logs.isEmpty) {
                return const Text('暂无日志');
              }
              return Column(
                children: [
                  for (final entry in logs.take(20))
                    ListTile(
                      dense: true,
                      leading: Icon(
                        entry.level == SyncLogLevel.error
                            ? Icons.error_outline
                            : entry.level == SyncLogLevel.warn
                            ? Icons.warning_amber
                            : Icons.info_outline,
                        size: 18,
                        color: entry.level == SyncLogLevel.error
                            ? Colors.red
                            : entry.level == SyncLogLevel.warn
                            ? Colors.orange
                            : null,
                      ),
                      title: Text(
                        '[${entry.operation}] ${entry.target} ${entry.detail}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(entry.timestamp.toLocal().toString()),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'company':
        return Icons.business_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'opportunity':
        return Icons.trending_up_rounded;
      case 'task':
        return Icons.task_alt_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  String _typeLabel(String type) {
    const labels = {
      'company': '客户',
      'person': '联系人',
      'opportunity': '商机',
      'task': '任务',
      'contractsHeTongGuanLi': '合同',
      'paymentsHuiKuanJiLu': '回款',
      'invoiceFaPiao': '发票',
      'commissionsTiChengJieSuan': '提成',
    };
    return labels[type] ?? type;
  }

  void _showEntityDetail(BuildContext context, CrmEntityCache item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.name),
          content: SingleChildScrollView(
            child: Text(
              '类型：${item.entityType}\n'
              'Twenty ID：${item.twentyId}\n'
              '本地版本：${item.localVersion}\n'
              '最近同步：${item.lastSyncedAt.toLocal()}\n\n'
              '快照：\n${_prettyJson(item.dataJson)}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String _prettyJson(String dataJson) {
    try {
      final decoded = jsonDecode(dataJson);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return dataJson;
    }
  }
}

class CrmSyncController extends GetxController {
  static const _kBaseUrl = 'twentyBaseUrl';
  static const _kApiToken = 'twentyApiToken';

  static const browseTypes = [
    'company',
    'person',
    'opportunity',
    'task',
    'contractsHeTongGuanLi',
    'paymentsHuiKuanJiLu',
    'invoiceFaPiao',
    'commissionsTiChengJieSuan',
  ];

  final baseUrlController = TextEditingController();
  final tokenController = TextEditingController();
  final searchController = TextEditingController();

  final tokenVisible = false.obs;
  final testing = false.obs;
  final syncing = false.obs;
  final reconciling = false.obs;
  final connectionResult = Rx<ConnectionResult?>(null);
  final syncResult = Rx<CrmSyncResult?>(null);
  final reconcileResult = Rx<ReconcileResult?>(null);
  final stats = <String, int>{}.obs;
  final cacheItems = <CrmEntityCache>[].obs;
  final logEntries = <SyncLogEntry>[].obs;
  final selectedType = 'company'.obs;
  final tabVisibility = <String, bool>{}.obs;

  CrmSyncService? _service;

  CrmSyncService get service {
    final existing = _service;
    if (existing != null) return existing;
    final config = TwentyConfig(
      baseUrl: baseUrlController.text.trim(),
      apiToken: tokenController.text.trim(),
    );
    final created = CrmSyncService.fromConfig(config);
    _service = created;
    return created;
  }

  @override
  void onInit() {
    super.onInit();
    _loadSavedConfig();
    loadTabVisibility();
    refreshLog();
  }

  Future<void> loadTabVisibility() async {
    for (final tab in kCrmTabs) {
      tabVisibility[tab.type] =
          PrefUtil.getValue<bool>('crmTabVisible_${tab.type}') ?? true;
    }
  }

  Future<void> setTabVisibility(String type, bool value) async {
    tabVisibility[type] = value;
    await PrefUtil.setValue<bool>('crmTabVisible_$type', value);
  }

  Future<void> _loadSavedConfig() async {
    try {
      final baseUrl = await SecureStorageUtil.getValue(_kBaseUrl);
      final token = await SecureStorageUtil.getValue(_kApiToken);
      if (baseUrl != null && baseUrl.isNotEmpty) {
        baseUrlController.text = baseUrl;
      } else {
        baseUrlController.text = 'http://10.200.245.54:3000';
      }
      if (token != null) {
        tokenController.text = token;
      } else {
        // 安全存储无令牌时尝试从本地配置文件预填（桌面开发环境）
        try {
          final local = await TwentyConfig.loadLocal();
          baseUrlController.text = local.baseUrl;
          tokenController.text = local.apiToken;
        } catch (_) {}
      }
    } catch (_) {
      // 安全存储不可用时使用默认地址，页面仍可渲染
      baseUrlController.text = 'http://10.200.245.54:3000';
    }
    _service = null;
  }

  /// 从 config/twenty.local.json 导入连接配置（桌面开发/CLI 场景）
  Future<void> importLocalConfig() async {
    try {
      final config = await TwentyConfig.loadLocal();
      baseUrlController.text = config.baseUrl;
      tokenController.text = config.apiToken;
      _service = null;
      await saveConfig();
      toast.success(message: '已导入本地配置并保存');
    } catch (e) {
      toast.error(message: '本地配置文件不可用：$e');
    }
  }

  Future<void> saveConfig() async {
    await SecureStorageUtil.setValue(_kBaseUrl, baseUrlController.text.trim());
    await SecureStorageUtil.setValue(_kApiToken, tokenController.text.trim());
    _service = null;
    toast.success(message: '配置已保存');
  }

  void toggleTokenVisible() => tokenVisible.value = !tokenVisible.value;

  Future<void> testConnection() async {
    testing.value = true;
    connectionResult.value = null;
    try {
      connectionResult.value = await service.testConnection();
      refreshLog();
    } catch (e) {
      connectionResult.value = ConnectionResult(ok: false, message: '$e');
    } finally {
      testing.value = false;
    }
  }

  Future<void> fullSync() async {
    syncing.value = true;
    try {
      syncResult.value = await service.fullPull();
      await refreshCache();
      refreshLog();
      toast.success(message: '同步完成');
    } catch (e) {
      toast.error(message: '同步失败：$e');
    } finally {
      syncing.value = false;
    }
  }

  Future<void> reconcile() async {
    reconciling.value = true;
    try {
      reconcileResult.value = await service.reconcile();
      refreshLog();
    } catch (e) {
      toast.error(message: '对账失败：$e');
    } finally {
      reconciling.value = false;
    }
  }

  Future<void> refreshCache() async {
    stats
      ..clear()
      ..addAll(await service.localStats());
    await search();
  }

  Future<void> search() async {
    final keyword = searchController.text.trim();
    cacheItems.value = keyword.isEmpty
        ? await IsarUtil.getCrmEntitiesByType(selectedType.value)
        : await service.searchLocal(keyword);
  }

  Future<void> selectType(String type) async {
    selectedType.value = type;
    searchController.clear();
    await search();
  }

  Future<void> clearCache() async {
    await IsarUtil.clearCrmCache();
    await refreshCache();
    toast.success(message: '缓存已清空');
  }

  Future<void> refreshLog() async {
    logEntries.value = SyncLogService.instance.query().reversed.toList();
  }

  @override
  void onClose() {
    baseUrlController.dispose();
    tokenController.dispose();
    searchController.dispose();
    super.onClose();
  }
}
