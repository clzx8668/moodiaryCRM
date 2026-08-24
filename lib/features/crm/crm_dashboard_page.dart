import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';

/// CRM 数据看板：对象统计、机会漏斗、回款趋势、到期提醒。
class CrmDashboardPage extends StatefulWidget {
  const CrmDashboardPage({super.key});

  @override
  State<CrmDashboardPage> createState() => _CrmDashboardPageState();
}

class _CrmDashboardPageState extends State<CrmDashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final repo = CrmLocalRepository();
    final stats = await repo.stats();
    final opportunities = await repo.listOpportunities();
    final payments = await repo.listPayments();
    final reminders = await repo.dueReminders();

    final stageCounts = <String, int>{};
    for (final stage in kOpportunityStages) {
      stageCounts[stage] = 0;
    }
    for (final opp in opportunities) {
      stageCounts[opp.stage] = (stageCounts[opp.stage] ?? 0) + 1;
    }

    final now = DateTime.now();
    final monthly = <String, double>{};
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      monthly['${month.year}-${month.month.toString().padLeft(2, '0')}'] = 0;
    }
    for (final payment in payments) {
      final key = '${payment.paymentDate.year}-'
          '${payment.paymentDate.month.toString().padLeft(2, '0')}';
      if (monthly.containsKey(key)) {
        monthly[key] = (monthly[key] ?? 0) + payment.amount;
      }
    }

    final won = opportunities
        .where((o) => o.stage == 'closedWon')
        .fold<double>(0, (s, o) => s + o.amount);
    final pipeline = opportunities
        .where(
          (o) =>
              o.stage != 'closedWon' &&
              o.stage != 'closedLost' &&
              o.stage != 'abandoned',
        )
        .fold<double>(0, (s, o) => s + o.amount);

    return _DashboardData(
      stats: stats,
      stageCounts: stageCounts,
      monthly: monthly,
      won: won,
      pipeline: pipeline,
      reminders: reminders,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CRM 看板')),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStats(data),
                const SizedBox(height: 16),
                _buildFunnel(data),
                const SizedBox(height: 16),
                _buildPayments(data),
                const SizedBox(height: 16),
                _buildReminders(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats(_DashboardData data) {
    const labels = {
      'account': '客户',
      'contact': '联系人',
      'opportunity': '机会',
      'contract': '合同',
      'product': '产品',
      'quote': '报价',
    };
    final entries = [
      for (final key in labels.keys)
        if ((data.stats[key] ?? 0) > 0) (key, data.stats[key]!),
    ];
    return _card(
      '对象统计',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in entries)
            Chip(
              label: Text('${labels[entry.$1]} ${entry.$2}'),
            ),
          if (entries.isEmpty) const Text('暂无数据，可先「生成演示数据」'),
        ],
      ),
    );
  }

  Widget _buildFunnel(_DashboardData data) {
    final total = data.stageCounts.values.fold<int>(0, (s, v) => s + v);
    return _card(
      '机会漏斗（共 $total）',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stage in kOpportunityStages)
            if ((data.stageCounts[stage] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        kOpportunityStageLabels[stage] ?? stage,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0
                            ? 0
                            : (data.stageCounts[stage] ?? 0) / total,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${data.stageCounts[stage]}'),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          Text(
            '赢单金额 ¥${data.won.toStringAsFixed(2)} · '
            '在谈管线 ¥${data.pipeline.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildPayments(_DashboardData data) {
    final max = data.monthly.values.fold<double>(0, (s, v) => v > s ? v : s);
    return _card(
      '近 6 个月回款',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in data.monthly.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : entry.value / max,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('¥${entry.value.toStringAsFixed(0)}'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminders(_DashboardData data) {
    return _card(
      '近期到期（${data.reminders.length}）',
      data.reminders.isEmpty
          ? const Text('暂无到期提醒')
          : Column(children: [
              for (final reminder in data.reminders.take(10))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm_rounded, size: 18),
                  title: Text(reminder.title),
                  subtitle: Text('${reminder.at.toLocal()}'),
                ),
            ]),
    );
  }

  Widget _card(String title, Widget child) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _DashboardData {
  final Map<String, int> stats;
  final Map<String, int> stageCounts;
  final Map<String, double> monthly;
  final double won;
  final double pipeline;
  final List<CrmReminderItem> reminders;

  const _DashboardData({
    required this.stats,
    required this.stageCounts,
    required this.monthly,
    required this.won,
    required this.pipeline,
    required this.reminders,
  });
}
