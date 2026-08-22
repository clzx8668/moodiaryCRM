import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_entity_detail_view.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_attachment_store.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 实体详情页（移动/窄屏整页）：复用 [CrmEntityDetailView]。
class CrmEntityDetailPage extends StatefulWidget {
  final String objectType;
  final CrmEntityCache item;
  final List<LocalObjectField> fields;

  const CrmEntityDetailPage({
    super.key,
    required this.objectType,
    required this.item,
    required this.fields,
  });

  @override
  State<CrmEntityDetailPage> createState() => _CrmEntityDetailPageState();
}

class _CrmEntityDetailPageState extends State<CrmEntityDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${crmTypeLabel(widget.objectType)} · ${widget.item.name}',
        ),
        actions: [
          IconButton(
            tooltip: '添加附件',
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: _pickAttachment,
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteEntity,
          ),
        ],
      ),
      body: CrmEntityDetailView(
        objectType: widget.objectType,
        item: widget.item,
        fields: widget.fields,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await CrmAttachmentStore.storeAndAttach(
        sourcePath: path,
        relatedType: widget.objectType,
        relatedId: widget.item.twentyId,
      );
      if (mounted) setState(() {});
      toast.success(message: '附件已添加');
    } catch (e) {
      toast.error(message: '添加附件失败：$e');
    }
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
