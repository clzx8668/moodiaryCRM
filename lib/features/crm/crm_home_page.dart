import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_sync_page.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/utils/notice_util.dart';

/// CRM 首页页签：本地缓存概览 + 同步操作入口
class CrmHomePage extends StatefulWidget {
  const CrmHomePage({super.key});

  @override
  State<CrmHomePage> createState() => _CrmHomePageState();
}

class _CrmHomePageState extends State<CrmHomePage> {
  Map<String, int> _stats = {};
  List<CrmEntityCache> _recent = [];
  bool _syncing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = <String, int>{};
    for (final type in CrmSyncService.defaultObjects) {
      stats[type] = await IsarUtil.countCrmEntitiesByType(type);
    }
    final recent = await IsarUtil.getAllCrmEntities();
    if (mounted) {
      setState(() {
        _stats = stats;
        _recent = recent.take(20).toList();
        _loaded = true;
      });
    }
  }

  Future<void> _sync() async {
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
      final result = await service.fullPull();
      toast.success(message: '同步完成：${result.totalPulled} 条');
    } catch (e) {
      toast.error(message: '同步失败：$e');
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('CRM 同步', style: context.textTheme.titleLarge),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: _syncing ? null : _sync,
              icon: _syncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 16),
              label: const Text('全量同步'),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'CRM 同步管理',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () {
                Get.to(() => const CrmSyncPage());
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_loaded)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _stats.entries)
                Chip(
                  label: Text('${_label(entry.key)} ${entry.value}'),
                  avatar: Icon(_icon(entry.key), size: 16),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('最近更新', style: context.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_recent.isEmpty)
                    const Text('暂无缓存数据，请先执行全量同步')
                  else
                    for (final item in _recent)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_icon(item.entityType), size: 20),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_label(item.entityType)} · '
                          '${item.updatedAt.toLocal()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _label(String type) {
    const labels = {
      'company': '客户',
      'person': '联系人',
      'opportunity': '商机',
      'task': '任务',
    };
    return labels[type] ?? type;
  }

  IconData _icon(String type) {
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
