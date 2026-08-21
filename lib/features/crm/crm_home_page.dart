import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
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

  /// P2.6 快速新建客户（AI 实体填充：从日记搜索提取名称）
  Future<void> _createCompany() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final search = TextEditingController();
    List<Diary> searchResults = [];
    bool searching = false;
    bool saving = false;

    Future<void> doSearch() async {
      final keyword = search.text.trim();
      if (keyword.isEmpty) {
        setState(() => searchResults = []);
        return;
      }
      searching = true;
      final results = await IsarUtil.searchDiariesByText(keyword);
      if (context.mounted) {
        setState(() {
          searching = false;
          searchResults = results.take(5).toList();
        });
      }
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('快速新建客户', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: '客户名称 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: search,
                      decoration: const InputDecoration(
                        labelText: 'AI 实体填充（搜索日记）',
                        prefixIcon: Icon(Icons.auto_awesome, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => doSearch(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: searching ? null : doSearch,
                    icon: searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    tooltip: '搜索',
                  ),
                ],
              ),
              if (searchResults.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final diary in searchResults)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      diary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${diary.time.toLocal()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      setSheetState(() {
                        name.text = diary.title;
                        search.clear();
                        searchResults = [];
                      });
                    },
                  ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty) {
                          toast.info(message: '请输入客户名称');
                          return;
                        }
                        setSheetState(() => saving = true);
                        try {
                          final baseUrl =
                              await SecureStorageUtil.getValue('twentyBaseUrl');
                          final token =
                              await SecureStorageUtil.getValue('twentyApiToken');
                          final service = CrmSyncService.fromConfig(
                            TwentyConfig(
                              baseUrl: baseUrl?.isNotEmpty == true
                                  ? baseUrl!
                                  : 'http://10.200.245.54:3000',
                              apiToken: token ?? '',
                            ),
                          );
                          await service.createCompany(
                            name: name.text.trim(),
                            extra: description.text.trim().isEmpty
                                ? null
                                : {'description': description.text.trim()},
                          );
                          toast.success(message: '客户已创建并同步');
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext, true);
                          }
                          await _load();
                        } catch (e) {
                          toast.error(message: '创建失败：$e');
                        } finally {
                          if (sheetContext.mounted) {
                            setSheetState(() => saving = false);
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_business_rounded, size: 18),
                label: Text(saving ? '创建中…' : '创建并同步'),
              ),
            ],
          ),
        ),
      ),
    );
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
              onPressed: _createCompany,
              icon: const Icon(Icons.add_business_rounded, size: 16),
              label: const Text('新增客户'),
            ),
            const SizedBox(width: 8),
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
