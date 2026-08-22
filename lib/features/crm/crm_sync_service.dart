import 'package:moodiary/features/crm/crm_field_registry.dart';
import 'package:moodiary/features/crm/crm_structure_sync_service.dart';
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

/// 全量同步结果（结构 + 数据记录）
class FullSyncResult {
  final StructureSyncResult structure;
  final CrmSyncResult data;

  const FullSyncResult({required this.structure, required this.data});

  @override
  String toString() => '结构[$structure] · 数据($data)';
}

/// 同步对账结果（架构文档"五、设置模块-同步对账"）
class ReconcileResult {
  final DateTime checkedAt;

  /// 远端有但本地缺失的实体（按对象）
  final Map<String, List<String>> missingLocal;

  /// 本地有但远端已删除的实体（按对象）
  final Map<String, List<String>> staleLocal;

  const ReconcileResult({
    required this.checkedAt,
    required this.missingLocal,
    required this.staleLocal,
  });

  int get totalDiff =>
      missingLocal.values.fold(0, (s, v) => s + v.length) +
      staleLocal.values.fold(0, (s, v) => s + v.length);

  @override
  String toString() =>
      'ReconcileResult(checkedAt: $checkedAt, missing: $missingLocal, '
      'stale: $staleLocal)';
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

  /// 自定义业务对象（Twenty 工作区内置扩展；GraphQL 字段名为对象名本身）
  static const Set<String> customObjects = {
    'contractsHeTongGuanLi',
    'paymentsHuiKuanJiLu',
    'invoiceFaPiao',
    'commissionsTiChengJieSuan',
  };

  /// 通用数据表（无关联内容收件箱；需按对接指导在 Twenty 创建）
  static const Set<String> genericObjects = {
    'moodiaryGeneric',
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
    Set<String>? objects,
  }) async {
    // 数据拉取前按需确保结构已同步（仅初始化/版本升级时执行，非每次）
    await CrmStructureSyncService(client: client).ensureSynced();
    final targets = objects ??
        {...defaultObjects, ...customObjects, ...genericObjects};
    final pulledByObject = <String, int>{};
    var total = 0;
    for (final object in targets) {
      try {
        final count = await pullObject(object);
        pulledByObject[object] = count;
        total += count;
      } catch (e) {
        // 单个对象失败（如目标实例未创建通用表）不阻断全量同步
        await log.write(
          level: SyncLogLevel.warn,
          operation: 'pull',
          target: object,
          detail: '对象拉取失败，已跳过',
          error: e.toString(),
        );
      }
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

  /// 全量同步 = 结构同步 + 数据记录同步
  Future<FullSyncResult> fullSync() async {
    final structure = await CrmStructureSyncService(
      client: client,
    ).syncStructure();
    final data = await fullPull();
    return FullSyncResult(structure: structure, data: data);
  }

  /// 拉取单个对象并 upsert 本地缓存
  Future<int> pullObject(String object) async {
    // 使用本地结构缓存拉取完整可展示字段（不触发 metadata 网络请求）
    final meta = await CrmFieldRegistry.fetchObjectMeta(client, object);
    var fields = meta == null
        ? <String>[]
        : CrmFieldRegistry.defaultDisplayFields(meta)
              .map((f) => f.name)
              .toList();
    if (fields.isEmpty) {
      fields = ['id', labelFieldFor(object)];
    }
    List<TwentyEntity> entities;
    try {
      entities = await client.listAll(object: object, fields: fields);
    } on TwentyApiException catch (e) {
      // 个别字段与 GraphQL 不一致时回退到标签字段，避免整对象拉取失败
      await log.write(
        level: SyncLogLevel.warn,
        operation: 'pull',
        target: object,
        detail: '字段列表拉取失败，回退标签字段',
        error: e.toString(),
      );
      entities = await client.listAll(
        object: object,
        fields: ['id', labelFieldFor(object)],
      );
    }
    final now = DateTime.now();
    final caches = <CrmEntityCache>[];
    for (final entity in entities) {
      final existing = await IsarUtil.getCrmEntityByTwentyId(entity.id);
      final cache = existing ?? CrmEntityCache()..twentyId = entity.id;
      cache
        ..entityType = object
        ..name = _nameOf(entity.data, object, entity.id)
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

  /// 通用创建：任意对象（company/person/opportunity/task/合同/通用记录等）。
  /// 成功后写入本地缓存，保持「本地缓存优先展示」的既有策略。
  Future<TwentyEntity> createEntity(
    String object,
    Map<String, dynamic> data,
  ) async {
    final labelField = labelFieldFor(object);
    final created = await client.create(
      object: object,
      data: data,
      fields: ['id', labelField],
    );
    final now = DateTime.now();
    final cache = CrmEntityCache()
      ..twentyId = created.id
      ..entityType = object
      ..name = _nameOf(created.data, object, created.id)
      ..setData(created.data)
      ..lastSyncedAt = now
      ..updatedAt = now;
    await IsarUtil.upsertCrmEntities([cache]);
    await log.write(
      level: SyncLogLevel.info,
      operation: 'push',
      target: object,
      detail: '创建 ${cache.name}（${created.id}）',
    );
    return created;
  }

  /// 通用更新：推送远端并同步本地缓存。
  Future<TwentyEntity> updateEntity(
    String object,
    String id,
    Map<String, dynamic> data,
  ) async {
    final labelField = labelFieldFor(object);
    final updated = await client.update(
      object: object,
      id: id,
      data: data,
      fields: ['id', labelField],
    );
    final now = DateTime.now();
    final existing = await IsarUtil.getCrmEntityByTwentyId(id);
    final cache =
        existing ?? CrmEntityCache()..twentyId = id;
    cache
      ..entityType = object
      ..name = _nameOf(updated.data, object, id)
      ..setData(updated.data)
      ..isDeleted = false
      ..lastSyncedAt = now
      ..updatedAt = now;
    await IsarUtil.upsertCrmEntities([cache]);
    await log.write(
      level: SyncLogLevel.info,
      operation: 'push',
      target: object,
      detail: '更新 ${cache.name}（$id）',
    );
    return updated;
  }

  /// 通用删除：删除远端并清理本地缓存。
  Future<void> deleteEntity(String object, String id) async {
    await client.delete(object: object, id: id);
    await IsarUtil.removeCrmEntityByTwentyId(id);
    await log.write(
      level: SyncLogLevel.info,
      operation: 'push',
      target: object,
      detail: '删除 $id',
    );
  }

  /// 对象标签字段（Twenty 对象的 label identifier）。
  static String labelFieldFor(String object) {
    switch (object) {
      case 'note':
      case 'task':
        return 'title';
      case 'contractsHeTongGuanLi':
        return 'contractName';
      default:
        return 'name';
    }
  }

  /// 从远端快照提取展示名（与 pullObject 保持一致）。
  static String _nameOf(Map<String, dynamic> data, String object, String id) {
    final labelField = labelFieldFor(object);
    return data[labelField]?.toString() ??
        data['name']?.toString() ??
        data['title']?.toString() ??
        data['contractName']?.toString() ??
        data['amount']?.toString() ??
        id;
  }

  /// 本地缓存搜索（跨对象）
  Future<List<CrmEntityCache>> searchLocal(String keyword) {
    return IsarUtil.searchCrmByName(keyword);
  }

  /// 本地缓存统计
  Future<Map<String, int>> localStats() async {
    final stats = <String, int>{};
    for (final object in {
      ...defaultObjects,
      ...customObjects,
      ...genericObjects,
    }) {
      stats[object] = await IsarUtil.countCrmEntitiesByType(object);
    }
    return stats;
  }

  /// 全量对账：对比远端与本地缓存，找出缺失/过期实体（不自动修复）
  Future<ReconcileResult> reconcile({
    Set<String> objects = defaultObjects,
  }) async {
    final missing = <String, List<String>>{};
    final stale = <String, List<String>>{};

    for (final object in objects) {
      final remote = await client.listAll(object: object);
      final remoteIds = remote.map((e) => e.id).toSet();
      final local = await IsarUtil.getCrmEntitiesByType(
        object,
        includeDeleted: true,
      );
      final localIds = local.map((e) => e.twentyId).toSet();

      final missingIds = remoteIds.difference(localIds).toList()..sort();
      final staleIds = localIds.difference(remoteIds).toList()..sort();
      if (missingIds.isNotEmpty) missing[object] = missingIds;
      if (staleIds.isNotEmpty) stale[object] = staleIds;
    }

    final result = ReconcileResult(
      checkedAt: DateTime.now(),
      missingLocal: missing,
      staleLocal: stale,
    );
    await log.write(
      level: result.totalDiff == 0 ? SyncLogLevel.info : SyncLogLevel.warn,
      operation: 'reconcile',
      target: 'crm',
      detail: '对账完成：差异 ${result.totalDiff} 项',
    );
    return result;
  }
}
