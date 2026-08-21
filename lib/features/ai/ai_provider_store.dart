import 'dart:convert';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/persistence/secure_storage.dart';

/// 多平台模型配置存储（安全存储，JSON 数组）。
///
/// 兼容旧版单配置：首次读取时若列表为空但旧 key 有值，自动迁移为默认 Provider。
class AiProviderStore {
  AiProviderStore._();

  static const String _storageKey = 'ai_providers_list';

  /// 读取全部配置（含旧配置迁移）
  static Future<List<AiProviderConfig>> loadAll() async {
    final raw = await SecureStorageUtil.getValue(_storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map(AiProviderConfig.fromJson)
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {
        // 损坏数据回退迁移逻辑
      }
    }
    return _migrateLegacy();
  }

  /// 旧版单配置迁移：把 ai_base_url/ai_api_key/... 转为首个 Provider
  static Future<List<AiProviderConfig>> _migrateLegacy() async {
    final legacy = await AiConfig.load();
    if (legacy.apiKey.trim().isEmpty) return [];
    final cfg = AiProviderConfig()
      ..name = '默认服务'
      ..baseUrl = legacy.baseUrl
      ..apiKey = legacy.apiKey
      ..chatModel = legacy.model
      ..embeddingModel = legacy.embeddingModel
      ..enabled = true
      ..priority = 0;
    await saveAll([cfg]);
    return [cfg];
  }

  static Future<void> saveAll(List<AiProviderConfig> list) async {
    await SecureStorageUtil.setValue(
      _storageKey,
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
    AiProviderFactory.invalidate();
  }

  /// 新增/更新单个配置
  static Future<void> upsert(AiProviderConfig config) async {
    final list = await loadAll();
    config.updatedAt = DateTime.now();
    final index = list.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      list[index] = config;
    } else {
      config.priority = list.isEmpty ? 0 : (list.map((c) => c.priority).reduce((a, b) => a > b ? a : b) + 1);
      list.add(config);
    }
    await saveAll(list);
  }

  static Future<void> remove(String id) async {
    final list = await loadAll();
    list.removeWhere((c) => c.id == id);
    await saveAll(list);
  }

  static Future<void> setEnabled(String id, bool enabled) async {
    final list = await loadAll();
    final index = list.indexWhere((c) => c.id == id);
    if (index >= 0) {
      list[index].enabled = enabled;
      await saveAll(list);
    }
  }

  /// 交换两条配置的主备顺序
  static Future<void> swapPriority(String idA, String idB) async {
    final list = await loadAll();
    final a = list.indexWhere((c) => c.id == idA);
    final b = list.indexWhere((c) => c.id == idB);
    if (a >= 0 && b >= 0) {
      final tmp = list[a].priority;
      list[a].priority = list[b].priority;
      list[b].priority = tmp;
      await saveAll(list);
    }
  }

  /// 纯函数：按优先级排序（priority 升序）
  static List<AiProviderConfig> sortByPriority(List<AiProviderConfig> list) {
    final copy = List<AiProviderConfig>.from(list);
    copy.sort((a, b) => a.priority.compareTo(b.priority));
    return copy;
  }

  /// 纯函数：仅启用且已配置
  static List<AiProviderConfig> enabledConfigured(
    List<AiProviderConfig> list,
  ) {
    return sortByPriority(list)
        .where((c) => c.enabled && c.isConfigured)
        .toList();
  }
}
