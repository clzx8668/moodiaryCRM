import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/local/crm_ai_assist.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/widgets/crm_currency_amount_field.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 新增表单内联面板（Twenty 式，替代新增弹窗）。
class CrmCreateFormPanel extends StatefulWidget {
  final String title;
  final List<LocalObjectField> fields;
  final Future<void> Function(Map<String, dynamic> data) onCreate;
  final VoidCallback onClose;

  /// 关联上下文提示，例如「关联：客户 XXX」（关联新增时显示）
  final String? contextLabel;

  const CrmCreateFormPanel({
    super.key,
    required this.title,
    required this.fields,
    required this.onCreate,
    required this.onClose,
    this.contextLabel,
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
  final Map<String, List<String>> _extraOptions = {};
  final Map<String, String> _fieldCurrencies = {};
  String? _addingOptionFor;
  final TextEditingController _optionController = TextEditingController();

  static bool isEditable(LocalObjectField field) {
    if (field.name.endsWith('Id')) return false;
    if (field.type == 'relation') return false;
    if (field.name == 'createdAt' || field.name == 'updatedAt') return false;
    // 去掉重复/自动计算字段：币种由金额复合组件承载；已收/已开票由流水自动累加
    if (field.name == 'currency' ||
        field.name == 'paidAmount' ||
        field.name == 'invoicedAmount') {
      return false;
    }
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
    _optionController.dispose();
    super.dispose();
  }

  List<String> _optionsFor(LocalObjectField field) {
    if (field.type == 'currency') {
      return [...kCurrencies, ...?_extraOptions[field.name]];
    }
    return [...field.options, ...?_extraOptions[field.name]];
  }

  Future<void> _pickDate(LocalObjectField field) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _controllers[field.name]!.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  void _confirmOption(LocalObjectField field) {
    final value = _optionController.text.trim();
    if (value.isEmpty) return;
    _extraOptions.putIfAbsent(field.name, () => []).add(value);
    _controllers[field.name]!.text = value;
    setState(() {
      _addingOptionFor = null;
      _optionController.clear();
    });
  }

  Widget _inputFor(LocalObjectField field) {
    if (field.type == 'select' ||
        (field.type == 'currency' && field.name == 'currency')) {
      final options = _optionsFor(field);
      final current = _controllers[field.name]!.text;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue:
                  options.contains(current) ? current : (options.isEmpty ? null : options.first),
              decoration: InputDecoration(
                labelText: field.label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (v) =>
                  _controllers[field.name]!.text = v ?? '',
            ),
          ),
          IconButton(
            tooltip: '添加选项',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            onPressed: () => setState(() {
              _addingOptionFor = _addingOptionFor == field.name
                  ? null
                  : field.name;
            }),
          ),
        ],
      );
    }
    if (field.type == 'currency') {
      // 复合组件：币种下拉（可改）+ 金额输入（手动）
      final currency = _fieldCurrencies[field.name] ?? kDefaultCurrency;
      return CrmCurrencyAmountField(
        currency: currency,
        onCurrencyChanged: (v) {
          setState(() => _fieldCurrencies[field.name] = v);
        },
        amountController: _controllers[field.name]!,
        label: field.label,
      );
    }
    if (field.type == 'date') {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controllers[field.name],
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: field.label,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  onPressed: () => _pickDate(field),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return TextField(
      controller: _controllers[field.name],
      keyboardType: field.type == 'number'
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final data = <String, dynamic>{
      for (final f in _fields)
        if (_controllers[f.name]!.text.trim().isNotEmpty)
          f.name: _typed(f, _controllers[f.name]!.text.trim()),
      // 复合币种字段：无独立 currency 字段时，币种随金额字段写入 <字段>Currency
      for (final entry in _fieldCurrencies.entries)
        if (entry.value.isNotEmpty) '${entry.key}Currency': entry.value,
    };
    if (data.isEmpty) {
      toast.info(message: '请至少填写一个字段');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onCreate(data);
      if (widget.contextLabel == null) {
        toast.success(message: '已创建');
      }
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
                if (widget.contextLabel != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.contextLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
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
                for (final field in _fields) ...[
                  _inputFor(field),
                  if (_addingOptionFor == field.name) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _optionController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: '输入新选项',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _confirmOption(field),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_rounded, size: 18),
                          onPressed: () => _confirmOption(field),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
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

/// 移动端新增页（整页复用 [CrmCreateFormPanel]）。
class CrmCreatePage extends StatelessWidget {
  final String title;
  final List<LocalObjectField> fields;
  final Future<void> Function(Map<String, dynamic> data) onCreate;
  final String? contextLabel;

  const CrmCreatePage({
    super.key,
    required this.title,
    required this.fields,
    required this.onCreate,
    this.contextLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          contextLabel == null ? '新增$title' : '新增$title · $contextLabel',
        ),
      ),
      body: CrmCreateFormPanel(
        title: title,
        fields: fields,
        contextLabel: contextLabel,
        onCreate: onCreate,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
