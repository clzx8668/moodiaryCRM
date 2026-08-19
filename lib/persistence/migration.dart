import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:moodiary/features/block/models/app_metadata.dart' as meta;
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/common/models/isar/diary.dart';

/// 数据库迁移服务（对齐架构文档 3.4）。
///
/// - 版本检测：读取 app_metadata 表中的 db_version；
/// - v1 → v2：将旧版 Diary.content/contentText 包装为 text 类型 Block 写入 Block 表；
/// - 幂等：已存在 Block 的日记跳过；
/// - 迁移日志：每次迁移在 app_metadata 中追加 migration_history 条目。
class MigrationService {
  static const String dbVersionKey = 'db_version';
  static const String migrationHistoryKey = 'migration_history';

  /// 当前代码期望的数据库版本
  static const int currentDbVersion = 2;

  static Future<int> getDbVersion(Isar isar) async {
    final metadata = isar.appMetadatas.get(meta.fastHash(dbVersionKey));
    return metadata == null ? 1 : int.tryParse(metadata.value) ?? 1;
  }

  static Future<void> setDbVersion(Isar isar, int version) async {
    await isar.writeAsync((isar) {
      isar.appMetadatas.put(
        meta.AppMetadata(key: dbVersionKey, value: version.toString()),
      );
    });
  }

  static Future<List<Map<String, dynamic>>> getMigrationHistory(
    Isar isar,
  ) async {
    final metadata = isar.appMetadatas.get(
      meta.fastHash(migrationHistoryKey),
    );
    if (metadata == null || metadata.value.isEmpty) return [];
    return (jsonDecode(metadata.value) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> _appendMigrationHistory(
    Isar isar,
    Map<String, dynamic> entry,
  ) async {
    final history = await getMigrationHistory(isar);
    history.add(entry);
    await isar.writeAsync((isar) {
      isar.appMetadatas.put(
        meta.AppMetadata(
          key: migrationHistoryKey,
          value: jsonEncode(history),
        ),
      );
    });
  }

  /// 执行迁移。若当前版本已是最新，返回 [MigrationResult.noop]。
  static Future<MigrationResult> run(Isar isar) async {
    final version = await getDbVersion(isar);
    if (version >= currentDbVersion) {
      return const MigrationResult(noop: true);
    }
    final stopwatch = Stopwatch()..start();

    if (version < 2) {
      final result = await migrateV1ToV2(isar);
      stopwatch.stop();
      await _appendMigrationHistory(isar, {
        'from': version,
        'to': currentDbVersion,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'migratedDiaries': result.migratedDiaries,
      });
      await setDbVersion(isar, currentDbVersion);
      return result;
    }

    await setDbVersion(isar, currentDbVersion);
    return const MigrationResult();
  }

  /// v1 → v2：把旧版 content 包装为 text Block。
  static Future<MigrationResult> migrateV1ToV2(Isar isar) async {
    final diaries = await isar.diarys.where().findAllAsync();
    var migrated = 0;

    for (final diary in diaries) {
      final blockCount = await isar.blocks
          .where()
          .diaryIdEqualTo(diary.id)
          .countAsync();
      // 幂等：已存在 Block 的日记跳过
      if (blockCount > 0) continue;

      final content =
          diary.contentText.trim().isNotEmpty ? diary.contentText : diary.content;
      final now = DateTime.fromMillisecondsSinceEpoch(
        diary.time.millisecondsSinceEpoch,
      );
      final block = Block()
        ..diaryId = diary.id
        ..blockType = BlockType.text
        ..content = content
        ..sortOrder = 0
        ..createdAt = now
        ..updatedAt = now;

      await isar.writeAsync((isar) {
        isar.blocks.put(block);
      });
      migrated++;
    }

    return MigrationResult(migratedDiaries: migrated);
  }
}

class MigrationResult {
  final bool noop;
  final int migratedDiaries;

  const MigrationResult({this.noop = false, this.migratedDiaries = 0});

  @override
  String toString() =>
      'MigrationResult(noop: $noop, migratedDiaries: $migratedDiaries)';
}
