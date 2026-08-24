import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_entity_loader.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 关联记录「就地展开」字段编辑器（Twenty `RecordDetailRelationRecordsListItem`
/// 展开行为）：不导航、不丢父上下文，全部字段原位编辑、失焦自动保存。
class CrmRecordInlineFields extends StatefulWidget {
  final String objectType;
  final String recordId;
  final List<LocalObjectField> fields;
  final VoidCallback onChanged;

  const CrmRecordInlineFields({
    super.key,
    required this.objectType,
    required this.recordId,
    required this.fields,
    required this.onChanged,
  });

  @override
  State<CrmRecordInlineFields> createState() => _CrmRecordInlineFieldsState();
}

class _CrmRecordInlineFieldsState extends State<CrmRecordInlineFields> {
  CrmEntityCache? _item;
  bool _loading = true;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, bool> _editing = {};
  final Set<String> _saving = {};

  String get _labelField => kLocalLabelFields[widget.objectType] ?? 'name';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final item = await loadCrmEntityCache(
      type: widget.objectType,
      id: widget.recordId,
    );
    if (!mounted) return;
    setState(() {
      _item = item;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  List<LocalObjectField> get _editableFields => widget.fields
      .where((f) => f.name != _labelField)
      .where((f) => f.name != 'createdAt' && f.name != 'updatedAt')
      .where((f) => f.name != 'currency')
      .where((f) => !f.name.endsWith('Id'))
      .toList();

  String _valueOf(LocalObjectField field) {
    final item = _item;
    if (item == null) return '';
    if (field.type == 'relation') {
      final v = item.data[field.name];
      if (v is Map) return v['name']?.toString() ?? '';
      if (v == null) return '';
      return v.toString();
    }
    final v = item.data[field.name];
    if (v == null) return '';
    if (field.type == 'date') {
      final d = DateTime.tryParse(v.toString());
      if (d == null) return v.toString();
      final local = d.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
    }
    return v.toString();
  }

  void _startEdit(LocalObjectField field) {
    _controllers[field.name] = TextEditingController(text: _valueOf(field));
    final focus = FocusNode();
    focus.addListener(() {
      if (!focus.hasFocus && _editing[field.name] == true) {
        _commit(field);
      }
    });
    _focusNodes[field.name] = focus;
    setState(() => _editing[field.name] = true);
  }

  Future<void> _commit(LocalObjectField field) async {
    if (_saving.contains(field.name)) return;
    _saving.add(field.name);
    var raw = _controllers[field.name]!.text.trim();
    if (field.type == 'date') {
      raw = normalizeDateInput(raw) ?? raw;
    }
    try {
      await CrmEntityFieldUpdater.update(
        objectType: widget.objectType,
        id: widget.recordId,
        field: field.name,
        value: raw,
      );
      final item = _item;
      if (item != null) {
        item.setData({...item.data, field.name: raw});
      }
      if (mounted) setState(() => _editing[field.name] = false);
      widget.onChanged();
      toast.success(message: '已保存');
    } catch (e) {
      toast.error(message: '保存失败：$e');
    } finally {
      _saving.remove(field.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_item == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('记录不存在或已删除', style: TextStyle(color: Colors.grey)),
      );
    }
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '编辑${crmTypeLabel(widget.objectType)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final field in _editableFields) _fieldRow(theme, field),
        ],
      ),
    );
  }

  Widget _fieldRow(ThemeData theme, LocalObjectField field) {
    final editing = _editing[field.name] == true;
    final isRelation = field.type == 'relation';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              field.label,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          Expanded(
            child: editing
                ? TextField(
                    controller: _controllers[field.name],
                    focusNode: _focusNodes[field.name],
                    autofocus: true,
                    keyboardType:
                        field.type == 'number' || field.type == 'currency'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : null,
                    decoration: const InputDecoration(isDense: true),
                    onSubmitted: (_) {
                      _focusNodes[field.name]?.unfocus();
                      _commit(field);
                    },
                  )
                : InkWell(
                    onTap: isRelation ? null : () => _startEdit(field),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _valueOf(field).isEmpty ? '—' : _valueOf(field),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
