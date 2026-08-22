import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_content_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_content_link.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/crm/crm_sync_page.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 内容同步页：本地笔记/待办 ↔ Twenty note/task/moodiaryGeneric。
///
/// - 一键推送：自动识别客户关联（公司优先）进入客户时间线，无关联落通用表；
/// - 未关联记录可「认领关联」（升级标准对象 + 挂 target）；
/// - 支持取消关联、删除远端、拉取 Twenty 笔记/待办。
class CrmContentSyncPage extends StatefulWidget {
  const CrmContentSyncPage({super.key});

  @override
  State<CrmContentSyncPage> createState() => _CrmContentSyncPageState();
}

class _CrmContentSyncPageState extends State<CrmContentSyncPage> {
  bool _pushing = false;
  bool _pulling = false;
  List<ContentSyncItem> _items = [];
  bool _loaded = false;
  CrmContentSyncResult? _lastResult;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _checkConfig();
    _load();
  }

  Future<void> _checkConfig() async {
    final baseUrl = await SecureStorageUtil.getValue('twentyBaseUrl');
    final token = await SecureStorageUtil.getValue('twentyApiToken');
    if (mounted) {
      setState(() {
        _configured = baseUrl?.isNotEmpty == true && token?.isNotEmpty == true;
      });
    }
  }

  Future<void> _load() async {
    final service = await _service();
    final items = await service.listContent();
    if (mounted) {
      setState(() {
        _items = items;
        _loaded = true;
      });
    }
  }

  Future<CrmContentSyncService> _service() async {
    final baseUrl = await SecureStorageUtil.getValue('twentyBaseUrl');
    final token = await SecureStorageUtil.getValue('twentyApiToken');
    return CrmContentSyncService.fromConfig(
      TwentyConfig(
        baseUrl: baseUrl?.isNotEmpty == true
            ? baseUrl!
            : 'http://10.200.245.54:3000',
        apiToken: token ?? '',
      ),
    );
  }

  Future<void> _pushAll() async {
    if (_pushing) return;
    setState(() => _pushing = true);
    try {
      final service = await _service();
      final result = await service.pushAll();
      _lastResult = result;
      toast.success(
        message: result.failed > 0
            ? '推送完成：${result.total} 条，失败 ${result.failed}'
            : '推送完成：${result.total} 条',
      );
      await _load();
    } catch (e) {
      toast.error(message: '推送失败：$e');
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  Future<void> _forcePushAll() async {
    if (_pushing) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('强制重推'),
        content: const Text(
          '将重新推送全部笔记与待办（含已推送记录，按最新内容更新远端；'
          '历史降级为标准对象的未关联记录会迁移到通用数据表）。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('强制重推'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _pushing = true);
    try {
      final service = await _service();
      final result = await service.pushAll(force: true);
      _lastResult = result;
      toast.success(
        message: result.failed > 0
            ? '重推完成：${result.total} 条，失败 ${result.failed}'
            : '重推完成：${result.total} 条',
      );
      await _load();
    } catch (e) {
      toast.error(message: '重推失败：$e');
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  Future<void> _pullRemote() async {
    if (_pulling) return;
    setState(() => _pulling = true);
    try {
      final service = await _service();
      final result = await service.pullRemoteContent();
      toast.success(message: '已拉取 Twenty 笔记/待办 ${result.totalPulled} 条');
    } catch (e) {
      toast.error(message: '拉取失败：$e');
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  Future<void> _claim(ContentSyncItem item) async {
    final link = item.link;
    if (link == null) return;
    final result = await _showClaimDialog();
    if (result == null) return;
    try {
      final service = await _service();
      await service.claimAssociation(
        link,
        targetEntityType: result.$1,
        targetId: result.$2,
      );
      toast.success(message: '已认领关联：${result.$3}');
      await _load();
    } catch (e) {
      toast.error(message: '认领失败：$e');
    }
  }

  Future<(String, String, String)?> _showClaimDialog() async {
    var entityType = 'company';
    final search = TextEditingController();
    List<CrmEntityCache> candidates = [];
    CrmEntityCache? selected;
    var loading = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> doSearch() async {
            setDialogState(() => loading = true);
            final entities = await IsarUtil.getCrmEntitiesByType(entityType);
            if (!dialogContext.mounted) return;
            final keyword = search.text.trim();
            setDialogState(() {
              loading = false;
              candidates = keyword.isEmpty
                  ? entities.take(30).toList()
                  : entities
                        .where(
                          (e) =>
                              e.name.toLowerCase().contains(keyword.toLowerCase()) ||
                              e.twentyId.contains(keyword),
                        )
                        .take(30)
                        .toList();
              if (selected != null &&
                  !candidates.any((e) => e.twentyId == selected!.twentyId)) {
                selected = null;
              }
            });
          }

          return AlertDialog(
            title: const Text('认领关联'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: entityType,
                    decoration: const InputDecoration(
                      labelText: '目标类型',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'company', child: Text('客户（公司）')),
                      DropdownMenuItem(value: 'person', child: Text('联系人')),
                      DropdownMenuItem(
                        value: 'opportunity',
                        child: Text('机会'),
                      ),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        entityType = v ?? 'company';
                        search.clear();
                        selected = null;
                        candidates = [];
                      });
                      doSearch();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      hintText: '搜索本地缓存实体…',
                      prefixIcon: Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) {
                      setDialogState(() => selected = null);
                      doSearch();
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : candidates.isEmpty
                        ? const Center(child: Text('无匹配实体，请先全量同步'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: candidates.length,
                            itemBuilder: (context, index) {
                              final entity = candidates[index];
                              final isSelected =
                                  selected?.twentyId == entity.twentyId;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  entity.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  entity.twentyId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                trailing: Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  size: 18,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                onTap: () {
                                  setDialogState(() => selected = entity);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('确认认领'),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
    if (ok == true && selected != null) {
      return (entityType, selected!.twentyId, selected!.name);
    }
    return null;
  }

  Future<void> _removeAssociation(ContentSyncItem item) async {
    final link = item.link;
    if (link == null) return;
    try {
      final service = await _service();
      await service.removeAssociation(link);
      toast.success(message: '已取消关联');
      await _load();
    } catch (e) {
      toast.error(message: '取消关联失败：$e');
    }
  }

  Future<void> _deleteRemote(ContentSyncItem item) async {
    final link = item.link;
    if (link == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除远端记录'),
        content: Text(
          '将删除 Twenty 中的 ${link.remoteType} 记录并清除本地映射，'
          '本地 ${item.localType} 数据保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final service = await _service();
      await service.deleteRemote(link);
      toast.success(message: '已删除远端记录');
      await _load();
    } catch (e) {
      toast.error(message: '删除失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容同步（笔记 · 待办）'),
        actions: [
          TextButton.icon(
            onPressed: _pulling ? null : _pullRemote,
            icon: _pulling
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: const Text('拉取 Twenty 内容'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_configured)
            Card.outlined(
              color: Theme.of(context).colorScheme.errorContainer
                  .withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('尚未配置 Twenty 连接，推送将无法执行。'),
                    ),
                    TextButton(
                      onPressed: () => Get.to(() => const CrmSyncPage()),
                      child: const Text('去配置'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_configured) const SizedBox(height: 12),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('推送笔记与待办', style: context.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '有客户关联自动进入客户时间线；无关联进入通用数据表（可认领）。',
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _pushing ? null : _pushAll,
                          icon: _pushing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.upload_rounded, size: 18),
                          label: Text(_pushing ? '推送中…' : '一键推送全部未同步内容'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pushing ? null : _forcePushAll,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('强制重推'),
                      ),
                    ],
                  ),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '上次推送：$_lastResult',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: _lastResult!.failed > 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_loaded)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            const Card.outlined(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('暂无笔记与待办数据')),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '共 ${_items.length} 条 · '
                '已关联 ${_items.where((i) => i.isLinked).length} · '
                '通用/待认领 ${_items.where((i) => i.isGeneric || !i.hasLink).length}',
                style: context.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 6),
            Card.outlined(
              child: Column(
                children: [
                  for (final item in _items) _buildItem(item),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(ContentSyncItem item) {
    final link = item.link;
    final IconData icon;
    final String typeLabel;
    if (item.localType == CrmContentLink.localTypeBlock) {
      icon = Icons.task_alt_rounded;
      typeLabel = '待办';
    } else {
      icon = Icons.notes_rounded;
      typeLabel = '笔记';
    }
    final Color statusColor;
    final String statusText;
    if (link == null) {
      statusColor = Colors.orange.shade700;
      statusText = '未推送';
    } else if (link.isLinked) {
      statusColor = Colors.green.shade700;
      statusText = '已关联';
    } else if (link.isGeneric) {
      statusColor = Colors.blueGrey.shade600;
      statusText = '通用/待认领';
    } else if (link.hasError) {
      statusColor = Colors.red.shade700;
      statusText = '错误';
    } else {
      statusColor = Colors.blueGrey.shade400;
      statusText = link.status;
    }

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$typeLabel · ${item.time.toLocal()}'
        '${item.matchHint.isNotEmpty ? ' · 可关联 ${item.matchHint}' : ''}'
        '${link != null && link.remoteId.isNotEmpty ? ' · ${link.remoteType}' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: TextStyle(fontSize: 11, color: statusColor),
            ),
          ),
          if (link != null && !link.isLinked)
            IconButton(
              tooltip: '认领关联',
              icon: const Icon(Icons.link_rounded, size: 18),
              onPressed: () => _claim(item),
            ),
          if (link != null && link.isLinked)
            IconButton(
              tooltip: '取消关联',
              icon: const Icon(Icons.link_off_rounded, size: 18),
              onPressed: () => _removeAssociation(item),
            ),
          if (link != null)
            IconButton(
              tooltip: '删除远端',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _deleteRemote(item),
            ),
        ],
      ),
    );
  }
}
