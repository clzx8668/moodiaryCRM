import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/ai_settings_page.dart';
import 'package:moodiary/features/ai/chat_model_selector.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/features/ai/search/search_skill.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 「切换模型」面板（对标 ima 的模型选择弹层）。
///
/// 结构：联网搜索开关 → 内置模型（默认档 + 各服务商的对话模型，✓ 当前）→ 模型管理入口。
/// 选择即写回对话能力配置并立即生效（下一次 AI 调用使用新模型）。
Future<ChatModelSelection?> showChatModelPicker(BuildContext context) async {
  final result = await showModalBottomSheet<ChatModelSelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const ChatModelPickerSheet(),
  );
  if (result != null) {
    toast.success(message: '已切换模型：${result.label}');
  }
  return result;
}

class ChatModelPickerSheet extends StatefulWidget {
  const ChatModelPickerSheet({super.key});

  @override
  State<ChatModelPickerSheet> createState() => _ChatModelPickerSheetState();
}

class _ChatModelPickerSheetState extends State<ChatModelPickerSheet> {
  List<AiProviderConfig> _providers = const [];
  AiCapabilityConfig _chat = AiCapabilityConfig(id: 'chat');

  /// 其它能力占用的模型名（向量/多模态/语音）：不作为对话模型候选
  Set<String> _excludeModels = const {};
  ChatModelSelection _current = const ChatModelSelection(
    providerId: ChatModelSelection.defaultProviderId,
    providerName: '',
    modelName: '',
  );
  bool _loading = true;
  bool _searchEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final providers = await AiProviderStore.loadAll();
      final caps = await AiCapabilityStore.load();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _chat = caps.chat;
        _excludeModels = {
          caps.embedding.modelName,
          caps.vision.modelName,
          caps.voice.modelName,
          if (caps.embedding.providerId.isEmpty)
            ...providers.map((p) => p.embeddingModel),
          ...providers.map((p) => p.voiceModel),
          ...providers.map((p) => p.visionModel),
        };
        _current = ChatModelSelector.current(
          providers: providers,
          chat: caps.chat,
        );
        _searchEnabled = SearchConfig.enabled;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSearch(bool value) async {
    setState(() => _searchEnabled = value);
    await PrefUtil.setValue<bool>(SearchConfig.kEnabled, value);
  }

  Future<void> _pick(ChatModelSelection selection) async {
    await ChatModelSelector.apply(selection);
    if (!mounted) return;
    Navigator.pop(context, selection);
  }

  bool _isSame(ChatModelSelection a, ChatModelSelection b) =>
      a.providerId == b.providerId && a.modelName == b.modelName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = ChatModelSelector.options(
      providers: _providers,
      chat: _chat,
      excludeModels: _excludeModels,
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  Row(
                    children: [
                      Text('切换模型', style: context.textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        _current.label,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 联网搜索：与「设置 → AI 设置 → 联网搜索」同一开关
                  Card.filled(
                    margin: EdgeInsets.zero,
                    color: colorScheme.surfaceContainerLow,
                    child: SwitchListTile(
                      value: _searchEnabled,
                      onChanged: _toggleSearch,
                      secondary: const Icon(Icons.public_rounded),
                      title: const Text('联网搜索'),
                      subtitle: const Text('AI 回答时允许检索网络（引擎在 AI 设置里配置）'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      '内置模型',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Card.filled(
                    margin: EdgeInsets.zero,
                    color: colorScheme.surfaceContainerLow,
                    child: Column(
                      children: [
                        for (var i = 0; i < options.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _optionTile(context, options[i]),
                        ],
                        if (options.length == 1)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                            child: Text(
                              '还没有可用的对话模型：先在「模型管理」里添加服务商、'
                              '拉取官方模型并勾选，再回到这里切换。',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card.filled(
                    margin: EdgeInsets.zero,
                    color: colorScheme.surfaceContainerLow,
                    child: ListTile(
                      leading: const Icon(Icons.add_rounded),
                      title: const Text('模型管理'),
                      subtitle: const Text('添加服务商 / 拉取官方模型 / 配置向量与语音模型'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await Get.to(() => const AiSettingsPage());
                        await _load(); // 回来后同步最新配置
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _optionTile(BuildContext context, ChatModelSelection option) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _isSame(option, _current);
    return ListTile(
      title: Text(
        option.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: option.isDefault
          ? const Text('按「模型管理」里的启用顺序自动主备切换')
          : null,
      trailing: selected
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: () => _pick(option),
    );
  }
}
