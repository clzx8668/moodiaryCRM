import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 业务对象管理页：合同/回款/发票/提成等结构化浏览（读本地缓存）
class BusinessObjectsPage extends StatelessWidget {
  const BusinessObjectsPage({super.key});

  static const tabs = [
    ('company', '客户'),
    ('person', '联系人'),
    ('opportunity', '商机'),
    ('task', '任务'),
    ('contractsHeTongGuanLi', '合同'),
    ('paymentsHuiKuanJiLu', '回款'),
    ('invoiceFaPiao', '发票'),
    ('commissionsTiChengJieSuan', '提成'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('业务对象'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in tabs) Tab(text: tab.$2)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in tabs)
              _ObjectTab(objectType: tab.$1, title: tab.$2),
          ],
        ),
      ),
    );
  }
}

class _ObjectTab extends StatefulWidget {
  final String objectType;
  final String title;

  const _ObjectTab({required this.objectType, required this.title});

  @override
  State<_ObjectTab> createState() => _ObjectTabState();
}

class _ObjectTabState extends State<_ObjectTab> {
  late Future<List<CrmEntityCache>> _future;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _future = IsarUtil.getCrmEntitiesByType(widget.objectType);
  }

  Future<void> _sync() async {
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
      final count = await service.pullObject(widget.objectType);
      toast.success(message: '已同步 $count 条 ${widget.title}');
    } catch (e) {
      toast.error(message: '同步失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _future = IsarUtil.getCrmEntitiesByType(widget.objectType);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CrmEntityCache>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text(
                    '共 ${items.length} 条',
                    style: context.textTheme.bodySmall,
                  ),
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
                    label: const Text('同步'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('暂无数据，请先同步'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: Icon(
                            _iconFor(item.entityType),
                            color: _colorFor(item.entityType),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _summary(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '${item.updatedAt.toLocal()}'.substring(0, 10),
                            style: context.textTheme.labelSmall,
                          ),
                          onTap: () => _showDetail(context, item),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 提取快照中的关键业务字段摘要
  String _summary(CrmEntityCache item) {
    try {
      final data = item.data;
      final keys = data.keys
          .where(
            (k) =>
                k != 'id' &&
                k != 'name' &&
                !k.endsWith('Id') &&
                !k.endsWith('At'),
          )
          .take(3)
          .toList();
      if (keys.isEmpty) return item.twentyId;
      return keys
          .map((k) => '$k: ${data[k]}')
          .join(' · ');
    } catch (_) {
      return item.twentyId;
    }
  }

  void _showDetail(BuildContext context, CrmEntityCache item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.name),
          content: SingleChildScrollView(
            child: Text(
              '类型：${item.entityType}\n'
              'Twenty ID：${item.twentyId}\n'
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

IconData _iconFor(String type) {
  switch (type) {
    case 'company':
      return Icons.business_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'opportunity':
      return Icons.trending_up_rounded;
    case 'task':
      return Icons.task_alt_rounded;
    case 'contractsHeTongGuanLi':
      return Icons.description_rounded;
    case 'paymentsHuiKuanJiLu':
      return Icons.payments_rounded;
    case 'invoiceFaPiao':
      return Icons.receipt_rounded;
    case 'commissionsTiChengJieSuan':
      return Icons.savings_rounded;
    default:
      return Icons.folder_rounded;
  }
}

Color _colorFor(String type) {
  switch (type) {
    case 'company':
      return Colors.blue.shade400;
    case 'person':
      return Colors.green.shade400;
    case 'opportunity':
      return Colors.orange.shade400;
    case 'task':
      return Colors.purple.shade400;
    case 'contractsHeTongGuanLi':
      return Colors.teal.shade400;
    case 'paymentsHuiKuanJiLu':
      return Colors.red.shade400;
    case 'invoiceFaPiao':
      return Colors.indigo.shade400;
    case 'commissionsTiChengJieSuan':
      return Colors.pink.shade400;
    default:
      return Colors.grey;
  }
}
