import 'package:moodiary/features/ai/ai_config.dart';
import 'package:uuid/uuid.dart';

/// AI 平台模型配置（多平台管理，CC Switch 样式）。
///
/// 一个配置 = 一个服务商（如 DeepSeek / OpenAI / Kimi / 通义），
/// 同时声明其大语言模型 / 向量模型 / 多模态模型 / 语音识别模型；
/// [enabled] 手动开关，[priority] 决定主备顺序（0 为主，越大越备用）。
class AiProviderConfig {
  /// 业务主键（UUID）
  String id = const Uuid().v7();

  /// 服务商显示名
  String name = '';

  /// OpenAI 兼容 Base URL（如 https://api.deepseek.com/v1）
  String baseUrl = '';

  /// API Key（安全存储）
  String apiKey = '';

  /// 大语言模型（chat/completions）
  String chatModel = '';

  /// 向量模型（embeddings，知识库用）
  String embeddingModel = '';

  /// 多模态模型（视觉/图片理解，预留）
  String visionModel = '';

  /// 语音识别模型（预留）
  String voiceModel = '';

  /// 手动开启/关闭
  bool enabled = true;

  /// 主备优先级：0 为主，越大越靠后（备用）
  int priority = 0;

  /// 从服务商 /models 拉取并勾选后的可用模型列表（功能模型从这里选）
  List<String> models = [];

  String description = '';

  DateTime updatedAt = DateTime.now();

  AiProviderConfig();

  bool get isConfigured => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  /// 转单配置（连接测试 / OpenAI 兼容实现使用）
  AiConfig toAiConfig({String embeddingModelOverride = ''}) {
    return AiConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: chatModel.trim().isEmpty ? AiConfig.defaultModel : chatModel,
      embeddingModel: embeddingModel.trim().isEmpty
          ? AiConfig.defaultEmbeddingModel
          : embeddingModel,
      modelForEmbedding: embeddingModelOverride,
    );
  }

  AiProviderConfig clone() {
    return AiProviderConfig()
      ..id = id
      ..name = name
      ..baseUrl = baseUrl
      ..apiKey = apiKey
      ..chatModel = chatModel
      ..embeddingModel = embeddingModel
      ..visionModel = visionModel
      ..voiceModel = voiceModel
      ..enabled = enabled
      ..priority = priority
      ..models = List<String>.from(models)
      ..description = description
      ..updatedAt = DateTime.fromMillisecondsSinceEpoch(
        updatedAt.millisecondsSinceEpoch,
      );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'chatModel': chatModel,
      'embeddingModel': embeddingModel,
      'visionModel': visionModel,
      'voiceModel': voiceModel,
      'enabled': enabled,
      'priority': priority,
      'models': models,
      'description': description,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig()
      ..id = json['id'] as String? ?? const Uuid().v7()
      ..name = json['name'] as String? ?? ''
      ..baseUrl = json['baseUrl'] as String? ?? ''
      ..apiKey = json['apiKey'] as String? ?? ''
      ..chatModel = json['chatModel'] as String? ?? ''
      ..embeddingModel = json['embeddingModel'] as String? ?? ''
      ..visionModel = json['visionModel'] as String? ?? ''
      ..voiceModel = json['voiceModel'] as String? ?? ''
      ..enabled = json['enabled'] as bool? ?? true
      ..priority = (json['priority'] as num?)?.toInt() ?? 0
      ..models =
          (json['models'] as List?)?.cast<String>() ?? <String>[]
      ..description = json['description'] as String? ?? ''
      ..updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now();
  }
}
