import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:moodiary/features/block/delta_to_markdown.dart';
import 'package:moodiary/features/block/models/block.dart' as block_model;
import 'package:moodiary/persistence/app_database.dart';

/// 数据库迁移服务（Drift/SQLite 实现，架构文档 3.4）。
///
/// - 版本检测：读取 app_metadata 表中的 db_version；
/// - v1 → v2：将旧版 Diary 内容包装为 text Block；
/// - v2 → v3：Quill Delta 内容统一转换为 Markdown（架构决策 2026-08-19）；
/// - 幂等 + 迁移历史。
class MigrationService {
  static const String dbVersionKey = 'db_version';
  static const String migrationHistoryKey = 'migration_history';

  /// 当前代码期望的数据库版本
  static const int currentDbVersion = 3;

  static Future<String?> _getMeta(AppDatabase db, String key) async {
    final row = await (db.select(db.appMetadata)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  static Future<void> _setMeta(
    AppDatabase db,
    String key,
    String value,
  ) async {
    await db.into(db.appMetadata).insertOnConflictUpdate(
      AppMetadataCompanion.insert(key: key, value: value),
    );
  }

  static Future<int> getDbVersion(AppDatabase db) async {
    final value = await _getMeta(db, dbVersionKey);
    return value == null ? 1 : int.tryParse(value) ?? 1;
  }

  static Future<void> setDbVersion(AppDatabase db, int version) async {
    await _setMeta(db, dbVersionKey, version.toString());
  }

  static Future<List<Map<String, dynamic>>> getMigrationHistory(
    AppDatabase db,
  ) async {
    final value = await _getMeta(db, migrationHistoryKey);
    if (value == null || value.isEmpty) return [];
    return (jsonDecode(value) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> _appendMigrationHistory(
    AppDatabase db,
    Map<String, dynamic> entry,
  ) async {
    final history = await getMigrationHistory(db);
    history.add(entry);
    await _setMeta(db, migrationHistoryKey, jsonEncode(history));
  }

  /// 执行迁移。若当前版本已是最新，返回 [MigrationResult.noop]。
  static Future<MigrationResult> run(AppDatabase db) async {
    final version = await getDbVersion(db);
    if (version >= currentDbVersion) {
      return const MigrationResult(noop: true);
    }
    var migrated = 0;
    var current = version;

    if (current < 2) {
      final stopwatch = Stopwatch()..start();
      final result = await migrateV1ToV2(db);
      stopwatch.stop();
      migrated += result.migratedDiaries;
      current = 2;
      await _appendMigrationHistory(db, {
        'from': version,
        'to': 2,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'migratedDiaries': result.migratedDiaries,
      });
    }

    if (current < 3) {
      final stopwatch = Stopwatch()..start();
      final result = await migrateV2ToV3(db);
      stopwatch.stop();
      migrated += result.migratedDiaries;
      current = 3;
      await _appendMigrationHistory(db, {
        'from': 2,
        'to': 3,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'migratedDiaries': result.migratedDiaries,
      });
    }

    await setDbVersion(db, currentDbVersion);
    return MigrationResult(migratedDiaries: migrated);
  }

  /// v1 → v2：把旧版 content 包装为 text Block
  static Future<MigrationResult> migrateV1ToV2(AppDatabase db) async {
    final diaries = await db.select(db.diaries).get();
    var migrated = 0;

    for (final diary in diaries) {
      final blockCount = (await (db.select(db.blocks)
                ..where((t) => t.diaryId.equals(diary.id)))
              .get())
          .length;
      // 幂等：已存在 Block 的日记跳过
      if (blockCount > 0) continue;

      final content = diary.contentText.trim().isNotEmpty
          ? diary.contentText
          : diary.content;
      final now = DateTime.fromMillisecondsSinceEpoch(
        diary.time.millisecondsSinceEpoch,
      );
      await db.into(db.blocks).insert(
        BlocksCompanion.insert(
          id: block_model.Block().id,
          diaryId: diary.id,
          blockType: block_model.BlockType.text.value,
          content: Value(content),
          sortOrder: const Value(0),
          createdAt: now,
          updatedAt: now,
        ),
      );
      migrated++;
    }

    return MigrationResult(migratedDiaries: migrated);
  }

  /// v2 → v3：Quill Delta 内容统一转换为 Markdown
  static Future<MigrationResult> migrateV2ToV3(AppDatabase db) async {
    final diaries = await db.select(db.diaries).get();
    var migrated = 0;

    for (final row in diaries) {
      if (row.type == 'markdown') continue;
      final newContent = DeltaToMarkdown.convertIfDelta(row.content);
      if (newContent == row.content) continue; // 非 Delta，跳过

      await (db.update(db.diaries)..where((t) => t.id.equals(row.id))).write(
        DiariesCompanion(
          content: Value(newContent),
          type: const Value('markdown'),
        ),
      );

      // 同步更新该日记的第一个 text Block
      final blocks = await (db.select(db.blocks)
            ..where((t) => t.diaryId.equals(row.id)))
          .get();
      final textBlocks = blocks
          .where((b) => b.blockType == block_model.BlockType.text.value && !b.isDeleted)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (textBlocks.isNotEmpty) {
        await (db.update(db.blocks)..where((t) => t.id.equals(textBlocks.first.id)))
            .write(
          BlocksCompanion(
            content: Value(newContent),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
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
