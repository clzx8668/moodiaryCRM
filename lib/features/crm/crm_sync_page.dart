import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/utils/notice_util.dart';

/// CRM 同步页面：配置 Twenty 连接、测试、全量拉取、缓存搜索、同步日志
class CrmSyncPage extends StatelessWidget {
  const CrmSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(CrmSyncController());
    return Scaffold(
      appBar: AppBar(title: const Text('CRM 同步（Twenty）')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConfigCard(context, logic),
          const SizedBox(height: 16),
          _buildActionCard(context, logic),
          const SizedBox(height: 16),
          _buildCacheCard(context, logic),
          const SizedBox(height: 16),
          _buildLogCard(context, logic),
        ],
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
            FilledButton.tonal(
              onPressed: logic.saveConfig,
              child: const Text('保存配置'),
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
                ],
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              final result = logic.connectionResult.value;
              final sync = logic.syncResult.value;
              final stats = logic.stats.value;
              if (result != null || sync != null || stats.isNotEmpty) {
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
            TextField(
              controller: logic.searchController,
              onChanged: (_) => logic.search(),
              decoration: const InputDecoration(
                hintText: '搜索客户/联系人/商机…',
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
}

class CrmSyncController extends GetxController {
  static const _kBaseUrl = 'twentyBaseUrl';
  static const _kApiToken = 'twentyApiToken';

  final baseUrlController = TextEditingController();
  final tokenController = TextEditingController();
  final searchController = TextEditingController();

  final tokenVisible = false.obs;
  final testing = false.obs;
  final syncing = false.obs;
  final connectionResult = Rx<ConnectionResult?>(null);
  final syncResult = Rx<CrmSyncResult?>(null);
  final stats = <String, int>{}.obs;
  final cacheItems = <CrmEntityCache>[].obs;
  final logEntries = <SyncLogEntry>[].obs;

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
    refreshLog();
  }

  Future<void> _loadSavedConfig() async {
    final baseUrl = await SecureStorageUtil.getValue(_kBaseUrl);
    final token = await SecureStorageUtil.getValue(_kApiToken);
    if (baseUrl != null && baseUrl.isNotEmpty) {
      baseUrlController.text = baseUrl;
    } else {
      baseUrlController.text = 'http://10.200.245.54:3000';
    }
    if (token != null) {
      tokenController.text = token;
    }
    _service = null;
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

  Future<void> refreshCache() async {
    stats
      ..clear()
      ..addAll(await service.localStats());
    await search();
  }

  Future<void> search() async {
    final keyword = searchController.text.trim();
    cacheItems.value = keyword.isEmpty
        ? await IsarUtil.getCrmEntitiesByType('company')
        : await service.searchLocal(keyword);
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
