import 'dart:convert';

import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/persistence/secure_storage.dart';

/// 能力配置存储（安全存储）。
///
/// 首次读取时从服务商列表生成默认能力：
/// - chat：启用（使用全部启用服务商，主备切换）；
/// - embedding / vision / voice：取第一个配置了对应模型的服务商。
class AiCapabilityStore {
  AiCapabilityStore._();

  static const String _storageKey = 'ai_capabilities';

  static Future<AiCapabilitySet> load() async {
    final raw = await SecureStorageUtil.getValue(_storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          return AiCapabilitySet.fromJson(json);
        }
      } catch (_) {
        // 损坏回退默认生成
      }
    }
    return _generateDefault();
  }

  static Future<void> save(AiCapabilitySet set) async {
    await SecureStorageUtil.setValue(_storageKey, jsonEncode(set.toJson()));
  }

  /// 从服务商列表生成默认能力（兼容旧版单配置迁移）
  static Future<AiCapabilitySet> _generateDefault() async {
    final providers = await AiProviderStore.loadAll();
    final enabled = AiProviderStore.enabledConfigured(providers);
    if (enabled.isEmpty) {
      return AiCapabilitySet();
    }

    String? firstWith(String? Function(AiProviderConfig c) pick) {
      for (final c in enabled) {
        final v = pick(c);
        if (v != null && v.trim().isNotEmpty) return c.id;
      }
      return null;
    }

    return AiCapabilitySet(
      chat: AiCapabilityConfig(
        id: 'chat',
        enabled: true,
        providerId: '',
        modelName: enabled.first.chatModel,
      ),
      embedding: AiCapabilityConfig(
        id: 'embedding',
        enabled: firstWith((c) => c.embeddingModel) != null,
        providerId: firstWith((c) => c.embeddingModel) ?? '',
        modelName: _firstModel(enabled, (c) => c.embeddingModel),
      ),
      vision: AiCapabilityConfig(
        id: 'vision',
        enabled: firstWith((c) => c.visionModel) != null,
        providerId: firstWith((c) => c.visionModel) ?? '',
        modelName: _firstModel(enabled, (c) => c.visionModel),
      ),
      voice: AiCapabilityConfig(
        id: 'voice',
        enabled: firstWith((c) => c.voiceModel) != null,
        providerId: firstWith((c) => c.voiceModel) ?? '',
        modelName: _firstModel(enabled, (c) => c.voiceModel),
      ),
    );
  }

  static String _firstModel(
    List<AiProviderConfig> list,
    String? Function(AiProviderConfig c) pick,
  ) {
    for (final c in list) {
      final v = pick(c);
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return '';
  }
}
