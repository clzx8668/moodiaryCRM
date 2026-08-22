import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/crm_entity_detail_view.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_attachment_store.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 桌面宽屏右侧详情/编辑一体面板（参照 Twenty 记录侧栏）。
class CrmEntitySidePanel extends StatelessWidget {
  final String objectType;
  final CrmEntityCache item;
  final List<LocalObjectField> fields;
  final VoidCallback onClose;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const CrmEntitySidePanel({
    super.key,
    required this.objectType,
    required this.item,
    required this.fields,
    required this.onClose,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Icon(
                  crmTypeIcon(objectType),
                  size: 18,
                  color: crmTypeColor(objectType),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '添加附件',
                  icon: const Icon(Icons.attach_file_rounded, size: 20),
                  onPressed: () => _pickAttachment(context),
                ),
                IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CrmEntityDetailView(
              objectType: objectType,
              item: item,
              fields: fields,
              compact: true,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachment(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await CrmAttachmentStore.storeAndAttach(
        sourcePath: path,
        relatedType: objectType,
        relatedId: item.twentyId,
      );
      toast.success(message: '附件已添加');
      onChanged();
    } catch (e) {
      toast.error(message: '添加附件失败：$e');
    }
  }
}
