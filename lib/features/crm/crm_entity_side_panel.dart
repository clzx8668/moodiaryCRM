import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/crm_record_detail_shell.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';

/// 桌面宽屏右侧详情/编辑一体面板（Twenty 记录详情页结构）。
class CrmEntitySidePanel extends StatelessWidget {
  final String objectType;
  final CrmEntityCache item;
  final List<LocalObjectField> fields;

  /// true = 根详情页（❌ 关闭）；false = 子详情页（← 返回上一层）
  final bool isRoot;

  /// 父页面关联上下文（子详情页显示）
  final String? parentLabel;

  final VoidCallback onClose;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  /// 外部刷新计数：变化时让详情视图失效关系候选缓存
  final int refreshTick;

  /// 原位关联已有记录 / 打开新增关联 / 打开关联记录详情
  final Future<void> Function(String targetType, String targetId)?
  onLinkRelated;
  final void Function(String targetType)? onCreateRelated;
  final void Function(String targetType)? onCreateBackRelated;
  final void Function(String targetType, String targetId)? onOpenRelated;
  final void Function(String targetType)? onShowRelatedList;

  const CrmEntitySidePanel({
    super.key,
    required this.objectType,
    required this.item,
    required this.fields,
    this.isRoot = true,
    this.parentLabel,
    required this.onClose,
    required this.onChanged,
    required this.onDelete,
    this.refreshTick = 0,
    this.onLinkRelated,
    this.onCreateRelated,
    this.onCreateBackRelated,
    this.onOpenRelated,
    this.onShowRelatedList,
  });

  @override
  Widget build(BuildContext context) {
    return CrmRecordDetailShell(
      objectType: objectType,
      item: item,
      fields: fields,
      isRoot: isRoot,
      parentLabel: parentLabel,
      isMobile: false,
      onClose: onClose,
      onChanged: onChanged,
      onDelete: onDelete,
      refreshTick: refreshTick,
      onLinkRelated: onLinkRelated,
      onCreateRelated: onCreateRelated,
      onCreateBackRelated: onCreateBackRelated,
      onOpenRelated: onOpenRelated,
      onShowRelatedList: onShowRelatedList,
    );
  }
}
