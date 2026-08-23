import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/crm/local/crm_attachment_store.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/crm/local/crm_pdf_export.dart';
import 'package:moodiary/features/crm/local/crm_quote_template_store.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:url_launcher/url_launcher.dart';

/// 实体详情视图（Twenty 风格）：字段原位编辑 + 标签/附件/下钻/时间线。
/// 桌面侧栏与移动整页共用同一实现。
class CrmEntityDetailView extends StatefulWidget {
  final String objectType;
  final CrmEntityCache item;
  final List<LocalObjectField> fields;
  final bool compact;
  final VoidCallback? onChanged;

  const CrmEntityDetailView({
    super.key,
    required this.objectType,
    required this.item,
    required this.fields,
    this.compact = false,
    this.onChanged,
  });

  @override
  State<CrmEntityDetailView> createState() => _CrmEntityDetailViewState();
}

class _CrmEntityDetailViewState extends State<CrmEntityDetailView> {
  late final CrmEntityCache _item = widget.item.clone();
  final Map<String, bool> _editing = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Set<String> _savingFields = {};
  bool _addingTag = false;
  bool _addingActivity = false;
  String? _addingOptionFor;
  final Map<String, List<String>> _extraOptions = {};
  final TextEditingController _optionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _activitySubject = TextEditingController();
  String _activityType = 'call';
  String _activityStatus = 'completed';

  CrmLocalRepository get _repo => CrmLocalRepository();

  String get _labelField => kLocalLabelFields[widget.objectType] ?? 'name';

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    _tagController.dispose();
    _activitySubject.dispose();
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
      _commit(field);
    }
  }

  void _confirmOption(LocalObjectField field) {
    final value = _optionController.text.trim();
    if (value.isEmpty) return;
    _extraOptions.putIfAbsent(field.name, () => []).add(value);
    setState(() {
      _addingOptionFor = null;
      _optionController.clear();
    });
    _commitSelect(field, value);
  }

  // ==================== 字段（原位编辑） ====================

  String _stringValue(LocalObjectField field) {
    if (field.name == _labelField) return _item.name;
    final v = _item.data[field.name];
    if (v is Map) return v['name']?.toString() ?? '';
    if (v == null) return '';
    final text = v.toString();
    if (field.type == 'date') return _formatDate(text);
    return text;
  }

  String _formatDate(String text) {
    final date = DateTime.tryParse(text);
    if (date == null) return text;
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  void _startEdit(LocalObjectField field) {
    _controllers[field.name] = TextEditingController(text: _stringValue(field));
    final focusNode = FocusNode();
    focusNode.addListener(() {
      // 失焦自动提交并刷新显示
      if (!focusNode.hasFocus && _editing[field.name] == true) {
        _commit(field);
      }
    });
    _focusNodes[field.name] = focusNode;
    setState(() => _editing[field.name] = true);
  }

  Future<void> _commit(LocalObjectField field) async {
    if (_savingFields.contains(field.name)) return;
    _savingFields.add(field.name);
    var raw = _controllers[field.name]!.text.trim();
    if (field.type == 'date') {
      raw = normalizeDateInput(raw) ?? raw;
    }
    try {
      await CrmEntityFieldUpdater.update(
        objectType: widget.objectType,
        id: _item.twentyId,
        field: field.name,
        value: raw,
      );
      // 写回 dataJson（data 为 getter，直接改 Map 不生效，面板显示会不刷新）
      _item.setData({..._item.data, field.name: raw});
      if (field.name == _labelField) _item.name = raw;
      if (mounted) {
        setState(() => _editing[field.name] = false);
      }
      widget.onChanged?.call();
      toast.success(message: '已保存');
    } catch (e) {
      toast.error(message: '保存失败：$e');
    } finally {
      _savingFields.remove(field.name);
    }
  }

  Future<void> _commitSelect(LocalObjectField field, String value) async {
    try {
      await CrmEntityFieldUpdater.update(
        objectType: widget.objectType,
        id: _item.twentyId,
        field: field.name,
        value: value,
      );
      _item.setData({..._item.data, field.name: value});
      if (mounted) {
        setState(() => _editing[field.name] = false);
      }
      widget.onChanged?.call();
      toast.success(message: '已保存');
    } catch (e) {
      toast.error(message: '保存失败：$e');
    }
  }

  Widget _buildFields() {
    final editable = widget.fields
        .where((f) => f.type != 'relation')
        .where((f) => f.name != 'createdAt' && f.name != 'updatedAt')
        .toList();
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('字段', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final field in editable) _buildFieldTile(field),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldTile(LocalObjectField field) {
    final editing = _editing[field.name] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              field.label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          Expanded(
            child: editing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditInput(field),
                      _optionAddRow(field),
                    ],
                  )
                : InkWell(
                    onTap: () => _startEdit(field),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _stringValue(field).isEmpty
                            ? '—'
                            : _stringValue(field),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditInput(LocalObjectField field) {
    if (field.type == 'select' ||
        (field.type == 'currency' && field.name == 'currency') ||
        field.name == 'isActive') {
      final options = _optionsFor(field).isNotEmpty
          ? _optionsFor(field)
          : (field.name == 'isActive' ? const ['true', 'false'] : const []);
      final current = _stringValue(field);
      return Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: options.contains(current) ? current : (options.isEmpty ? null : options.first),
              isDense: true,
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (v) {
                if (v != null) _commitSelect(field, v);
              },
            ),
          ),
          IconButton(
            tooltip: '添加选项',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            onPressed: () => setState(() {
              _addingOptionFor = _addingOptionFor == field.name
                  ? null
                  : field.name;
            }),
          ),
        ],
      );
    }
    if (field.type == 'date') {
      return TextField(
        controller: _controllers[field.name]!,
        focusNode: _focusNodes[field.name],
        autofocus: true,
        decoration: InputDecoration(
          isDense: true,
          hintText: _controllers[field.name]!.text.isEmpty ? '未设置日期' : null,
          suffixIcon: IconButton(
            tooltip: '选择日期',
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            onPressed: () => _pickDate(field),
          ),
        ),
        onSubmitted: (_) {
          _focusNodes[field.name]!.unfocus();
          _commit(field);
        },
      );
    }
    final controller = _controllers[field.name]!;
    final focusNode = _focusNodes[field.name]!;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      keyboardType: field.type == 'number' || field.type == 'currency'
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: const InputDecoration(
        isDense: true,
      ),
      onSubmitted: (_) {
        focusNode.unfocus();
        _commit(field);
      },
    );
  }

  Widget _optionAddRow(LocalObjectField field) {
    if (_addingOptionFor != field.name) return const SizedBox.shrink();
    return Row(
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
    );
  }

  // ==================== 标签 / 附件 ====================

  Widget _buildTags() {
    return FutureBuilder<List<LocalTag>>(
      future: _repo.tagsForEntity(widget.objectType, _item.twentyId),
      builder: (context, snapshot) {
        final tags = snapshot.data ?? const <LocalTag>[];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('标签', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in tags)
                      InputChip(
                        label: Text(tag.name),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => _removeTag(tag.name),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('添加'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _addingTag = true),
                    ),
                    if (_addingTag)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _tagController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: '标签名',
                                isDense: true,
                              ),
                              onSubmitted: (_) => _commitTag(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_rounded, size: 18),
                            onPressed: _commitTag,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _tagController.clear();
                              setState(() => _addingTag = false);
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _commitTag() async {
    final name = _tagController.text.trim();
    if (name.isEmpty) return;
    final tags = await _repo.tagsForEntity(widget.objectType, _item.twentyId);
    await _repo.setEntityTags(
      widget.objectType,
      _item.twentyId,
      [...tags.map((t) => t.name), name],
    );
    if (mounted) {
      setState(() {
        _tagController.clear();
        _addingTag = false;
      });
    }
  }

  Future<void> _removeTag(String name) async {
    final tags = await _repo.tagsForEntity(widget.objectType, _item.twentyId);
    await _repo.setEntityTags(
      widget.objectType,
      _item.twentyId,
      tags.map((t) => t.name).where((n) => n != name).toList(),
    );
    if (mounted) setState(() {});
  }

  Widget _buildAttachments() {
    return FutureBuilder<List<LocalAttachment>>(
      future: _repo.listAttachments(widget.objectType, _item.twentyId),
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? const <LocalAttachment>[];
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '附件（${attachments.length}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (attachments.isEmpty)
                  const Text('暂无附件，点右上「回形针」添加')
                else
                  for (final attachment in attachments)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.insert_drive_file_outlined,
                        size: 18,
                      ),
                      title: Text(
                        attachment.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () async {
                          await CrmAttachmentStore.delete(attachment);
                          if (mounted) setState(() {});
                        },
                      ),
                      onTap: () => _openAttachment(attachment),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAttachment(LocalAttachment attachment) async {
    try {
      await launchUrl(
        Uri.file(attachment.filePath),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      toast.error(message: '打开附件失败：$e');
    }
  }

  // ==================== 下钻 / 财务 / 质保 / 报价 ====================

  Widget _buildDrilldowns() {
    final sections = <Widget>[];
    if (widget.objectType == 'account') {
      sections.add(_accountDrilldown());
    } else if (widget.objectType == 'opportunity') {
      sections.add(_opportunityDrilldown());
    } else if (widget.objectType == 'contract') {
      sections.add(_contractItems());
      sections.add(_contractFinance());
      sections.add(_contractWarranties());
    } else if (widget.objectType == 'quote') {
      sections.add(_quoteItems());
    }
    return Column(
      children: [
        for (final section in sections) ...[section, const SizedBox(height: 16)],
      ],
    );
  }

  Widget _accountDrilldown() {
    return FutureBuilder<List<Object>>(
      future: () async {
        final id = _item.twentyId;
        final contacts = await _repo.contactsOfAccount(id);
        final opps = (await _repo.listOpportunities())
            .where((o) => o.accountId == id)
            .toList();
        final contracts = (await _repo.listContracts())
            .where((c) => c.accountId == id)
            .toList();
        return <Object>[...contacts, ...opps, ...contracts];
      }(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return _sectionCard(
          '关联业务（${items.length}）',
          items.isEmpty
              ? const Text('暂无联系人/机会/合同')
              : Column(children: [
                  for (final item in items.take(50))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item is LocalContact
                          ? Icons.person_outline_rounded
                          : item is LocalOpportunity
                          ? Icons.trending_up_rounded
                          : Icons.description_outlined,
                      size: 18,
                    ),
                    title: Text(
                      item is LocalContact
                          ? item.name
                          : item is LocalOpportunity
                          ? item.name
                          : (item as LocalContract).name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item is LocalContact
                          ? '联系人 · ${item.title}'
                          : item is LocalOpportunity
                          ? '机会 · ${item.stage}'
                          : '合同 · ${(item as LocalContract).status}',
                    ),
                  ),
                ]),
        );
      },
    );
  }

  Widget _opportunityDrilldown() {
    return FutureBuilder<List<Object>>(
      future: () async {
        final id = _item.twentyId;
        final contracts = (await _repo.listContracts())
            .where((c) => c.opportunityId == id)
            .toList();
        final quotes = (await _repo.listQuotes())
            .where((q) => q.opportunityId == id)
            .toList();
        return <Object>[...contracts, ...quotes];
      }(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return _sectionCard(
          '关联报价/合同（${items.length}）',
          items.isEmpty
              ? const Text('暂无报价/合同')
              : Column(children: [
                  for (final item in items.take(30))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item is LocalQuote
                          ? Icons.request_quote_outlined
                          : Icons.description_outlined,
                      size: 18,
                    ),
                    title: Text(
                      item is LocalQuote
                          ? '${item.quoteNo} · ${item.status}'
                          : (item as LocalContract).name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
        );
      },
    );
  }

  Widget _contractItems() {
    return FutureBuilder<List<LocalContractItem>>(
      future: _repo.contractItems(_item.twentyId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return _sectionCard(
          '合同明细（${items.length}）',
          items.isEmpty
              ? const Text('暂无明细（报价转合同自动生成）')
              : Column(children: [
                  for (final item in items)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.productName),
                    subtitle: Text(
                      '×${item.quantity} @ ¥${item.unitPrice.toStringAsFixed(2)}'
                      '${item.warrantyMonths > 0 ? ' · 质保 ${item.warrantyMonths} 月' : ''}',
                    ),
                    trailing: Text('¥${item.amount.toStringAsFixed(2)}'),
                  ),
                ]),
        );
      },
    );
  }

  Widget _contractFinance() {
    return FutureBuilder<List<Object>>(
      future: () async {
        final id = _item.twentyId;
        final plans = await _repo.listPaymentPlans(contractId: id);
        final payments = await _repo.listPayments(contractId: id);
        final invoices = await _repo.listInvoices(contractId: id);
        return <Object>[...plans, ...payments, ...invoices];
      }(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        final plans = items.whereType<LocalPaymentPlan>().toList();
        final payments = items.whereType<LocalPayment>().toList();
        final invoices = items.whereType<LocalInvoice>().toList();
        final paid = payments.fold<double>(0, (s, p) => s + p.amount);
        final invoiced = invoices.fold<double>(0, (s, i) => s + i.amount);
        return _sectionCard(
          '财务（已回款 ¥${paid.toStringAsFixed(2)} · 已开票 ¥${invoiced.toStringAsFixed(2)}）',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plans.isNotEmpty)
                for (final plan in plans)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(plan.planName),
                    subtitle: Text(
                      '¥${plan.planAmount.toStringAsFixed(2)}'
                      ' · 已收 ¥${plan.paidAmount.toStringAsFixed(2)} · ${plan.status}',
                    ),
                  ),
              if (payments.isNotEmpty)
                for (final payment in payments)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '¥${payment.amount.toStringAsFixed(2)} · ${payment.paymentDate.toLocal().toString().substring(0, 10)}',
                    ),
                    subtitle: Text(payment.method),
                  ),
              if (invoices.isNotEmpty)
                for (final invoice in invoices)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${invoice.invoiceNo.isEmpty ? '（未编号）' : invoice.invoiceNo} · ¥${invoice.amount.toStringAsFixed(2)}',
                    ),
                    subtitle: Text('${invoice.type} · ${invoice.status}'),
                  ),
              if (items.isEmpty) const Text('暂无财务记录'),
            ],
          ),
        );
      },
    );
  }

  Widget _contractWarranties() {
    return FutureBuilder<List<LocalWarranty>>(
      future: _repo.listWarranties(contractId: _item.twentyId),
      builder: (context, snapshot) {
        final warranties = snapshot.data ?? const [];
        return _sectionCard(
          '质保（${warranties.length}）',
          warranties.isEmpty
              ? const Text('暂无质保')
              : Column(children: [
                  for (final warranty in warranties)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      warranty.serialNo.isEmpty
                          ? '（未登记序列号）'
                          : warranty.serialNo,
                    ),
                    subtitle: Text(
                      '${warranty.startDate.toLocal().toString().substring(0, 10)}'
                      ' ~ ${warranty.endDate.toLocal().toString().substring(0, 10)}'
                      ' · ${warranty.status}',
                    ),
                  ),
                ]),
        );
      },
    );
  }

  Widget _quoteItems() {
    return FutureBuilder<List<LocalQuoteItem>>(
      future: _repo.quoteItems(_item.twentyId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        final total = items.fold<double>(0, (s, i) => s + i.amount);
        return _sectionCard(
          '报价明细（${items.length} · 合计 ¥${total.toStringAsFixed(2)}）',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty)
                const Text('暂无明细，点右上「明细」添加')
              else
                for (final item in items)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.productName),
                    subtitle: Text(
                      '×${item.quantity} @ ¥${item.unitPrice.toStringAsFixed(2)}'
                      '${item.discount < 1 ? '（${(item.discount * 100).toStringAsFixed(0)}%）' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('¥${item.amount.toStringAsFixed(2)}'),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () async {
                            await _repo.removeQuoteItem(item.id);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }

  // ==================== 时间线 / 快速跟进 ====================

  Widget _buildTimeline() {
    return FutureBuilder<List<_TimelineEntry>>(
      future: () async {
        final entries = <_TimelineEntry>[];
        final activities = await _repo.listActivities(
          relatedType: widget.objectType,
          relatedId: _item.twentyId,
        );
        for (final activity in activities) {
          entries.add(
            _TimelineEntry(
              time:
                  activity.completedAt ??
                  activity.scheduledAt ??
                  activity.createdAt,
              title: activity.subject,
              subtitle: '${activity.type} · ${activity.status}',
              icon: Icons.event_available_rounded,
              diary: null,
            ),
          );
        }
        for (final link in await _repo.linksForEntity(
          widget.objectType,
          _item.twentyId,
        )) {
          if (link.localType != 'diary') continue;
          final diary = await IsarUtil.getDiaryById(link.localId);
          if (diary != null) {
            entries.add(
              _TimelineEntry(
                time: diary.time,
                title: diary.title.isEmpty ? '未命名日记' : diary.title,
                subtitle: '日记',
                icon: Icons.article_outlined,
                diary: diary,
              ),
            );
          }
        }
        if (entries.isEmpty) {
          for (final diary in (await IsarUtil.searchDiariesByText(_item.name))
              .take(10)) {
            entries.add(
              _TimelineEntry(
                time: diary.time,
                title: diary.title.isEmpty ? '未命名日记' : diary.title,
                subtitle: '日记（名称匹配）',
                icon: Icons.article_outlined,
                diary: diary,
              ),
            );
          }
        }
        entries.sort((a, b) => b.time.compareTo(a.time));
        return entries.take(50).toList();
      }(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <_TimelineEntry>[];
        return _sectionCard(
          '时间线（${entries.length}）',
          entries.isEmpty
              ? const Text('暂无跟进与相关日记')
              : Column(children: [
                  for (final entry in entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(entry.icon, size: 18),
                    title: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${entry.time.toLocal()} · ${entry.subtitle}',
                    ),
                    onTap: entry.diary == null
                        ? null
                        : () => Get.toNamed(
                            AppRoutes.diaryPage,
                            arguments: [entry.diary, true],
                          ),
                  ),
                ]),
        );
      },
    );
  }

  Widget _buildQuickActivityForm() {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新增跟进', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _activitySubject,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '主题',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _commitActivity(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _activityType,
                    decoration: const InputDecoration(
                      labelText: '类型',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'call', child: Text('电话')),
                      DropdownMenuItem(value: 'meeting', child: Text('会议')),
                      DropdownMenuItem(value: 'email', child: Text('邮件')),
                      DropdownMenuItem(value: 'wechat', child: Text('微信')),
                      DropdownMenuItem(value: 'visit', child: Text('拜访')),
                      DropdownMenuItem(value: 'task', child: Text('任务')),
                      DropdownMenuItem(value: 'note', child: Text('备注')),
                    ],
                    onChanged: (v) => setState(() => _activityType = v ?? 'call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _activityStatus,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'planned', child: Text('计划')),
                      DropdownMenuItem(value: 'completed', child: Text('已完成')),
                      DropdownMenuItem(value: 'canceled', child: Text('已取消')),
                    ],
                    onChanged: (v) => setState(() => _activityStatus = v ?? 'completed'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _commitActivity,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _commitActivity() async {
    final subject = _activitySubject.text.trim();
    if (subject.isEmpty) return;
    await _repo.createActivity(
      LocalActivity(
        id: '',
        type: _activityType,
        relatedType: widget.objectType,
        relatedId: _item.twentyId,
        subject: subject,
        status: _activityStatus,
        completedAt: _activityStatus == 'completed' ? DateTime.now() : null,
      ),
    );
    if (mounted) {
      setState(() {
        _activitySubject.clear();
        _addingActivity = false;
      });
    }
    widget.onChanged?.call();
  }

  // ==================== 组装 ====================

  @override
  Widget build(BuildContext context) {
    final padding = widget.compact ? 8.0 : 16.0;
    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        _buildActions(),
        const SizedBox(height: 12),
        if (_addingActivity) ...[
          _buildQuickActivityForm(),
          const SizedBox(height: 12),
        ],
        _buildFields(),
        const SizedBox(height: 16),
        _buildTags(),
        const SizedBox(height: 16),
        _buildAttachments(),
        const SizedBox(height: 16),
        _buildDrilldowns(),
        _buildTimeline(),
      ],
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => setState(() => _addingActivity = !_addingActivity),
          icon: const Icon(Icons.add_comment_rounded, size: 16),
          label: Text(_addingActivity ? '收起跟进' : '跟进'),
        ),
        if (widget.objectType == 'quote') ...[
          FilledButton.tonalIcon(
            onPressed: _quoteToContract,
            icon: const Icon(Icons.description_rounded, size: 16),
            label: const Text('转合同'),
          ),
          OutlinedButton.icon(
            onPressed: _showQuoteItemEditor,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('明细'),
          ),
          OutlinedButton.icon(
            onPressed: _saveAsTemplate,
            icon: const Icon(Icons.save_alt_rounded, size: 16),
            label: const Text('存模板'),
          ),
          OutlinedButton.icon(
            onPressed: _quoteFromTemplate,
            icon: const Icon(Icons.dashboard_customize_rounded, size: 16),
            label: const Text('模板报价'),
          ),
          OutlinedButton.icon(
            onPressed: _manageVersions,
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('版本'),
          ),
        ],
        if (widget.objectType == 'quote' ||
            widget.objectType == 'contract' ||
            widget.objectType == 'invoice')
          OutlinedButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('导出 PDF'),
          ),
      ],
    );
  }

  Future<void> _exportPdf() async {
    try {
      final String path;
      switch (widget.objectType) {
        case 'quote':
          path = await CrmPdfExport.exportQuote(_repo, _item.twentyId);
        case 'contract':
          path = await CrmPdfExport.exportContract(_repo, _item.twentyId);
        case 'invoice':
          path = await CrmPdfExport.exportInvoice(_repo, _item.twentyId);
        default:
          return;
      }
      toast.success(message: '已导出：$path');
      await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
    } catch (e) {
      toast.error(message: '导出失败：$e');
    }
  }

  Future<void> _quoteToContract() async {
    try {
      final contract = await _repo.quoteToContract(_item.twentyId);
      toast.success(message: '已转合同：${contract.contractNo}');
      widget.onChanged?.call();
    } catch (e) {
      toast.error(message: '转合同失败：$e');
    }
  }

  Future<void> _showQuoteItemEditor() async {
    final products = await _repo.listProducts();
    if (!mounted) return;
    var selectedProduct = products.isEmpty ? null : products.first;
    final quantity = TextEditingController(text: '1');
    final unitPrice = TextEditingController(
      text: selectedProduct == null ? '' : selectedProduct.price.toString(),
    );
    final discount = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('添加报价明细'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LocalProduct>(
                  initialValue: selectedProduct,
                  decoration: const InputDecoration(
                    labelText: '产品/服务',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final p in products)
                      DropdownMenuItem(value: p, child: Text(p.name)),
                  ],
                  onChanged: (v) => setDialogState(() {
                    selectedProduct = v;
                    if (v != null) unitPrice.text = v.price.toString();
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '数量',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '单价（元）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: discount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '折扣率（1=无折扣）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selectedProduct == null) return;
    try {
      await _repo.addQuoteItem(
        LocalQuoteItem(
          id: '',
          quoteId: _item.twentyId,
          productId: selectedProduct!.id,
          productName: selectedProduct!.name,
          quantity: double.tryParse(quantity.text) ?? 1,
          unitPrice: double.tryParse(unitPrice.text) ?? 0,
          discount: double.tryParse(discount.text) ?? 1,
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      toast.error(message: '添加失败：$e');
    }
  }

  Future<void> _saveAsTemplate() async {
    final items = await _repo.quoteItems(_item.twentyId);
    if (items.isEmpty) {
      toast.info(message: '请先添加报价明细再保存模板');
      return;
    }
    final name = TextEditingController(
      text: '${_item.name}-模板',
    );
    final days = TextEditingController(text: '15');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存为报价模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: '模板名称',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '默认有效期（天）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await CrmQuoteTemplateStore.save(
      CrmQuoteTemplate(
        name: name.text.trim(),
        validUntilDays: int.tryParse(days.text) ?? 15,
        items: [
          for (final item in items)
            {
              'productId': item.productId,
              'productName': item.productName,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              'discount': item.discount,
            },
        ],
      ),
    );
    toast.success(message: '模板已保存');
  }

  Future<void> _quoteFromTemplate() async {
    final templates = await CrmQuoteTemplateStore.list();
    if (templates.isEmpty) {
      toast.info(message: '暂无模板，可在报价详情「存模板」创建');
      return;
    }
    if (!mounted) return;
    final selected = await showDialog<CrmQuoteTemplate>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('选择报价模板'),
        children: [
          for (final template in templates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, template),
              child: Text(
                '${template.name}（${template.items.length} 项）',
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      final quote = await CrmQuoteTemplateStore.createQuoteFromTemplate(
        _repo,
        selected,
      );
      toast.success(message: '已生成报价单 ${quote.quoteNo}');
      widget.onChanged?.call();
    } catch (e) {
      toast.error(message: '生成失败：$e');
    }
  }

  Future<void> _manageVersions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('报价版本'),
          content: SizedBox(
            width: 380,
            child: FutureBuilder<List<LocalQuoteVersion>>(
              future: _repo.listQuoteVersions(_item.twentyId),
              builder: (context, snapshot) {
                final versions = snapshot.data ?? const [];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await _repo.saveQuoteVersion(_item.twentyId);
                        toast.success(message: '当前版本已保存');
                        if (dialogContext.mounted) setDialogState(() {});
                      },
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: const Text('保存当前版本'),
                    ),
                    const SizedBox(height: 8),
                    if (versions.isEmpty)
                      const Text('暂无版本')
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: versions.length,
                          itemBuilder: (context, index) {
                            final version = versions[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'V${version.versionNo} · ${version.createdAt.toLocal().toString().substring(0, 16)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: '恢复此版本',
                                    icon: const Icon(Icons.restore_rounded, size: 18),
                                    onPressed: () async {
                                      await _repo.restoreQuoteVersion(version.id);
                                      toast.success(message: '已恢复 V${version.versionNo}');
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                      widget.onChanged?.call();
                                    },
                                  ),
                                  IconButton(
                                    tooltip: '删除版本',
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () async {
                                      await _repo.deleteQuoteVersion(version.id);
                                      if (dialogContext.mounted) setDialogState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry {
  final DateTime time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Diary? diary;

  const _TimelineEntry({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.diary,
  });
}
