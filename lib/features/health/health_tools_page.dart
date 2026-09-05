import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/attachments/attachment_manager.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/health/database_reset_service.dart';
import 'package:moodiary/features/health/health_service.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/utils/notice_util.dart';

/// P4.3 数据健康度工具：概览统计 / 附件清理 / 重建向量索引 / CRM 对账
class HealthToolsPage extends StatefulWidget {
  const HealthToolsPage({super.key});

  @override
  State<HealthToolsPage> createState() => _HealthToolsPageState();
}

class _HealthToolsPageState extends State<HealthToolsPage> {
  final RagService _rag = RagService();

  HealthStats? _stats;
  List<String>? _orphans;
  ReconcileResult? _reconcile;
  bool _busy = false;
  String _busyLabel = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _busy = true);
    _stats = await HealthService.loadStats();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _scanOrphans() async {
    setState(() => _busy = true);
    try {
      final orphans = await AttachmentManager.scanOrphans();
      if (!mounted) return;
      setState(() => _orphans = orphans);
      toast.info(message: orphans.isEmpty ? '没有孤立附件' : '发现 ${orphans.length} 个孤立附件');
    } catch (e) {
      toast.error(message: '扫描失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanOrphans() async {
    setState(() => _busy = true);
    try {
      final count = await AttachmentManager.cleanOrphans();
      if (!mounted) return;
      setState(() => _orphans = []);
      toast.success(message: count == 0 ? '没有可清理的附件' : '已清理 $count 个孤立附件');
    } catch (e) {
      toast.error(message: '清理失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reindexAll() async {
    setState(() {
      _busy = true;
      _busyLabel = '正在重建向量索引…';
    });
    try {
      final result = await _rag.reindexAll();
      if (!mounted) return;
      toast.success(
        message: result.indexed == 0
            ? '未索引任何卡片：请检查 AI 设置中的 Embedding 模型'
            : '重建完成：${result.succeeded}/${result.knowledgeBases} 个知识库，索引 ${result.indexed} 个卡片',
      );
    } catch (e) {
      toast.error(message: '重建失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = '';
        });
        await _loadStats();
      }
    }
  }

  Future<void> _runReconcile() async {
    setState(() => _busy = true);
    try {
      final baseUrl = await SecureStorageUtil.getValue('twentyBaseUrl');
      final token = await SecureStorageUtil.getValue('twentyApiToken');
      if (token == null || token.trim().isEmpty) {
        toast.info(message: '请先在「CRM 同步」中配置 Twenty 服务器与令牌');
        return;
      }
      final service = CrmSyncService.fromConfig(
        TwentyConfig(
          baseUrl: baseUrl?.isNotEmpty == true ? baseUrl! : 'http://10.200.245.54:3000',
          apiToken: token,
        ),
      );
      final result = await service.reconcile();
      if (!mounted) return;
      setState(() => _reconcile = result);
    } catch (e) {
      toast.error(message: '对账失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAllData() async {
    if (_busy) return;
    final badge = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('清空所有数据？'),
        content: const Text('将删除本地全部数据（日记/Block/CRM 及 Twenty 关联/知识库/日程/待办），'
            '且不可恢复，但不会影响云端 Twenty 数据。确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );
    if (badge != true) return;

    setState(() => _busy = true);
    try {
      await DatabaseResetService.clearAllData();
      toast.success(message: '已清空所有数据');
      await _loadStats();
      // 全局刷新：首页列表/日历等跟随空库重置，避免残留内存态
      try {
        if (Bind.isRegistered<HomeLogic>()) {
          await Bind.find<HomeLogic>().refreshDiaryLists();
        }
      } catch (_) {
        // 首页尚未挂载时忽略
      }
    } catch (e) {
      toast.error(message: '清空失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Card.filled(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('数据健康度')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section('数据概览', [
            if (stats == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _row(Icons.article_rounded, '日记', '${stats.diaries}'),
              _row(Icons.layers_rounded, 'Block（含待办/卡片）', '${stats.blocks}'),
              _row(Icons.business_rounded, 'CRM 实体缓存', '${stats.crmEntities}'),
              _row(Icons.menu_book_rounded, '知识库', '${stats.knowledgeBases}'),
              _row(Icons.bolt_rounded, '向量索引', '${stats.embeddings}'),
              _row(Icons.storage_rounded, '数据库大小', stats.dbSizeText),
            ],
            ListTile(
              dense: true,
              leading: const Icon(Icons.refresh_rounded, size: 20),
              title: const Text('刷新统计'),
              onTap: _loadStats,
            ),
          ]),
          _section('附件健康', [
            _row(
              Icons.attachment_rounded,
              '孤立附件',
              _orphans == null ? '未扫描' : '${_orphans!.length} 个',
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.search_rounded, size: 20),
              title: const Text('扫描孤立附件'),
              onTap: _scanOrphans,
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.cleaning_services_rounded, size: 20),
              title: const Text('清理孤立附件'),
              enabled: (_orphans?.isNotEmpty ?? false) && !_busy,
              onTap: _cleanOrphans,
            ),
          ]),
          _section('向量索引', [
            _row(
              Icons.auto_fix_high_rounded,
              '全部知识库',
              '${stats?.knowledgeBases ?? 0} 个',
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.construction_rounded, size: 20),
              title: const Text('重建全部向量索引'),
              subtitle: const Text('为每个知识库重新 Embedding 全部可索引卡片'),
              enabled: !_busy,
              onTap: _reindexAll,
            ),
          ]),
          _section('同步对账', [
            if (_reconcile != null)
              _row(
                Icons.checklist_rounded,
                '上次对账',
                _reconcile!.totalDiff == 0
                    ? '✅ 一致'
                    : '⚠️ 差异 ${_reconcile!.totalDiff} 项',
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.compare_arrows_rounded, size: 20),
              title: const Text('CRM 全量对账'),
              subtitle: const Text('对比 Twenty 远端与本地缓存（缺失/过期）'),
              enabled: !_busy,
              onTap: _runReconcile,
            ),
          ]),
          _section('危险区', [
            ListTile(
              dense: true,
              leading: const Icon(Icons.delete_forever_rounded, size: 20),
              title: const Text('清空所有数据'),
              subtitle: const Text('删除全部日记/Block/CRM/Twenty 关联/知识库/日程/待办，用于干净调试'),
              enabled: !_busy,
              onTap: _clearAllData,
            ),
          ]),
          if (_busy) ...[
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(_busyLabel.isEmpty ? '处理中…' : _busyLabel),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
