import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_api.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/persistence/isar.dart';

/// 连接测试结果
class ConnectionResult {
  final bool ok;
  final String? message;
  final int companyCount;

  const ConnectionResult({
    required this.ok,
    this.message,
    this.companyCount = 0,
  });
}

/// 全量拉取结果
class CrmSyncResult {
  final DateTime syncedAt;
  final Map<String, int> pulledByObject;
  final int totalPulled;

  const CrmSyncResult({
    required this.syncedAt,
    required this.pulledByObject,
    required this.totalPulled,
  });

  @override
  String toString() =>
      'CrmSyncResult(syncedAt: $syncedAt, totalPulled: $totalPulled, '
      'byObject: $pulledByObject)';
}

/// CRM 同步服务：Twenty 增量/全量同步 + 本地缓存（架构文档 P1.8）
class CrmSyncService {
  final TwentyApiClient client;
  final SyncLogService log;

  static const Set<String> defaultObjects = {
    'company',
    'person',
    'opportunity',
    'task',
  };

  CrmSyncService({required this.client, SyncLogService? log})
    : log = log ?? SyncLogService.instance;

  factory CrmSyncService.fromConfig(TwentyConfig config) {
    return CrmSyncService(client: TwentyApiClient(config: config));
  }

  /// 连接测试：ping + 拉取一页公司验证令牌
  Future<ConnectionResult> testConnection() async {
    try {
      final ok = await client.ping();
      if (!ok) {
        await log.write(
          level: SyncLogLevel.error,
          operation: 'test',
          target: 'server',
          detail: '健康检查未通过',
        );
        return const ConnectionResult(
          ok: false,
          message: '服务健康检查未通过',
        );
      }
      final companies = await client.listAll(object: 'company', pageSize: 1);
      await log.write(
        level: SyncLogLevel.info,
        operation: 'test',
        target: 'company',
        detail: '连接成功，可访问公司数据',
      );
      return ConnectionResult(
        ok: true,
        message: '连接成功（Twenty 在线）',
        companyCount: companies.length,
      );
    } on TwentyApiException catch (e) {
      await log.write(
        level: SyncLogLevel.error,
        operation: 'test',
        target: 'server',
        detail: '连接失败',
        error: e.toString(),
      );
      return ConnectionResult(ok: false, message: e.message);
    } catch (e) {
      await log.write(
        level: SyncLogLevel.error,
        operation: 'test',
        target: 'server',
        detail: '连接异常',
        error: e.toString(),
      );
      return ConnectionResult(ok: false, message: e.toString());
    }
  }

  /// 全量拉取指定对象到本地缓存
  Future<CrmSyncResult> fullPull({
    Set<String> objects = defaultObjects,
  }) async {
    final pulledByObject = <String, int>{};
    var total = 0;
    for (final object in objects) {
      final count = await pullObject(object);
      pulledByObject[object] = count;
      total += count;
    }
    final result = CrmSyncResult(
      syncedAt: DateTime.now(),
      pulledByObject: pulledByObject,
      totalPulled: total,
    );
    await log.write(
      level: SyncLogLevel.info,
      operation: 'pull',
      target: 'crm',
      detail: '全量拉取完成：$result',
    );
    return result;
  }

  /// 拉取单个对象并 upsert 本地缓存
  Future<int> pullObject(String object) async {
    final entities = await client.listAll(object: object);
    final now = DateTime.now();
    final caches = <CrmEntityCache>[];
    for (final entity in entities) {
      final existing = await IsarUtil.getCrmEntityByTwentyId(entity.id);
      final cache = existing ?? CrmEntityCache()..twentyId = entity.id;
      cache
        ..entityType = object
        ..name = entity.data['name']?.toString() ??
            entity.data['title']?.toString() ??
            entity.id
        ..setData(entity.data)
        ..isDeleted = false
        ..lastSyncedAt = now
        ..updatedAt = now;
      caches.add(cache);
    }
    await IsarUtil.upsertCrmEntities(caches);
    return caches.length;
  }

  /// 创建公司并写入本地缓存（推送到 Twenty）
  Future<TwentyEntity> createCompany({
    required String name,
    Map<String, dynamic>? extra,
  }) async {
    final created = await client.create(
      object: 'company',
      data: {'name': name, ...?extra},
    );
    final now = DateTime.now();
    final cache = CrmEntityCache()
      ..twentyId = created.id
      ..entityType = 'company'
      ..name = name
      ..setData(created.data)
      ..lastSyncedAt = now
      ..updatedAt = now;
    await IsarUtil.upsertCrmEntities([cache]);
    await log.write(
      level: SyncLogLevel.info,
      operation: 'push',
      target: 'company',
      detail: '创建公司 $name（${created.id}）',
    );
    return created;
  }

  /// 删除远端公司并清理本地缓存
  Future<void> deleteCompany(String id) async {
    await client.delete(object: 'company', id: id);
    await IsarUtil.removeCrmEntityByTwentyId(id);
    await log.write(
      level: SyncLogLevel.info,
      operation: 'push',
      target: 'company',
      detail: '删除公司 $id',
    );
  }

  /// 本地缓存搜索（跨对象）
  Future<List<CrmEntityCache>> searchLocal(String keyword) {
    return IsarUtil.searchCrmByName(keyword);
  }

  /// 本地缓存统计
  Future<Map<String, int>> localStats() async {
    final stats = <String, int>{};
    for (final object in defaultObjects) {
      stats[object] = await IsarUtil.countCrmEntitiesByType(object);
    }
    return stats;
  }
}
