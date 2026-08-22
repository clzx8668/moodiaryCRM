import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/local/crm_ai_assist.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 新增表单内联面板（Twenty 式，替代新增弹窗）。
class CrmCreateFormPanel extends StatefulWidget {
  final String title;
  final List<LocalObjectField> fields;
  final Future<void> Function(Map<String, dynamic> data) onCreate;
  final VoidCallback onClose;

  const CrmCreateFormPanel({
    super.key,
    required this.title,
    required this.fields,
    required this.onCreate,
    required this.onClose,
  });

  @override
  State<CrmCreateFormPanel> createState() => _CrmCreateFormPanelState();
}

class _CrmCreateFormPanelState extends State<CrmCreateFormPanel> {
  late final List<LocalObjectField> _fields = widget.fields
      .where(isEditable)
      .toList();
  final Map<String, TextEditingController> _controllers = {};
  bool _aiOpen = false;
  bool _saving = false;

  static bool isEditable(LocalObjectField field) {
    if (field.name.endsWith('Id')) return false;
    if (field.type == 'relation') return false;
    if (field.name == 'createdAt' || field.name == 'updatedAt') return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _controllers[f.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final data = <String, dynamic>{
      for (final f in _fields)
        if (_controllers[f.name]!.text.trim().isNotEmpty)
          f.name: _typed(f, _controllers[f.name]!.text.trim()),
    };
    if (data.isEmpty) {
      toast.info(message: '请至少填写一个字段');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onCreate(data);
      toast.success(message: '已创建');
      widget.onClose();
    } catch (e) {
      toast.error(message: '创建失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Object? _typed(LocalObjectField field, String raw) {
    if (field.type == 'number') return num.tryParse(raw) ?? raw;
    return raw;
  }

  void _applyExtraction(CrmAiExtraction extraction) {
    void setField(String name, String? value) {
      if (value != null && value.isNotEmpty && _controllers.containsKey(name)) {
        _controllers[name]!.text = value;
      }
    }

    setField('name', extraction.name);
    if (extraction.amount != null) {
      final amountText = extraction.amount!.toStringAsFixed(2);
      setField('amount', amountText);
      setField('planAmount', amountText);
      setField('price', amountText);
    }
    setField('phone', extraction.phone);
    setField('email', extraction.email);
    if (extraction.closeDate != null) {
      final d = extraction.closeDate!;
      final dateText = '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      setField('expectedCloseDate', dateText);
      setField('closeDate', dateText);
      setField('issueDate', dateText);
    }
    setField('stage', extraction.stage);
    setField('note', extraction.note);
    if (mounted) setState(() {});
    toast.success(message: '已填充，可修改后保存');
  }

  @override
  Widget build(BuildContext context) {
    final aiInput = TextEditingController();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Text(
                  '新增${widget.title}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _aiOpen = !_aiOpen),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('AI 填充'),
                  ),
                ),
                if (_aiOpen) ...[
                  TextField(
                    controller: aiInput,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: '粘贴客户/机会描述，自动提取名称、金额、电话、邮箱、日期、阶段',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () {
                        _applyExtraction(CrmAiAssist.extractFromText(aiInput.text));
                        aiInput.clear();
                      },
                      child: const Text('提取并填充'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (final field in _fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: _controllers[field.name],
                      keyboardType: field.type == 'number'
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : null,
                      decoration: InputDecoration(
                        labelText: field.label,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: widget.onClose,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中…' : '创建'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
