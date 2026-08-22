import 'package:moodiary/persistence/secure_storage.dart';

/// AI Provider 配置（OpenAI 兼容，DeepSeek/OpenAI 通用）。
///
/// 密钥存 flutter_secure_storage（与 CRM 令牌同一存储模式，不入 git）。
class AiConfig {
  static const String keyBaseUrl = 'ai_base_url';
  static const String keyApiKey = 'ai_api_key';
  static const String keyModel = 'ai_model';
  static const String keyEmbeddingModel = 'ai_embedding_model';

  static const String defaultBaseUrl = 'https://api.deepseek.com/v1';
  static const String defaultModel = 'deepseek-chat';
  static const String defaultEmbeddingModel = 'text-embedding-3-small';

  final String baseUrl;
  final String apiKey;
  final String model;
  final String embeddingModel;
  final int timeoutSeconds;

  /// 嵌入请求使用的模型名（能力配置优先于服务商默认值）
  final String modelForEmbedding;

  const AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.embeddingModel = defaultEmbeddingModel,
    this.modelForEmbedding = '',
    this.timeoutSeconds = 60,
  });

  bool get isConfigured => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  String get chatCompletionsUrl =>
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions';

  String get embeddingsUrl =>
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/embeddings';

  /// 实际使用的向量模型：能力配置覆盖 > 服务商默认
  String get effectiveEmbeddingModel =>
      modelForEmbedding.trim().isNotEmpty
      ? modelForEmbedding
      : embeddingModel;

  static Future<AiConfig> load() async {
    final baseUrl = await SecureStorageUtil.getValue(keyBaseUrl);
    final apiKey = await SecureStorageUtil.getValue(keyApiKey);
    final model = await SecureStorageUtil.getValue(keyModel);
    final embeddingModel = await SecureStorageUtil.getValue(keyEmbeddingModel);
    return AiConfig(
      baseUrl: baseUrl ?? defaultBaseUrl,
      apiKey: apiKey ?? '',
      model: model ?? defaultModel,
      embeddingModel: embeddingModel ?? defaultEmbeddingModel,
    );
  }

  static Future<void> save({
    required String baseUrl,
    required String apiKey,
    required String model,
    String embeddingModel = defaultEmbeddingModel,
  }) async {
    await SecureStorageUtil.setValue(keyBaseUrl, baseUrl);
    await SecureStorageUtil.setValue(keyApiKey, apiKey);
    await SecureStorageUtil.setValue(keyModel, model);
    await SecureStorageUtil.setValue(keyEmbeddingModel, embeddingModel);
  }
}
