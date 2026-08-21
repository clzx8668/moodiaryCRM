import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_provider_edit_page.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';

/// AI 模型管理页（CC Switch 样式）：多平台模型列表 + 开关 + 测试联通 + 主备排序。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  List<AiProviderConfig> _list = [];
  bool _loading = true;
  final Map<String, AiConnectionResult> _testResults = {};
  final Set<String> _testing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AiProviderStore.loadAll();
    if (mounted) {
      setState(() {
        _list = AiProviderStore.sortByPriority(list);
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final changed = await Get.to(() => const AiProviderEditPage());
    if (changed == true) await _load();
  }

  Future<void> _edit(AiProviderConfig config) async {
    final changed = await Get.to(() => AiProviderEditPage(initial: config));
    if (changed == true) await _load();
  }

  Future<void> _test(AiProviderConfig config) async {
    setState(() => _testing.add(config.id));
    final result = await AiConnectionTester.test(config.toAiConfig());
    if (mounted) {
      setState(() {
        _testing.remove(config.id);
        _testResults[config.id] = result;
      });
    }
  }

  Future<void> _move(AiProviderConfig config, int delta) async {
    final index = _list.indexWhere((c) => c.id == config.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= _list.length) return;
    await AiProviderStore.swapPriority(_list[index].id, _list[target].id);
    await _load();
  }

  Future<void> _delete(AiProviderConfig config) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除模型'),
        content: Text('删除「${config.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AiProviderStore.remove(config.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型管理'),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加模型',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: '添加模型',
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 56,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('还没有模型配置，点击 + 添加服务商'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: _list.length,
              itemBuilder: (context, index) {
                final config = _list[index];
                return _buildCard(context, config, index);
              },
            ),
    );
  }

  Widget _buildCard(BuildContext context, AiProviderConfig config, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = _testResults[config.id];
    final testing = _testing.contains(config.id);
    final anyEnabled = _list.any((c) => c.enabled);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    config.name.isEmpty ? '?' : config.name.characters.first,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              config.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (config.enabled && index == 0 && anyEnabled)
                            _Badge(
                              label: '主',
                              color: colorScheme.primaryContainer,
                              textColor: colorScheme.onPrimaryContainer,
                            )
                          else if (config.enabled && index > 0)
                            _Badge(
                              label: '备 $index',
                              color: colorScheme.secondaryContainer,
                              textColor: colorScheme.onSecondaryContainer,
                            )
                          else if (!config.enabled)
                            _Badge(
                              label: '关闭',
                              color: colorScheme.surfaceContainerHighest,
                              textColor: colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.baseUrl,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          if (config.chatModel.isNotEmpty) '对话 ${config.chatModel}',
                          if (config.embeddingModel.isNotEmpty)
                            '向量 ${config.embeddingModel}',
                          if (config.visionModel.isNotEmpty)
                            '多模态 ${config.visionModel}',
                          if (config.voiceModel.isNotEmpty)
                            '语音 ${config.voiceModel}',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: config.enabled,
                  onChanged: (v) async {
                    await AiProviderStore.setEnabled(config.id, v);
                    await _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: Text(testing ? '测试中…' : '测试联通'),
                  visualDensity: VisualDensity.compact,
                  onPressed: testing ? null : () => _test(config),
                ),
                ActionChip(
                  label: const Text('编辑'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _edit(config),
                ),
                ActionChip(
                  label: const Text('上移'),
                  visualDensity: VisualDensity.compact,
                  onPressed: index == 0 ? null : () => _move(config, -1),
                ),
                ActionChip(
                  label: const Text('下移'),
                  visualDensity: VisualDensity.compact,
                  onPressed: index >= _list.length - 1
                      ? null
                      : () => _move(config, 1),
                ),
                ActionChip(
                  label: const Text('删除'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _delete(config),
                ),
              ],
            ),
            if (result != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      result.ok
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 16,
                      color: result.ok
                          ? Colors.green.shade600
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        result.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: result.ok
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: textColor),
      ),
    );
  }
}
