import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_provider_edit_page.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';

/// AI 模型管理页：服务商（账号）+ 功能模型（对话/向量/多模态/语音）独立配置。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  List<AiProviderConfig> _providers = [];
  AiCapabilitySet _caps = AiCapabilitySet();
  bool _loading = true;
  final Map<String, AiConnectionResult> _testResults = {};
  final Set<String> _testing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final providers = await AiProviderStore.loadAll();
    final caps = await AiCapabilityStore.load();
    if (mounted) {
      setState(() {
        _providers = AiProviderStore.sortByPriority(providers);
        _caps = caps;
        _loading = false;
      });
    }
  }

  Future<void> _saveCaps() async {
    await AiCapabilityStore.save(_caps);
  }

  Future<void> _addProvider() async {
    final changed = await Get.to(() => const AiProviderEditPage());
    if (changed == true) await _load();
  }

  Future<void> _editProvider(AiProviderConfig config) async {
    final changed = await Get.to(() => AiProviderEditPage(initial: config));
    if (changed == true) await _load();
  }

  Future<void> _testProvider(AiProviderConfig config) async {
    setState(() => _testing.add(config.id));
    final result = await AiConnectionTester.test(config.toAiConfig());
    if (mounted) {
      setState(() {
        _testing.remove(config.id);
        _testResults[config.id] = result;
      });
    }
  }

  Future<void> _moveProvider(AiProviderConfig config, int delta) async {
    final index = _providers.indexWhere((c) => c.id == config.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= _providers.length) return;
    await AiProviderStore.swapPriority(_providers[index].id, _providers[target].id);
    await _load();
  }

  Future<void> _deleteProvider(AiProviderConfig config) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除服务商'),
        content: Text('删除「${config.name}」？功能模型若引用了它将失效。'),
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
            onPressed: _addProvider,
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加服务商',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProvider,
        tooltip: '添加服务商',
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                const _SectionTitle(
                  icon: Icons.dns_rounded,
                  title: '服务商（账号）',
                  subtitle: '管理 Base URL / API Key；对话按这里的主备顺序自动切换',
                ),
                if (_providers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        '还没有服务商，点击 + 添加',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < _providers.length; i++)
                    _buildProviderCard(context, _providers[i], i),
                const SizedBox(height: 18),
                const _SectionTitle(
                  icon: Icons.tune_rounded,
                  title: '功能模型',
                  subtitle: '每项能力可独立选择服务商与模型（互不依赖）',
                ),
                _buildCapabilityCard(
                  context,
                  capability: _caps.chat,
                  title: '对话（大语言模型）',
                  subtitle: 'AI 对话与智能处理；使用全部启用服务商，主备自动切换',
                  icon: Icons.chat_bubble_outline_rounded,
                  showModelField: false,
                ),
                _buildCapabilityCard(
                  context,
                  capability: _caps.embedding,
                  title: '向量模型',
                  subtitle: '知识库 RAG 检索（专用，如 text-embedding-3-small）',
                  icon: Icons.polyline_rounded,
                  showModelField: true,
                ),
                _buildCapabilityCard(
                  context,
                  capability: _caps.vision,
                  title: '多模态模型',
                  subtitle: '图片理解（专用，如 gpt-4o）',
                  icon: Icons.image_search_rounded,
                  showModelField: true,
                ),
                _buildCapabilityCard(
                  context,
                  capability: _caps.voice,
                  title: '语音识别模型',
                  subtitle: '语音转文字（专用，如 whisper-1）',
                  icon: Icons.mic_none_rounded,
                  showModelField: true,
                ),
              ],
            ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context,
    AiProviderConfig config,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = _testResults[config.id];
    final testing = _testing.contains(config.id);
    final anyEnabled = _providers.any((c) => c.enabled);
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
                      if (config.chatModel.isNotEmpty)
                        Text(
                          '默认对话模型：${config.chatModel}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
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
                  onPressed: testing ? null : () => _testProvider(config),
                ),
                ActionChip(
                  label: const Text('编辑'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editProvider(config),
                ),
                ActionChip(
                  label: const Text('上移'),
                  visualDensity: VisualDensity.compact,
                  onPressed: index == 0 ? null : () => _moveProvider(config, -1),
                ),
                ActionChip(
                  label: const Text('下移'),
                  visualDensity: VisualDensity.compact,
                  onPressed: index >= _providers.length - 1
                      ? null
                      : () => _moveProvider(config, 1),
                ),
                ActionChip(
                  label: const Text('删除'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteProvider(config),
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

  Widget _buildCapabilityCard(
    BuildContext context, {
    required AiCapabilityConfig capability,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool showModelField,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final providerOptions = _providers
        .where((c) => c.isConfigured)
        .toList();
    final selectedProvider = _findProvider(
      providerOptions,
      capability.providerId,
    );

    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: capability.enabled,
                  onChanged: (v) async {
                    setState(() => capability.enabled = v);
                    await _saveCaps();
                  },
                ),
              ],
            ),
            if (capability.enabled) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedProvider?.id,
                decoration: const InputDecoration(
                  labelText: '使用服务商',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  if (capability.id == 'chat' && providerOptions.isNotEmpty)
                    const DropdownMenuItem(
                      value: '',
                      child: Text('全部（主备自动切换）'),
                    ),
                  for (final p in providerOptions)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) async {
                  setState(() {
                    capability.providerId = v ?? '';
                    // 选中服务商时，若模型名为空则取其默认模型建议
                    if (capability.modelName.isEmpty && v != null) {
                      final target = _findProvider(providerOptions, v);
                      capability.modelName = switch (capability.id) {
                        'embedding' => target?.embeddingModel ?? '',
                        'vision' => target?.visionModel ?? '',
                        'voice' => target?.voiceModel ?? '',
                        _ => target?.chatModel ?? '',
                      };
                    }
                  });
                  await _saveCaps();
                },
              ),
              if (showModelField) ...[
                const SizedBox(height: 10),
                _ModelField(
                  key: ValueKey(
                    '${capability.id}-${capability.providerId}-${capability.modelName}',
                  ),
                  models: selectedProvider?.models ?? const [],
                  modelName: capability.modelName,
                  onChanged: (v) {
                    capability.modelName = v;
                    _saveCaps();
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  AiProviderConfig? _findProvider(
    List<AiProviderConfig> list,
    String id,
  ) {
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// 模型名选择：优先下拉已选服务商的可用模型，空列表时回退手输。
class _ModelField extends StatelessWidget {
  final List<String> models;
  final String modelName;
  final ValueChanged<String> onChanged;

  const _ModelField({
    super.key,
    required this.models,
    required this.modelName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) {
      return TextFormField(
        initialValue: modelName,
        decoration: const InputDecoration(
          labelText: '模型名',
          helperText: '该服务商尚未选择模型，可先到「服务商」拉取官方模型列表',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => onChanged(v.trim()),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: modelName,
      decoration: const InputDecoration(
        labelText: '模型名',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final m in models) DropdownMenuItem(value: m, child: Text(m)),
        if (!models.contains(modelName) && modelName.isNotEmpty)
          DropdownMenuItem(value: modelName, child: Text('$modelName（自定义）')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
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
