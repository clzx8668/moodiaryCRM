import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_create_form_panel.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/crm_record_detail_shell.dart';
import 'package:moodiary/features/crm/local/crm_entity_creator.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_entity_loader.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 实体详情页（移动/窄屏整页）：复用 [CrmRecordDetailShell]。
class CrmEntityDetailPage extends StatefulWidget {
  final String objectType;
  final CrmEntityCache item;
  final List<LocalObjectField> fields;

  /// true = 根详情页（❌ 关闭）；false = 子详情页（← 返回上一层）
  final bool isRoot;

  /// 父页面关联上下文（子详情页显示）
  final String? parentLabel;

  const CrmEntityDetailPage({
    super.key,
    required this.objectType,
    required this.item,
    required this.fields,
    this.isRoot = true,
    this.parentLabel,
  });

  @override
  State<CrmEntityDetailPage> createState() => _CrmEntityDetailPageState();
}

class _CrmEntityDetailPageState extends State<CrmEntityDetailPage> {
  int _refreshTick = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CrmRecordDetailShell(
        objectType: widget.objectType,
        item: widget.item,
        fields: widget.fields,
        isRoot: widget.isRoot,
        parentLabel: widget.parentLabel,
        isMobile: true,
        onClose: () => Get.back(),
        onDelete: _deleteEntity,
        onLinkRelated: _linkRelated,
        onCreateRelated: _createRelated,
        onCreateBackRelated: _createBackRelated,
        onOpenRelated: _openRelated,
        refreshTick: _refreshTick,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _linkRelated(String targetType, String targetId) async {
    try {
      await CrmEntityLinker.link(
        repo: CrmLocalRepository(),
        parentType: widget.objectType,
        parentId: widget.item.twentyId,
        targetType: targetType,
        targetId: targetId,
      );
      toast.success(message: '已关联${crmTypeLabel(targetType)}');
      if (mounted) setState(() => _refreshTick++);
    } catch (e) {
      toast.error(message: '关联失败：$e');
    }
  }

  void _createRelated(String targetType) {
    final future = Get.to(
      () => CrmCreatePage(
        objectType: targetType,
        title: crmTypeLabel(targetType),
        fields: kBaseObjectFields[targetType] ?? const [],
        contextLabel: '关联：${widget.item.name}',
        onCreate: (data) async {
          final id = await createCrmEntity(
            repo: CrmLocalRepository(),
            objectType: targetType,
            data: data,
          );
          if (id != null) {
            await CrmEntityLinker.link(
              repo: CrmLocalRepository(),
              parentType: widget.objectType,
              parentId: widget.item.twentyId,
              targetType: targetType,
              targetId: id,
            );
          }
        },
      ),
    );
    future?.then((_) {
      if (mounted) setState(() => _refreshTick++);
    });
  }

  /// 子侧关系字段「新增并关联」：新建父实体后把当前实体挂上去。
  void _createBackRelated(String targetType) {
    final future = Get.to(
      () => CrmCreatePage(
        objectType: targetType,
        title: crmTypeLabel(targetType),
        fields: kBaseObjectFields[targetType] ?? const [],
        contextLabel: '关联：${widget.item.name}',
        onCreate: (data) async {
          final id = await createCrmEntity(
            repo: CrmLocalRepository(),
            objectType: targetType,
            data: data,
          );
          if (id != null) {
            await CrmEntityLinker.link(
              repo: CrmLocalRepository(),
              parentType: targetType,
              parentId: id,
              targetType: widget.objectType,
              targetId: widget.item.twentyId,
            );
          }
        },
      ),
    );
    future?.then((_) {
      if (mounted) setState(() => _refreshTick++);
    });
  }

  Future<void> _openRelated(String targetType, String targetId) async {
    final cache = await loadCrmEntityCache(type: targetType, id: targetId);
    if (cache == null || !mounted) return;
    Get.to(
      () => CrmEntityDetailPage(
        objectType: targetType,
        item: cache,
        fields: kBaseObjectFields[targetType] ?? const [],
        isRoot: false,
        parentLabel:
            '来自 ${crmTypeLabel(widget.objectType)} · ${widget.item.name}',
      ),
    );
  }

  Future<void> _deleteEntity() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('将删除「${widget.item.name}」，此操作不可撤销。'),
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
      await CrmEntityDeleter.delete(widget.objectType, widget.item.twentyId);
      toast.success(message: '已删除');
      Get.back();
    } catch (e) {
      toast.error(message: '删除失败：$e');
    }
  }
}
