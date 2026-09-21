import 'package:flutter/material.dart';
import 'package:moodiary/features/ai/triage/ai_triage_service.dart';
import 'package:moodiary/features/ai/triage/triage_config.dart';
import 'package:moodiary/features/ai/triage/triage_types.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 分流策略设置页：让用户看清"什么会上云、什么留在本地"，并能自己调。
class AiTriageSettingsPage extends StatefulWidget {
  const AiTriageSettingsPage({super.key});

  @override
  State<AiTriageSettingsPage> createState() => _AiTriageSettingsPageState();
}

class _AiTriageSettingsPageState extends State<AiTriageSettingsPage> {
  TriageConfig? _config;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await AiTriageService.instance.config();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _loading = false;
    });
  }

  Future<void> _update(TriageConfig next) async {
    setState(() => _config = next);
    await AiTriageService.instance.saveConfig(next);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    return Scaffold(
      appBar: AppBar(title: const Text('本地分流策略')),
      body: _loading || cfg == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _intro(context),
                const SizedBox(height: 14),
                _scoreRules(context),
                const SizedBox(height: 14),
                _section(context, '策略档位'),
                for (final level in TriageLevel.values)
                  _levelTile(context, cfg, level),
                const SizedBox(height: 14),
                _section(context, '隐私'),
                _sensitiveTile(context, cfg),
                const SizedBox(height: 14),
                _section(context, '按操作控制'),
                for (final op in _cloudOperations)
                  _operationTile(context, cfg, op),
                const SizedBox(height: 14),
                _section(context, '额度'),
                _quotaTile(context, cfg),
                const SizedBox(height: 14),
                _section(context, '展示'),
                SwitchListTile(
                  value: cfg.showExplanations,
                  onChanged: (v) => _update(cfg.copyWith(showExplanations: v)),
                  title: const Text('显示分流说明'),
                  subtitle: const Text('在笔记与任务列表里标出"为什么送/不送 AI"'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
    );
  }

  /// 会被分流的云端操作（本地操作如向量索引不在这里）
  static const List<TriageOperation> _cloudOperations = [
    TriageOperation.autoTag,
    TriageOperation.autoClassify,
    TriageOperation.autoSummary,
    TriageOperation.deColloquial,
    TriageOperation.extractPlan,
  ];

  /// 打分规则（可折叠）：把"多少分才送 AI"讲清楚，用户就不觉得是黑盒。
  Widget _scoreRules(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.rule_rounded, color: colorScheme.primary),
        title: const Text('打分规则（怎么判断值不值得）'),
        subtitle: const Text('累加命中信号，≥ 3 分才联网处理'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _ruleRow(context, '+3', '命中时间表达', '明天／下周三／3月5日／15:30／三天内'),
          _ruleRow(context, '+2', '命中待办关键词', '记得／别忘／要交／提交／截止'),
          _ruleRow(context, '+2', '命中日程关键词', '开会／见面／约／拜访／闹钟'),
          _ruleRow(context, '+1', '只有"今天/昨天"这类', '只是时间框架，不是有事要办'),
          _ruleRow(context, '−1', '句尾是"吗/呢/？"', '更像闲聊提问，不是要记的事'),
          _ruleRow(context, '−1', '文本少于 6 字', '太短，多半是随手记'),
          _ruleRow(context, '−3', '疑似测试/占位内容', '避免开发和试写内容占用额度'),
          const Divider(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '总分 ≥ 3 → 送 AI 深度处理（并只发送相关片段）\n'
              '总分 < 3 → 本地保存，不联网、不花额度',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(BuildContext context, String score, String title, String hint) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              score,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: score.startsWith('+')
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                if (hint.isNotEmpty)
                  Text(
                    hint,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('三级分流', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '① 本地规则引擎（离线、零延迟）→ 判断"值不值得"\n'
              '② 本地轻量分类器（可选）→ 给规则拿不准的内容兜底\n'
              '③ 云端大模型 → 只处理被上面选中的内容',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '未命中的内容一律本地保存，不联网、不消耗额度。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _levelTile(BuildContext context, TriageConfig cfg, TriageLevel level) {
    final selected = cfg.level == level;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => _update(cfg.copyWith(level: level)),
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? colorScheme.primary : colorScheme.outline,
      ),
      title: Text(level.label),
      subtitle: Text(level.description),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _sensitiveTile(BuildContext context, TriageConfig cfg) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: cfg.allowSensitiveToCloud
          ? colorScheme.errorContainer
          : colorScheme.surfaceContainerHigh,
      child: SwitchListTile(
        value: cfg.allowSensitiveToCloud,
        onChanged: (v) => _update(cfg.copyWith(allowSensitiveToCloud: v)),
        title: const Text('允许把敏感内容送云端'),
        subtitle: Text(
          cfg.allowSensitiveToCloud
              ? '⚠️ 手机号/身份证/银行卡/密钥等将可能被上传'
              : '默认关闭：检测到手机号、身份证、银行卡、密钥等一律本地保存',
        ),
        secondary: Icon(
          cfg.allowSensitiveToCloud
              ? Icons.warning_amber_rounded
              : Icons.lock_outline_rounded,
        ),
        dense: true,
      ),
    );
  }

  Widget _operationTile(
    BuildContext context,
    TriageConfig cfg,
    TriageOperation op,
  ) {
    final enabled = cfg.isEnabled(op);
    return SwitchListTile(
      value: enabled,
      onChanged: (v) {
        final next = {...cfg.disabledOperations};
        if (v) {
          next.remove(op);
        } else {
          next.add(op);
        }
        _update(cfg.copyWith(disabledOperations: next));
      },
      title: Text(_operationLabel(op)),
      subtitle: Text(
        enabled ? _operationHint(op) : '已关闭：该操作不再入队（本地保存）',
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  static String _operationLabel(TriageOperation op) => switch (op) {
    TriageOperation.autoTag => '自动标签',
    TriageOperation.autoClassify => '自动分类',
    TriageOperation.autoSummary => '自动摘要',
    TriageOperation.deColloquial => '去口语化',
    TriageOperation.extractPlan => '提取待办/日程',
    _ => op.name,
  };

  static String _operationHint(TriageOperation op) => switch (op) {
    TriageOperation.autoTag => '内容有主题词或已成篇时才上云',
    TriageOperation.autoClassify => '与自动标签同源，按分流结果决定',
    TriageOperation.autoSummary => '内容较长（60 字以上）才上云',
    TriageOperation.deColloquial => '检测到明显口语特征才上云',
    TriageOperation.extractPlan => '命中时间/待办/客户线索才上云',
    _ => '',
  };

  Widget _quotaTile(BuildContext context, TriageConfig cfg) {
    final quota = cfg.quota;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('每月最多联网处理'),
                const Spacer(),
                Text(
                  quota.unlimited ? '不限制' : '${quota.monthlyLimit} 次',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            Slider(
              value: quota.unlimited ? 0 : quota.monthlyLimit.toDouble(),
              min: 0,
              max: 1000,
              divisions: 20,
              label: quota.unlimited ? '不限制' : '${quota.monthlyLimit}',
              onChanged: (v) => _update(
                cfg.copyWith(
                  quota: quota.copyWith(monthlyLimit: v.round()),
                ),
              ),
            ),
            Text(
              quota.unlimited
                  ? '当前未设上限。建议设一个上限，避免意外花销。'
                  : '本月已用 ${quota.usedThisMonth} / ${quota.monthlyLimit} 次'
                        '（超出后自动转为本地保存）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!quota.unlimited) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: quota.usage),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await _update(
                    cfg.copyWith(quota: quota.copyWith(usedThisMonth: 0)),
                  );
                  toast.info(message: '本月用量已清零');
                },
                child: const Text('清零本月用量'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
