import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';

/// 一次「当前对话模型」的选择。
///
/// [providerId] 为空 = 默认档：全部启用服务商按优先级主备自动切换。
class ChatModelSelection {
  /// 默认档（主备自动切换）
  static const String defaultProviderId = '';

  final String providerId;
  final String providerName;
  final String modelName;

  const ChatModelSelection({
    required this.providerId,
    required this.providerName,
    required this.modelName,
  });

  bool get isDefault => providerId.trim().isEmpty;

  /// 完整标签（面板里展示）
  String get label {
    if (isDefault) return '默认（主备自动切换）';
    if (modelName.trim().isEmpty) return providerName;
    return '$providerName · $modelName';
  }

  /// 输入条 chip 上的短标签
  String get shortLabel {
    if (isDefault) return '默认';
    final m = modelName.trim();
    if (m.isEmpty) return providerName;
    // 形如 Qwen/Qwen3-8B 只显示末段，避免 chip 过长
    final tail = m.split('/').last;
    return tail.isEmpty ? m : tail;
  }
}

/// 当前对话模型的选择与生效（快速收集 chip / 详情页 / AI 助手共用）。
///
/// 与「模型管理」共用同一份能力配置（`AiCapabilitySet.chat`），
/// 所以在这里切换后：模型管理页显示同步、所有 AI 调用（模板处理/抽取/对话/技能）
/// 下一次请求即生效（`AiProviderFactory.invalidate()` 让 Provider 重建）。
class ChatModelSelector {
  ChatModelSelector._();

  /// 可选项：默认档 + 各启用且已配置服务商的对话模型（去重、按优先级排序）。
  ///
  /// [excludeModels]：被其它能力（向量/多模态/语音）占用的模型名——
  /// 这些不是对话模型，列进来只会让人选错。
  static List<ChatModelSelection> options({
    required List<AiProviderConfig> providers,
    required AiCapabilityConfig chat,
    Set<String> excludeModels = const {},
  }) {
    final out = <ChatModelSelection>[
      const ChatModelSelection(
        providerId: ChatModelSelection.defaultProviderId,
        providerName: '',
        modelName: '',
      ),
    ];
    final seen = <String>{};
    final excluded = excludeModels
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    for (final c in AiProviderStore.sortByPriority(providers)) {
      if (!c.enabled || !c.isConfigured) continue;
      final models = c.models.isNotEmpty
          ? c.models
          : [if (c.chatModel.trim().isNotEmpty) c.chatModel];
      for (final m in models) {
        final model = m.trim();
        if (model.isEmpty) continue;
        if (excluded.contains(model)) continue;
        if (looksLikeNonChatModel(model)) continue;
        if (!seen.add('${c.id}|$model')) continue;
        out.add(
          ChatModelSelection(
            providerId: c.id,
            providerName: c.name,
            modelName: model,
          ),
        );
      }
    }
    return out;
  }

  /// 明显的非对话模型（向量/语音/重排/审核）：从候选里剔掉，
  /// 避免「内置模型」列表里混进 `BAAI/bge-m3`、`*-asr-*` 这类项。
  /// 判断是纯字符串启发式——想用非常规模型仍可去「模型管理 → 对话模型」里指定。
  static bool looksLikeNonChatModel(String modelName) {
    final m = modelName.toLowerCase();
    const markers = [
      'embedding',
      'bge-',
      'bge_',
      'rerank',
      'sensevoice',
      'whisper',
      'asr',
      'tts',
      'moderation',
    ];
    return markers.any(m.contains);
  }

  /// 当前选择（用于打勾与 chip 标签）。
  static ChatModelSelection current({
    required List<AiProviderConfig> providers,
    required AiCapabilityConfig chat,
  }) {
    if (chat.providerId.trim().isEmpty) {
      return const ChatModelSelection(
        providerId: ChatModelSelection.defaultProviderId,
        providerName: '',
        modelName: '',
      );
    }
    for (final c in providers) {
      if (c.id == chat.providerId) {
        return ChatModelSelection(
          providerId: c.id,
          providerName: c.name,
          modelName: chat.modelName.trim().isNotEmpty
              ? chat.modelName.trim()
              : c.chatModel.trim(),
        );
      }
    }
    // 配置里指的服务商已不存在 → 视为默认档
    return const ChatModelSelection(
      providerId: ChatModelSelection.defaultProviderId,
      providerName: '',
      modelName: '',
    );
  }

  /// 生效：写回对话能力配置并让 Provider 缓存失效（下一次调用即用新模型）。
  static Future<void> apply(ChatModelSelection selection) async {
    final caps = await AiCapabilityStore.load();
    caps.chat
      ..providerId = selection.providerId
      ..modelName = selection.modelName;
    // 明确选了某个模型＝要用它，顺手把对话能力打开（默认档保持原开关）
    if (!selection.isDefault) caps.chat.enabled = true;
    await AiCapabilityStore.save(caps);
    AiProviderFactory.invalidate();
  }

  /// 直接读存储得到当前短标签（输入条 chip 用）。
  static Future<String> currentShortLabel() async {
    final providers = await AiProviderStore.loadAll();
    final caps = await AiCapabilityStore.load();
    return current(providers: providers, chat: caps.chat).shortLabel;
  }
}
