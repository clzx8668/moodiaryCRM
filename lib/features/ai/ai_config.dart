import 'package:moodiary/persistence/secure_storage.dart';

/// AI Provider 配置（OpenAI 兼容，DeepSeek/OpenAI 通用）。
///
/// 密钥存 flutter_secure_storage（与 CRM 令牌同一存储模式，不入 git）。
class AiConfig {
  static const String keyBaseUrl = 'ai_base_url';
  static const String keyApiKey = 'ai_api_key';
  static const String keyModel = 'ai_model';

  static const String defaultBaseUrl = 'https://api.deepseek.com/v1';
  static const String defaultModel = 'deepseek-chat';

  final String baseUrl;
  final String apiKey;
  final String model;
  final int timeoutSeconds;

  const AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.timeoutSeconds = 60,
  });

  bool get isConfigured => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  String get chatCompletionsUrl =>
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions';

  static Future<AiConfig> load() async {
    final baseUrl = await SecureStorageUtil.getValue(keyBaseUrl);
    final apiKey = await SecureStorageUtil.getValue(keyApiKey);
    final model = await SecureStorageUtil.getValue(keyModel);
    return AiConfig(
      baseUrl: baseUrl ?? defaultBaseUrl,
      apiKey: apiKey ?? '',
      model: model ?? defaultModel,
    );
  }

  static Future<void> save({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    await SecureStorageUtil.setValue(keyBaseUrl, baseUrl);
    await SecureStorageUtil.setValue(keyApiKey, apiKey);
    await SecureStorageUtil.setValue(keyModel, model);
  }
}
