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
  static const int currentDbVersion = 14;

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

    if (current < 4) {
      final stopwatch = Stopwatch()..start();
      final migrated = await migrateV3ToV4(db);
      stopwatch.stop();
      current = 4;
      await _appendMigrationHistory(db, {
        'from': 3,
        'to': 4,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'migratedBlocks': migrated,
      });
    }

    if (current < 5) {
      // v4 → v5：新增知识库/向量表由 Drift schema 迁移处理，此处仅推进版本号
      final stopwatch = Stopwatch()..start();
      current = 5;
      await _appendMigrationHistory(db, {
        'from': 4,
        'to': 5,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'knowledge_bases + block_embeddings 表',
      });
    }

    if (current < 6) {
      // v5 → v6：AI 会话/消息表由 Drift schema 迁移处理
      final stopwatch = Stopwatch()..start();
      current = 6;
      await _appendMigrationHistory(db, {
        'from': 5,
        'to': 6,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'ai_chat_sessions + ai_chat_messages 表',
      });
    }

    if (current < 7) {
      // v6 → v7：内容同步映射表由 Drift schema 迁移处理
      final stopwatch = Stopwatch()..start();
      current = 7;
      await _appendMigrationHistory(db, {
        'from': 6,
        'to': 7,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'crm_content_links 表（笔记/待办 ↔ Twenty 对象映射）',
      });
    }

    if (current < 8) {
      // v7 → v8：本地优先 CRM 表（基础对象 + 自定义对象引擎 + 实体关联）
      final stopwatch = Stopwatch()..start();
      current = 8;
      await _appendMigrationHistory(db, {
        'from': 7,
        'to': 8,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'crm_companies/people/opportunities/contracts + object_defs/custom_records/entity_links',
      });
    }

    if (current < 9) {
      // v8 → v9：Account 统一客户模型（R1 决策）；机会/合同按 19 表设计文档重建
      final stopwatch = Stopwatch()..start();
      current = 9;
      await _appendMigrationHistory(db, {
        'from': 8,
        'to': 9,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'Account 统一模型：crm_accounts + crm_contacts；机会/合同重建',
      });
    }

    if (current < 10) {
      // v9 → v10：产品/分类、报价单/明细、合同明细
      final stopwatch = Stopwatch()..start();
      current = 10;
      await _appendMigrationHistory(db, {
        'from': 9,
        'to': 10,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'crm_product_categories/products + quotes/quote_items + contract_items',
      });
    }

    if (current < 11) {
      // v10 → v11：回款计划/回款记录/发票
      final stopwatch = Stopwatch()..start();
      current = 11;
      await _appendMigrationHistory(db, {
        'from': 10,
        'to': 11,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'crm_payment_plans + crm_payments + crm_invoices',
      });
    }

    if (current < 12) {
      // v11 → v12：质保 + 售后工单
      final stopwatch = Stopwatch()..start();
      current = 12;
      await _appendMigrationHistory(db, {
        'from': 11,
        'to': 12,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'crm_warranties + crm_after_sales',
      });
    }

    if (current < 13) {
      // v12 → v13：跟进记录 + 标签 + 实体标签
      final stopwatch = Stopwatch()..start();
      current = 13;
      await _appendMigrationHistory(db, {
        'from': 12,
        'to': 13,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'crm_activities + crm_tags + crm_entity_tags',
      });
    }

    if (current < 14) {
      // v13 → v14：附件 + 提醒
      final stopwatch = Stopwatch()..start();
      current = 14;
      await _appendMigrationHistory(db, {
        'from': 13,
        'to': 14,
        'time': DateTime.now().toIso8601String(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'note': 'crm_attachments + crm_reminders',
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

  /// v3 → v4：为历史 Block 回填 metaJson（source=initial）。
  ///
  /// 迁移前创建的 Block（v1→v2 包装的原始内容、快速收集生成的 text Block）
  /// 语义上都是"原始记录卡"，统一标记为 initial；已带 meta 的 Block 跳过。
  /// 幂等：版本门禁保证只执行一次，此处仍按"空 meta 才回填"做二次保护。
  static Future<int> migrateV3ToV4(AppDatabase db) async {
    final blocks = await db.select(db.blocks).get();
    var migrated = 0;

    for (final row in blocks) {
      final raw = row.metaJson.trim();
      final isEmpty = raw.isEmpty || raw == '{}';
      if (!isEmpty) continue;
      await (db.update(db.blocks)..where((t) => t.id.equals(row.id))).write(
        BlocksCompanion(
          metaJson: const Value('{"source":"initial"}'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      migrated++;
    }

    return migrated;
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
