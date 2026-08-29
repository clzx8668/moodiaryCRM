import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/local/crm_write_service.dart';

/// CRM 写操作确认卡片（M6）：AI 提议 crm_create/update/delete 时展示，
/// 用户确认后才执行；拒绝则把「已取消」回填给 AI。
class CrmWriteConfirmCard extends StatelessWidget {
  final CrmWriteProposal proposal;

  const CrmWriteConfirmCard({super.key, required this.proposal});

  static const int _maxShownFields = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDelete = proposal.action == 'delete';
    final isCreate = proposal.action == 'create';
    final accent = isDelete
        ? scheme.error
        : isCreate
        ? scheme.primary
        : scheme.tertiary;
    final entries = proposal.fields.entries.toList();
    final shown = entries.take(_maxShownFields).toList();

    return AlertDialog(
      icon: Icon(
        isDelete
            ? Icons.delete_forever_rounded
            : isCreate
            ? Icons.add_business_rounded
            : Icons.edit_rounded,
        color: accent,
        size: 28,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${proposal.actionLabel}${proposal.objectLabel}'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              proposal.actionLabel,
              style: textTheme.labelSmall?.copyWith(color: accent),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (proposal.targetName.isNotEmpty) ...[
                Text(
                  proposal.targetName,
                  style: textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Text(
                isDelete
                    ? '将删除该记录（软删除，可在 CRM 中恢复）。'
                    : '操作将写入本地 CRM，并记录到同步日志。',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (proposal.action == 'delete' && proposal.id != null)
                _row(scheme, textTheme, '记录 id', proposal.id!)
              else if (shown.isNotEmpty) ...[
                for (final e in shown)
                  _row(
                    scheme,
                    textTheme,
                    CrmWriteService.fieldLabels[e.key] ?? e.key,
                    _fmt(e.value),
                  ),
                if (entries.length > shown.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '…等共 ${entries.length} 个字段',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              if (proposal.id != null && proposal.action != 'delete') ...[
                const SizedBox(height: 4),
                _row(scheme, textTheme, '记录 id', proposal.id!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isDelete ? scheme.error : null,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isDelete ? '确认删除' : '确认执行'),
        ),
      ],
    );
  }

  Widget _row(
    ColorScheme scheme,
    TextTheme textTheme,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Object? value) {
    final s = value?.toString() ?? '';
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }
}

/// 弹出确认卡片，返回用户是否确认执行。
Future<bool> showCrmWriteConfirmDialog(CrmWriteProposal proposal) async {
  final ok = await Get.dialog<bool>(
    CrmWriteConfirmCard(proposal: proposal),
    barrierDismissible: false,
  );
  return ok ?? false;
}
