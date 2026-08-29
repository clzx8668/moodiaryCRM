import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_entity_detail_page.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_entity_loader.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';

/// 商机看板（Kanban）：按阶段分列，拖拽卡片改阶段，点击进详情。
class CrmOpportunityBoard extends StatefulWidget {
  const CrmOpportunityBoard({super.key});

  @override
  State<CrmOpportunityBoard> createState() => _CrmOpportunityBoardState();
}

class _CrmOpportunityBoardState extends State<CrmOpportunityBoard> {
  List<LocalOpportunity> _opportunities = [];
  Map<String, String> _accountNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = CrmLocalRepository();
    final opps = await repo.listOpportunities();
    final accounts = await repo.listAccounts();
    if (!mounted) return;
    setState(() {
      _opportunities = opps;
      _accountNames = {for (final a in accounts) a.id: a.name};
      _loading = false;
    });
  }

  LocalOpportunity? _byId(String id) {
    for (final o in _opportunities) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> _moveToStage(LocalOpportunity opp, String stage) async {
    if (opp.stage == stage) return;
    setState(() => opp.stage = stage);
    await CrmEntityFieldUpdater.update(
      objectType: 'opportunity',
      id: opp.id,
      field: 'stage',
      value: stage,
    );
    await _load();
  }

  Future<void> _openDetail(LocalOpportunity opp) async {
    final item = await loadCrmEntityCache(type: 'opportunity', id: opp.id);
    if (item == null || !mounted) return;
    final route = Get.to(
      () => CrmEntityDetailPage(
        objectType: 'opportunity',
        item: item,
        fields: kBaseObjectFields['opportunity'] ?? const [],
      ),
    );
    route?.then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_opportunities.isEmpty) {
      return const Center(child: Text('暂无商机，先在表格视图新建'));
    }
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final stage in kOpportunityStages) _buildColumn(stage),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(String stage) {
    final items = _opportunities.where((o) => o.stage == stage).toList();
    final total = items.fold<double>(0, (s, o) => s + o.amount);
    return SizedBox(
      width: 260,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _columnHeader(stage, items.length, total),
            const SizedBox(height: 8),
            DragTarget<String>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) {
                final opp = _byId(details.data);
                if (opp != null) _moveToStage(opp, stage);
              },
              builder: (context, candidate, rejected) {
                return _columnBody(stage, items, candidate.isNotEmpty);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _columnHeader(String stage, int count, double total) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = kOpportunityStageLabels[stage] ?? stage;
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
        const Spacer(),
        if (total > 0)
          Text(
            '¥${total.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _columnBody(String stage, List<LocalOpportunity> items, bool hovered) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: hovered
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final opp in items) _buildCard(opp),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '拖拽商机到此',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(LocalOpportunity opp) {
    final content = _cardContent(opp);
    return Draggable<String>(
      data: opp.id,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 244, child: content),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: content),
      child: content,
    );
  }

  Widget _cardContent(LocalOpportunity opp) {
    final colorScheme = Theme.of(context).colorScheme;
    final account = opp.accountId == null
        ? null
        : _accountNames[opp.accountId];
    final name = opp.name.trim().isEmpty ? '（未命名商机）' : opp.name;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openDetail(opp),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (account != null && account.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  account,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _money(opp),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _money(LocalOpportunity opp) {
    final symbol = switch (opp.currency) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      _ => '¥',
    };
    return '$symbol${opp.amount.toStringAsFixed(0)}';
  }
}
