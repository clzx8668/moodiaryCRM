import 'package:moodiary/features/crm/crm_field_registry.dart';
import 'package:moodiary/features/crm/twenty_api.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/persistence/pref.dart';

/// 结构同步结果
class StructureSyncResult {
  final DateTime syncedAt;
  final int objects;
  final int fields;
  final int failed;
  final List<String> errors;

  const StructureSyncResult({
    required this.syncedAt,
    this.objects = 0,
    this.fields = 0,
    this.failed = 0,
    this.errors = const [],
  });

  @override
  String toString() =>
      '对象 $objects · 字段 $fields · 失败 $failed';
}

/// 数据结构同步服务（对象/字段元数据）。
///
/// 与数据记录同步（fullPull / 内容推送）分离：
/// - 仅在初始化、结构版本升级或用户手动触发时执行；
/// - 结果持久化（`crmFieldMeta_v2_<对象>` + 版本/时间），
///   之后的数据同步只读缓存，不再访问 metadata API；
/// - 手动入口：设置 → CRM 同步 → 数据结构同步；全量同步 = 结构 + 数据。
class CrmStructureSyncService {
  final TwentyApiClient client;
  final SyncLogService log;

  /// 结构版本：代码层结构规则变化时 +1，触发一次自动结构同步
  static const int structureVersion = 3;

  static const String versionKey = 'crmStructureVersion';
  static const String syncedAtKey = 'crmStructureSyncedAt';

  CrmStructureSyncService({required this.client, SyncLogService? log})
    : log = log ?? SyncLogService.instance;

  /// 同步全部 CRM 对象的结构（对象 + 字段清单）。
  Future<StructureSyncResult> syncStructure({Set<String>? objects}) async {
    final targets = objects ?? CrmFieldRegistry.objectMetaName.keys.toSet();
    var totalObjects = 0;
    var totalFields = 0;
    var failed = 0;
    final errors = <String>[];

    for (final object in targets) {
      try {
        final meta = await CrmFieldRegistry.fetchObjectMeta(
          client,
          object,
          force: true,
        );
        if (meta != null) {
          totalObjects++;
          totalFields += meta.fields.length;
        }
      } catch (e) {
        failed++;
        errors.add('$object: $e');
      }
    }

    final now = DateTime.now();
    final result = StructureSyncResult(
      syncedAt: now,
      objects: totalObjects,
      fields: totalFields,
      failed: failed,
      errors: errors,
    );
    try {
      await PrefUtil.setValue<int>(versionKey, structureVersion);
      await PrefUtil.setValue<String>(
        syncedAtKey,
        now.toIso8601String(),
      );
    } catch (_) {
      // 测试/CLI 环境未初始化 PrefUtil 时忽略
    }
    await log.write(
      level: failed > 0 ? SyncLogLevel.warn : SyncLogLevel.info,
      operation: 'structure',
      target: 'crm',
      detail: '结构同步完成：$result',
    );
    return result;
  }

  /// 是否需要结构同步：结构版本落后，或任一对象缺本地结构缓存。
  static bool needsSync() {
    try {
      final version = PrefUtil.getValue<int>(versionKey) ?? 0;
      if (version < structureVersion) return true;
      for (final key in CrmFieldRegistry.objectMetaName.keys) {
        final cached = PrefUtil.getValue<String>('crmFieldMeta_v2_$key');
        if (cached == null || cached.isEmpty) return true;
      }
      return false;
    } catch (_) {
      // PrefUtil 未初始化（测试/CLI）→ 视为需要同步
      return true;
    }
  }

  /// 按需确保结构已同步（初始化/版本升级时自动执行；已同步则无操作）。
  Future<StructureSyncResult?> ensureSynced() async {
    if (!needsSync()) return null;
    return syncStructure();
  }

  /// 最近一次结构同步时间（未同步返回 null）
  static DateTime? lastSyncedAt() {
    try {
      final raw = PrefUtil.getValue<String>(syncedAtKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }
}
