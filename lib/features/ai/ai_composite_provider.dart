import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/multi_provider.dart';

/// 组合 Provider：对话走主备切换（全部启用服务商），
/// Embedding 走独立配置的专用向量服务（可不同于对话服务商）。
///
/// 这是"能力按功能分开配置"的运行时落地：DeepSeek 做对话、
/// OpenAI 做向量互不干扰。
class AiCompositeProvider implements AiProvider {
  final MultiProvider _chat;
  final OpenAiCompatibleProvider? _embedding;
  final String? _embeddingName;

  AiCompositeProvider({
    required MultiProvider chat,
    OpenAiCompatibleProvider? embedding,
    String? embeddingName,
  }) : _chat = chat,
       _embedding = embedding,
       _embeddingName = embeddingName;

  /// 从存储构建（读取能力配置）
  static Future<AiCompositeProvider> fromStore() async {
    final providers = await AiProviderStore.loadAll();
    final caps = await AiCapabilityStore.load();
    final enabled = AiProviderStore.enabledConfigured(providers);

    // 对话：全部启用服务商按优先级主备（chat.providerId 为空时）
    final chatProviders = <OpenAiCompatibleProvider>[];
    if (caps.chat.enabled) {
      if (caps.chat.providerId.isNotEmpty) {
        // 指定单个服务商作为对话
        final target = enabled.where((c) => c.id == caps.chat.providerId);
        chatProviders.addAll(
          target.map((c) => OpenAiCompatibleProvider(config: c.toAiConfig())),
        );
      } else {
        chatProviders.addAll(
          enabled.map((c) => OpenAiCompatibleProvider(config: c.toAiConfig())),
        );
      }
    }

    // 向量：独立能力配置
    OpenAiCompatibleProvider? embedding;
    String? embeddingName;
    if (caps.embedding.enabled && caps.embedding.providerId.isNotEmpty) {
      final target = providers.where(
        (c) => c.id == caps.embedding.providerId && c.isConfigured,
      );
      if (target.isNotEmpty) {
        final cfg = target.first;
        embeddingName = cfg.name;
        embedding = OpenAiCompatibleProvider(
          config: cfg.toAiConfig(
            embeddingModelOverride: caps.embedding.modelName,
          ),
        );
      }
    }

    return AiCompositeProvider(
      chat: MultiProvider(chatProviders),
      embedding: embedding,
      embeddingName: embeddingName,
    );
  }

  @override
  bool get isConfigured => _chat.isConfigured || _embedding != null;

  @override
  Stream<AiChunk> streamChat(List<AiChatMessage> messages) =>
      _chat.streamChat(messages);

  @override
  Stream<AiChunk> streamTemplate({
    required String content,
    required String template,
  }) =>
      _chat.streamTemplate(content: content, template: template);

  @override
  Future<List<double>> embed(String text) async {
    final provider = _embedding;
    if (provider == null) {
      throw StateError(
        '未配置向量模型：请到「模型管理 → 功能模型 → 向量模型」启用并选择服务商。'
        '（DeepSeek 无 embeddings 接口，需使用支持 embeddings 的服务，如 OpenAI）',
      );
    }
    try {
      return await provider.embed(text);
    } catch (e) {
      throw StateError(
        '向量服务「$_embeddingName」调用失败：$e',
      );
    }
  }
}
