/// AI 能力配置：按功能独立指定使用的服务商与模型（参考 Blinko）。
///
/// 四种能力：
/// - chat：大语言模型（通用，AI 对话与智能处理），支持多服务商主备；
/// - embedding：向量模型（专用，知识库 RAG 检索）；
/// - vision：多模态模型（专用，图片理解）；
/// - voice：语音识别模型（专用）。
/// - light：轻量模型（专用，后台/小任务，如去口语化、标签、摘要、实体抽取）。
class AiCapabilityConfig {
  /// 能力标识：chat / embedding / vision / voice
  final String id;

  /// 是否启用该能力
  bool enabled;

  /// 使用的服务商 id（空 = 未指定；chat 为空表示使用全部启用服务商按主备切换）
  String providerId;

  /// 模型名（chat 能力为"默认对话模型"，运行时可被服务商主备覆盖）
  String modelName;

  AiCapabilityConfig({
    required this.id,
    this.enabled = false,
    this.providerId = '',
    this.modelName = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'enabled': enabled,
      'providerId': providerId,
      'modelName': modelName,
    };
  }

  factory AiCapabilityConfig.fromJson(Map<String, dynamic> json) {
    return AiCapabilityConfig(
      id: json['id'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      providerId: json['providerId'] as String? ?? '',
      modelName: json['modelName'] as String? ?? '',
    );
  }
}

/// 能力集合（完整配置单元）
class AiCapabilitySet {
  final AiCapabilityConfig chat;
  final AiCapabilityConfig embedding;
  final AiCapabilityConfig vision;
  final AiCapabilityConfig voice;
  final AiCapabilityConfig light;

  AiCapabilitySet({
    AiCapabilityConfig? chat,
    AiCapabilityConfig? embedding,
    AiCapabilityConfig? vision,
    AiCapabilityConfig? voice,
    AiCapabilityConfig? light,
  }) : chat = chat ?? AiCapabilityConfig(id: 'chat', enabled: false),
       embedding =
           embedding ?? AiCapabilityConfig(id: 'embedding'),
       vision = vision ?? AiCapabilityConfig(id: 'vision'),
       voice = voice ?? AiCapabilityConfig(id: 'voice'),
       light = light ?? AiCapabilityConfig(id: 'light');

  Map<String, dynamic> toJson() {
    return {
      'chat': chat.toJson(),
      'embedding': embedding.toJson(),
      'vision': vision.toJson(),
      'voice': voice.toJson(),
      'light': light.toJson(),
    };
  }

  factory AiCapabilitySet.fromJson(Map<String, dynamic> json) {
    AiCapabilityConfig read(String key) {
      final raw = json[key];
      if (raw is Map<String, dynamic>) {
        return AiCapabilityConfig.fromJson(raw);
      }
      return AiCapabilityConfig(id: key);
    }

    return AiCapabilitySet(
      chat: read('chat'),
      embedding: read('embedding'),
      vision: read('vision'),
      voice: read('voice'),
      light: read('light'),
    );
  }
}
