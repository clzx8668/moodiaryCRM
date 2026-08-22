import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/models/isar/font.dart' hide fastHash;
import 'package:moodiary/common/models/isar/sync_record.dart' hide fastHash;
import 'package:moodiary/common/models/map.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/features/block/models/block.dart' as block_model;
import 'package:moodiary/features/block/markdown_projection.dart';
import 'package:moodiary/features/ai/models/ai_chat_session.dart'
    as chat_model;
import 'package:moodiary/features/crm/models/crm_entity_cache.dart'
    as crm_model;
import 'package:moodiary/features/crm/models/crm_content_link.dart'
    as link_model;
import 'package:moodiary/features/rag/models/block_embedding.dart'
    as rag_model;
import 'package:moodiary/features/rag/models/knowledge_base.dart'
    as kb_model;
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/migration.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/src/rust/api/jieba.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/webdav_util.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 数据访问层（Drift/SQLite 实现）。
///
/// 保持原 IsarUtil 的全部公开接口，内部由 Isar 切换为 Drift，
/// 业务调用方无需改动（架构决策 2026-08-20：Isar → Drift）。
class IsarUtil {
  static AppDatabase? _db;

  /// 测试接缝：可注入内存数据库
  static AppDatabase? _testDb;

  static AppDatabase get _database => _testDb ?? _db!;

  @visibleForTesting
  static void overrideDbForTest(AppDatabase db) {
    _testDb = db;
  }

  @visibleForTesting
  static void restoreDbForTest() {
    _testDb = null;
  }

  static Future<void> initIsar() async {
    _db = await AppDatabase.open();
    // 启动时自动执行数据迁移（v1 → v2 → v3）
    await MigrationService.run(_database);
    await _refreshCaches();
  }

  // 同步查询用的内存缓存（Drift 无同步 API，仅用于少量同步调用点）
  static List<Category> _categoryCache = [];
  static int _diaryCountCache = 0;

  static Future<void> _refreshCaches() async {
    _categoryCache = await getAllCategoryAsync();
    _diaryCountCache = (await getAllDiaries()).length;
  }

  static Future<void> _refreshCategoryCache() async {
    _categoryCache = await getAllCategoryAsync();
  }

  static Future<void> _refreshDiaryCount() async {
    _diaryCountCache = (await getAllDiaries()).length;
  }

  // ==================== 行 ↔ 模型映射 ====================

  static DiariesCompanion _diaryCompanion(Diary d) {
    return DiariesCompanion.insert(
      id: d.id,
      categoryId: Value(d.categoryId),
      title: Value(d.title),
      content: Value(d.content),
      contentText: Value(d.contentText),
      yM: Value(d.yM),
      yMd: Value(d.yMd),
      time: d.time,
      lastModified: d.lastModified,
      show: Value(d.show),
      mood: Value(d.mood),
      weather: Value(d.weather),
      imageName: Value(d.imageName),
      audioName: Value(d.audioName),
      videoName: Value(d.videoName),
      tags: Value(d.tags),
      position: Value(d.position),
      keywords: Value(d.keywords),
      tokenizer: Value(d.tokenizer),
      type: Value(d.type),
      imageColor: Value(d.imageColor),
      aspect: Value(d.aspect),
    );
  }

  static Diary _diaryFromRow(DiaryRow row) {
    return Diary()
      ..id = row.id
      ..categoryId = row.categoryId
      ..title = row.title
      ..content = row.content
      ..contentText = row.contentText
      ..time = row.time
      ..lastModified = row.lastModified
      ..show = row.show
      ..mood = row.mood
      ..weather = row.weather
      ..imageName = row.imageName
      ..audioName = row.audioName
      ..videoName = row.videoName
      ..tags = row.tags
      ..position = row.position
      ..keywords = row.keywords
      ..tokenizer = row.tokenizer
      ..type = row.type
      ..imageColor = row.imageColor
      ..aspect = row.aspect;
  }

  static CategoriesCompanion _categoryCompanion(Category c) {
    return CategoriesCompanion.insert(
      id: c.id,
      categoryName: c.categoryName,
      parentId: Value(c.parentId),
    );
  }

  static Category _categoryFromRow(CategoryRow row) {
    return Category()
      ..id = row.id
      ..categoryName = row.categoryName
      ..parentId = row.parentId;
  }

  static FontsCompanion _fontCompanion(Font f) {
    return FontsCompanion.insert(
      fontFileName: f.fontFileName,
      fontWghtAxisMap: Value(f.fontWghtAxisMap),
    );
  }

  static Font _fontFromRow(FontRow row) {
    return Font(fontFileName: row.fontFileName, fontWghtAxisMap: row.fontWghtAxisMap);
  }

  static BlocksCompanion _blockCompanion(block_model.Block b) {
    return BlocksCompanion.insert(
      id: b.id,
      diaryId: b.diaryId,
      blockType: b.blockType.value,
      content: Value(b.content),
      sortOrder: Value(b.sortOrder),
      isDeleted: Value(b.isDeleted),
      streamBuffer: Value(b.streamBuffer),
      streamComplete: Value(b.streamComplete),
      metaJson: Value(b.metaJson),
      createdAt: b.createdAt,
      updatedAt: b.updatedAt,
    );
  }

  static block_model.Block _blockFromRow(BlockRow row) {
    return block_model.Block()
      ..id = row.id
      ..diaryId = row.diaryId
      ..blockType = block_model.BlockType.fromValue(row.blockType)
      ..content = row.content
      ..sortOrder = row.sortOrder
      ..isDeleted = row.isDeleted
      ..streamBuffer = row.streamBuffer
      ..streamComplete = row.streamComplete
      ..metaJson = row.metaJson
      ..createdAt = row.createdAt
      ..updatedAt = row.updatedAt;
  }

  static CrmEntityCachesCompanion _crmCompanion(crm_model.CrmEntityCache c) {
    return CrmEntityCachesCompanion.insert(
      id: c.id,
      twentyId: c.twentyId,
      entityType: c.entityType,
      name: Value(c.name),
      dataJson: Value(c.dataJson),
      isDeleted: Value(c.isDeleted),
      localVersion: Value(c.localVersion),
      lastSyncedAt: c.lastSyncedAt,
      updatedAt: c.updatedAt,
    );
  }

  static crm_model.CrmEntityCache _crmFromRow(CrmEntityCacheRow row) {
    return crm_model.CrmEntityCache()
      ..id = row.id
      ..twentyId = row.twentyId
      ..entityType = row.entityType
      ..name = row.name
      ..dataJson = row.dataJson
      ..isDeleted = row.isDeleted
      ..localVersion = row.localVersion
      ..lastSyncedAt = row.lastSyncedAt
      ..updatedAt = row.updatedAt;
  }

  static SyncRecordsCompanion _syncCompanion(SyncRecord r) {
    return SyncRecordsCompanion.insert(
      syncId: r.syncId,
      diaryId: r.diaryId,
      diaryJson: r.diaryJson,
      time: r.time,
      syncType: r.syncType.index,
    );
  }

  static SyncRecord _syncFromRow(SyncRecordRow row) {
    return SyncRecord()
      ..syncId = row.syncId
      ..diaryId = row.diaryId
      ..diaryJson = row.diaryJson
      ..time = row.time
      ..syncType = SyncType.values[row.syncType];
  }

  static KnowledgeBasesCompanion _kbCompanion(kb_model.KnowledgeBase kb) {
    return KnowledgeBasesCompanion.insert(
      id: kb.id,
      name: kb.name,
      description: Value(kb.description),
      createdAt: kb.createdAt,
      updatedAt: kb.updatedAt,
    );
  }

  static kb_model.KnowledgeBase _kbFromRow(KnowledgeBaseRow row) {
    return kb_model.KnowledgeBase()
      ..id = row.id
      ..name = row.name
      ..description = row.description
      ..createdAt = row.createdAt
      ..updatedAt = row.updatedAt;
  }

  static BlockEmbeddingsCompanion _embeddingCompanion(
    rag_model.BlockEmbedding e,
  ) {
    return BlockEmbeddingsCompanion.insert(
      blockId: e.blockId,
      diaryId: e.diaryId,
      knowledgeBaseId: e.knowledgeBaseId,
      textContent: e.text,
      embedding: e.encode(),
      dimension: e.dimension,
      updatedAt: e.updatedAt,
    );
  }

  static rag_model.BlockEmbedding _embeddingFromRow(BlockEmbeddingRow row) {
    return rag_model.BlockEmbedding()
      ..blockId = row.blockId
      ..diaryId = row.diaryId
      ..knowledgeBaseId = row.knowledgeBaseId
      ..text = row.textContent
      ..embedding = rag_model.BlockEmbedding.decode(row.embedding, row.dimension)
      ..updatedAt = row.updatedAt;
  }

  static AiChatSessionsCompanion _chatSessionCompanion(
    chat_model.AiChatSession s,
  ) {
    return AiChatSessionsCompanion.insert(
      id: s.id,
      title: Value(s.title),
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  static chat_model.AiChatSession _chatSessionFromRow(AiChatSessionRow row) {
    return chat_model.AiChatSession()
      ..id = row.id
      ..title = row.title
      ..createdAt = row.createdAt
      ..updatedAt = row.updatedAt;
  }

  static AiChatMessagesCompanion _chatMessageCompanion(
    chat_model.AiChatMessageRecord m,
  ) {
    return AiChatMessagesCompanion.insert(
      id: m.id,
      sessionId: m.sessionId,
      role: m.role,
      content: m.content,
      sourcesJson: Value(m.sourcesJson),
      createdAt: m.createdAt,
    );
  }

  static chat_model.AiChatMessageRecord _chatMessageFromRow(
    AiChatMessageRow row,
  ) {
    final record = chat_model.AiChatMessageRecord()
      ..id = row.id
      ..sessionId = row.sessionId
      ..role = row.role
      ..content = row.content
      ..createdAt = row.createdAt;
    record.setSourcesJson(row.sourcesJson);
    return record;
  }

  // ==================== 基础操作 ====================

  /// 旧 Isar 数据文件迁移不再适用（Drift 全新库），保留签名以兼容调用方
  static Future<void> dataMigration(String path) async {}

  //清空数据
  static Future<void> clearIsar() async {
    final db = _database;
    await db.transaction(() async {
      await db.delete(db.diaries).go();
      await db.delete(db.categories).go();
      await db.delete(db.blocks).go();
      await db.delete(db.crmEntityCaches).go();
      await db.delete(db.fonts).go();
      await db.delete(db.appMetadata).go();
      await db.delete(db.syncRecords).go();
    });
  }

  static Future<Map<String, dynamic>> getSize() async {
    final db = _database;
    final pageCount = (await db.customSelect('PRAGMA page_count').get()).first
        .data['page_count'] as int? ?? 0;
    final pageSize = (await db.customSelect('PRAGMA page_size').get()).first
        .data['page_size'] as int? ?? 4096;
    return FileUtil.bytesToUnits(pageCount * pageSize);
  }

  /// 导出数据库文件（SQLite VACUUM INTO）
  static Future<void> exportIsar(
    String dir,
    String path,
    String fileName,
  ) async {
    final target = p.join(path, fileName);
    final safe = target.replaceAll("'", "''");
    await _database.customStatement("VACUUM INTO '$safe'");
  }

  // ==================== Diary ====================

  static Future<void> insertADiary(Diary diary) async {
    diary.lastModified = DateTime.now();
    await _database.into(_database.diaries).insertOnConflictUpdate(
      _diaryCompanion(diary),
    );
    await _refreshDiaryCount();
  }

  static Future<List<Diary>> getDiaryByMonth(int year, int month) async {
    final rows = await (_database.select(_database.diaries)
          ..where(
            (t) => t.show.equals(true) & t.yM.equals('$year/$month'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
    return rows.map(_diaryFromRow).toList();
  }

  /// 按历史 isarId（业务主键哈希）查找日记
  static Future<Diary?> getDiaryByID(int isarId) async {
    final rows = await _database.select(_database.diaries).get();
    for (final row in rows) {
      if (fastHash(row.id) == isarId) return _diaryFromRow(row);
    }
    return null;
  }

  /// 按业务主键（UUID）查找日记（SmartCanvasPage 等按 id 聚合的场景）
  static Future<Diary?> getDiaryById(String id) async {
    final row = await (_database.select(_database.diaries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _diaryFromRow(row);
  }

  static Future<List<Diary>> getDiariesByDateRange(
    DateTime start,
    DateTime end, {
    bool all = true,
  }) async {
    final rows = await (_database.select(_database.diaries)
          ..where(
            (t) =>
                t.time.isBetweenValues(start, end) &
                t.show.equals(all),
          ))
        .get();
    return rows.map(_diaryFromRow).toList();
  }

  static Future<List<Diary>> getAllDiaries() async {
    final rows = await _database.select(_database.diaries).get();
    return rows.map(_diaryFromRow).toList();
  }

  static Future<List<Diary>> getAllDiariesSorted() async {
    final rows = await (_database.select(_database.diaries)
          ..where((t) => t.show.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
    return rows.map(_diaryFromRow).toList();
  }

  static Future<List<List<String>>> getWeatherByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await (_database.select(_database.diaries)
          ..where(
            (t) =>
                t.show.equals(true) &
                t.time.isBetweenValues(start, end),
          ))
        .get();
    final seen = <String>{};
    return rows
        .where((r) => seen.add(r.yMd))
        .map((r) => r.weather)
        .toList();
  }

  static Future<List<double>> getMoodByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await (_database.select(_database.diaries)
          ..where(
            (t) =>
                t.show.equals(true) &
                t.time.isBetweenValues(start, end),
          ))
        .get();
    final seen = <String>{};
    return rows.where((r) => seen.add(r.yMd)).map((r) => r.mood).toList();
  }

  /// 按历史 isarId 删除
  static Future<bool> deleteADiary(int isarId) async {
    final diary = await getDiaryByID(isarId);
    if (diary == null) return false;
    final count = await (_database.delete(_database.diaries)
          ..where((t) => t.id.equals(diary.id)))
        .go();
    await _refreshDiaryCount();
    return count > 0;
  }

  static Future<List<Diary>> getRecycleBinDiaries() async {
    final rows = await (_database.select(_database.diaries)
          ..where((t) => t.show.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
    return rows.map(_diaryFromRow).toList();
  }

  static Future<void> updateADiary({
    Diary? oldDiary,
    required Diary newDiary,
  }) async {
    newDiary.lastModified = DateTime.now();
    await _database.into(_database.diaries).insertOnConflictUpdate(
      _diaryCompanion(newDiary),
    );
    await _refreshDiaryCount();
    if (oldDiary != null) {
      await FileUtil.cleanUpOldMediaFiles(oldDiary, newDiary);
      if (WebDavUtil().hasOption &&
          PrefUtil.getValue<bool>('autoSyncAfterChange') == true) {
        unawaited(
          WebDavUtil().updateSingleDiary(
            oldDiary: oldDiary,
            newDiary: newDiary,
          ),
        );
      }
    } else {
      if (WebDavUtil().hasOption &&
          PrefUtil.getValue<bool>('autoSyncAfterChange') == true) {
        unawaited(WebDavUtil().uploadSingleDiary(newDiary));
      }
    }
  }

  static Future<List<Diary>> searchDiaries({
    required List<String> queryList,
  }) async {
    if (queryList.isEmpty) return [];
    final results = <Diary>[];
    for (final word in queryList) {
      final rows = await (_database.select(_database.diaries)
            ..where(
              (t) =>
                  t.show.equals(true) &
                  (t.title.contains(word) |
                      t.contentText.contains(word) |
                      t.tokenizer.contains(word)),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.time)]))
          .get();
      results.addAll(rows.map(_diaryFromRow));
    }
    final unique = <String, Diary>{};
    for (final d in results) {
      unique[d.id] = d;
    }
    return unique.values.toList()
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  static Future<List<Diary>> searchDiariesByText(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    final rows = await (_database.select(_database.diaries)
          ..where(
            (t) =>
                t.show.equals(true) &
                t.contentText.contains(keyword.trim()),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
    return rows.map(_diaryFromRow).toList();
  }

  static Future<List<Diary>> searchDiariesByTag(String value) async {
    final rows = await (_database.select(_database.diaries)
          ..where(
            (t) => t.show.equals(true) & t.tags.contains(value),
          ))
        .get();
    return rows.map(_diaryFromRow).toList();
  }

  static Future<int> countShowDiary() async {
    return (await (_database.select(_database.diaries)
              ..where((t) => t.show.equals(true)))
            .get())
        .length;
  }

  static int countAllDiary() {
    return _diaryCountCache;
  }

  // ==================== Category ====================

  static int countCategories() {
    return _categoryCache.length;
  }

  static Category? getCategoryName(String id) {
    for (final category in _categoryCache) {
      if (category.id == id) return category;
    }
    return null;
  }

  static Future<bool> insertACategory(Category category) async {
    final existing = await (_database.select(_database.categories)
          ..where((t) => t.categoryName.equals(category.categoryName)))
        .getSingleOrNull();
    if (existing != null && existing.id != category.id) {
      category.categoryName =
          '${category.categoryName}_${category.id.substring(0, 4)}';
    }
    category.id = const Uuid().v7();
    await _database.into(_database.categories).insertOnConflictUpdate(
      _categoryCompanion(category),
    );
    await _refreshCategoryCache();
    return existing == null;
  }

  static Future<bool> updateACategory(Category category) async {
    final existing = await (_database.select(_database.categories)
          ..where((t) => t.categoryName.equals(category.categoryName)))
        .getSingleOrNull();
    if (existing != null && existing.id != category.id) {
      category.categoryName =
          '${category.categoryName}_${category.id.substring(0, 4)}';
    }
    await _database.into(_database.categories).insertOnConflictUpdate(
      _categoryCompanion(category),
    );
    await _refreshCategoryCache();
    return existing == null;
  }

  static Future<bool> deleteACategory(String id) async {
    final used = await (_database.select(_database.diaries)
          ..where((t) => t.categoryId.equals(id)))
        .get();
    if (used.isNotEmpty) return false;
    final count = await (_database.delete(_database.categories)
          ..where((t) => t.id.equals(id)))
        .go();
    await _refreshCategoryCache();
    return count > 0;
  }

  static Future<List<String>> getContentList() async {
    final rows = await (_database.select(_database.diaries)
          ..where((t) => t.show.equals(true)))
        .get();
    return rows.map((r) => r.contentText).toList();
  }

  static List<Category> getAllCategory() {
    return List.unmodifiable(_categoryCache);
  }

  static Future<List<Category>> getAllCategoryAsync() async {
    final rows = await _database.select(_database.categories).get();
    return rows.map(_categoryFromRow).toList();
  }

  static Future<List<Diary>> getDiaryByCategory(
    String? categoryId,
    int offset,
    int limit,
  ) async {
    final query = _database.select(_database.diaries)
      ..where(
        (t) =>
            t.show.equals(true) &
            (categoryId == null
                ? const Constant(true)
                : t.categoryId.equals(categoryId)),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.time)])
      ..limit(limit, offset: offset);
    final rows = await query.get();
    return rows.map(_diaryFromRow).toList();
  }

  static Future<List<Diary>> getDiaryByDay(DateTime time) async {
    final rows = await (_database.select(_database.diaries)
          ..where(
            (t) =>
                t.show.equals(true) &
                t.yMd.equals(
                  '${time.year}/${time.month}/${time.day}',
                ),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
    return rows.map(_diaryFromRow).toList();
  }

  static Future<List<Diary>> getDiary(int offset, int limit) async {
    final rows = await (_database.select(_database.diaries)
          ..orderBy([(t) => OrderingTerm.desc(t.time)])
          ..limit(limit, offset: offset))
        .get();
    return rows.map(_diaryFromRow).toList();
  }

  // ==================== 旧版迁移（Drift 下为兼容保留） ====================

  static void mergeToV2_4_8(String dir) {
    // Drift schema 已是最新结构，无需迁移
  }

  static Future<void> mergeToV2_7_4(String dir) async {
    final diaries = await getAllDiaries();
    for (final diary in diaries) {
      final newContent = diary.contentText.removeLineBreaks();
      diary.tokenizer = await JiebaRs.cutAll(text: newContent);
      final keywords = await JiebaRs.extractKeywordsTfidf(
        text: newContent,
        topK: BigInt.from(5),
        allowedPos: [],
      );
      final sortByWeight =
          keywords..sort((a, b) => b.weight.compareTo(a.weight));
      diary.keywords = sortByWeight.map((e) => e.keyword).toList();
      diary.contentText = newContent;
      await _database.into(_database.diaries).insertOnConflictUpdate(
        _diaryCompanion(diary),
      );
    }
  }

  static Future<void> fixV2_6_3(String dir) async {
    final diaries = await _database.select(_database.diaries).get();
    final categories = await _database.select(_database.categories).get();
    final categoryIds = categories.map((c) => c.id).toSet();
    for (final diary in diaries) {
      final id = diary.categoryId;
      if (id != null && !categoryIds.contains(id)) {
        await _database.into(_database.categories).insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: id,
            categoryName: '已修复${id.substring(0, 4)}',
          ),
        );
      }
    }
    await _refreshCategoryCache();
  }

  static Future<List<DiaryMapItem>> getAllMapItem() async {
    final rows = await (_database.select(_database.diaries)
          ..where((t) => t.show.equals(true)))
        .get();
    final items = <DiaryMapItem>[];
    for (final row in rows) {
      if (row.position.isEmpty) continue;
      items.add(
        DiaryMapItem(
          LatLng(
            double.parse(row.position[0]),
            double.parse(row.position[1]),
          ),
          fastHash(row.id),
          row.imageName.isEmpty ? '' : row.imageName.first,
        ),
      );
    }
    return items;
  }

  // ==================== SyncRecord ====================

  static Future<void> addSyncRecord(SyncRecord record) async {
    await _database.into(_database.syncRecords).insertOnConflictUpdate(
      _syncCompanion(record),
    );
  }

  static Future<List<SyncRecord>> getSyncRecords() async {
    final rows = await _database.select(_database.syncRecords).get();
    return rows.map(_syncFromRow).toList();
  }

  // ==================== 知识库（P3.2） ====================

  static Future<void> upsertKnowledgeBase(kb_model.KnowledgeBase kb) async {
    kb.updatedAt = DateTime.now();
    await _database.into(_database.knowledgeBases).insertOnConflictUpdate(
      _kbCompanion(kb),
    );
  }

  static Future<List<kb_model.KnowledgeBase>> getAllKnowledgeBases() async {
    final rows = await (_database.select(_database.knowledgeBases)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_kbFromRow).toList();
  }

  static Future<kb_model.KnowledgeBase?> getKnowledgeBaseById(String id) async {
    final row = await (_database.select(_database.knowledgeBases)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _kbFromRow(row);
  }

  static Future<void> deleteKnowledgeBase(String id) async {
    await _database.transaction(() async {
      await (_database.delete(_database.knowledgeBases)
            ..where((t) => t.id.equals(id)))
          .go();
      await (_database.delete(_database.blockEmbeddings)
            ..where((t) => t.knowledgeBaseId.equals(id)))
          .go();
    });
  }

  static Future<int> countEmbeddingsByKnowledgeBase(String kbId) async {
    return (await (_database.select(_database.blockEmbeddings)
              ..where((t) => t.knowledgeBaseId.equals(kbId)))
            .get())
        .length;
  }

  // ==================== 块向量（P3.3） ====================

  static Future<void> upsertBlockEmbedding(rag_model.BlockEmbedding e) async {
    e.updatedAt = DateTime.now();
    await _database.into(_database.blockEmbeddings).insertOnConflictUpdate(
      _embeddingCompanion(e),
    );
  }

  static Future<void> deleteBlockEmbeddings(String blockId) async {
    await (_database.delete(_database.blockEmbeddings)
          ..where((t) => t.blockId.equals(blockId)))
        .go();
  }

  static Future<void> deleteBlockEmbedding(
    String blockId,
    String knowledgeBaseId,
  ) async {
    await (_database.delete(_database.blockEmbeddings)
          ..where(
            (t) =>
                t.blockId.equals(blockId) &
                t.knowledgeBaseId.equals(knowledgeBaseId),
          ))
        .go();
  }

  static Future<List<rag_model.BlockEmbedding>> getEmbeddingsByKnowledgeBase(
    String kbId,
  ) async {
    final rows = await (_database.select(_database.blockEmbeddings)
          ..where((t) => t.knowledgeBaseId.equals(kbId)))
        .get();
    return rows.map(_embeddingFromRow).toList();
  }

  static Future<List<rag_model.BlockEmbedding>> getAllBlockEmbeddings() async {
    final rows = await _database.select(_database.blockEmbeddings).get();
    return rows.map(_embeddingFromRow).toList();
  }

  static Future<rag_model.BlockEmbedding?> getEmbeddingByBlockAndKb(
    String blockId,
    String kbId,
  ) async {
    final row = await (_database.select(_database.blockEmbeddings)
          ..where(
            (t) =>
                t.blockId.equals(blockId) &
                t.knowledgeBaseId.equals(kbId),
          ))
        .getSingleOrNull();
    return row == null ? null : _embeddingFromRow(row);
  }

  // ==================== AI 对话会话（历史话题） ====================

  static Future<void> upsertChatSession(chat_model.AiChatSession session) async {
    session.updatedAt = DateTime.now();
    await _database.into(_database.aiChatSessions).insertOnConflictUpdate(
      _chatSessionCompanion(session),
    );
  }

  static Future<List<chat_model.AiChatSession>> getAllChatSessions() async {
    final rows = await (_database.select(_database.aiChatSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_chatSessionFromRow).toList();
  }

  static Future<void> deleteChatSession(String id) async {
    await _database.transaction(() async {
      await (_database.delete(_database.aiChatSessions)
            ..where((t) => t.id.equals(id)))
          .go();
      await (_database.delete(_database.aiChatMessages)
            ..where((t) => t.sessionId.equals(id)))
          .go();
    });
  }

  static Future<void> insertChatMessage(
    chat_model.AiChatMessageRecord message,
  ) async {
    await _database.into(_database.aiChatMessages).insertOnConflictUpdate(
      _chatMessageCompanion(message),
    );
  }

  static Future<List<chat_model.AiChatMessageRecord>> getChatMessages(
    String sessionId,
  ) async {
    final rows = await (_database.select(_database.aiChatMessages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_chatMessageFromRow).toList();
  }

  static Future<void> deleteSyncRecord(int id) async {
    final rows = await _database.select(_database.syncRecords).get();
    for (final row in rows) {
      if (fastHash(row.syncId) == id) {
        await (_database.delete(_database.syncRecords)
              ..where((t) => t.syncId.equals(row.syncId)))
            .go();
        return;
      }
    }
  }

  // ==================== Font ====================

  static Future<List<Font>> getAllFonts() async {
    final rows = await _database.select(_database.fonts).get();
    return rows.map(_fontFromRow).toList();
  }

  static Future<void> mergeToV2_7_3(Map<String, dynamic> parma) async {
    final fonts = (parma['fonts'] as List).cast<Font>();
    await _database.transaction(() async {
      await _database.delete(_database.fonts).go();
      for (final font in fonts) {
        await _database.into(_database.fonts).insert(
          _fontCompanion(font),
        );
      }
    });
  }

  static Future<void> insertAFont(Font font) async {
    await _database.into(_database.fonts).insertOnConflictUpdate(
      _fontCompanion(font),
    );
  }

  static Future<Font?> getFontByFontFamily(String fontFamily) async {
    final row = await (_database.select(_database.fonts)
          ..where((t) => t.fontFileName.equals('$fontFamily.ttf')))
        .getSingleOrNull();
    return row == null ? null : _fontFromRow(row);
  }

  static Future<bool> deleteFont(int id) async {
    final rows = await _database.select(_database.fonts).get();
    for (final row in rows) {
      if (fastHash(row.fontFileName) == id) {
        final count = await (_database.delete(_database.fonts)
              ..where((t) => t.fontFileName.equals(row.fontFileName)))
            .go();
        return count > 0;
      }
    }
    return false;
  }

  // ==================== Block CRUD ====================

  static Future<void> insertBlock(block_model.Block block) async {
    block.updatedAt = DateTime.now();
    await _database.into(_database.blocks).insertOnConflictUpdate(
      _blockCompanion(block),
    );
  }

  static Future<void> insertBlocks(List<block_model.Block> blocks) async {
    final now = DateTime.now();
    for (final block in blocks) {
      block.updatedAt = now;
    }
    await _database.transaction(() async {
      for (final block in blocks) {
        await _database.into(_database.blocks).insertOnConflictUpdate(
          _blockCompanion(block),
        );
      }
    });
  }

  static Future<void> updateBlock(block_model.Block block) async {
    block.updatedAt = DateTime.now();
    await _database.into(_database.blocks).insertOnConflictUpdate(
      _blockCompanion(block),
    );
  }

  static Future<List<block_model.Block>> getBlocksByDiary(
    String diaryId, {
    bool includeDeleted = false,
  }) async {
    final query = _database.select(_database.blocks)
      ..where(
        (t) =>
            t.diaryId.equals(diaryId) &
            (includeDeleted ? const Constant(true) : t.isDeleted.equals(false)),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    final rows = await query.get();
    return rows.map(_blockFromRow).toList();
  }

  static Future<void> softDeleteBlock(String blockId) async {
    await (_database.update(_database.blocks)
          ..where((t) => t.id.equals(blockId)))
        .write(const BlocksCompanion(isDeleted: Value(true)));
  }

  static Future<List<block_model.Block>> getBlocksByType(
    block_model.BlockType type, {
    bool includeDeleted = false,
  }) async {
    final query = _database.select(_database.blocks)
      ..where(
        (t) =>
            t.blockType.equals(type.value) &
            (includeDeleted ? const Constant(true) : t.isDeleted.equals(false)),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    final rows = await query.get();
    return rows.map(_blockFromRow).toList();
  }

  static Future<List<block_model.Block>> searchBlocksByContent(
    String keyword,
  ) async {
    if (keyword.trim().isEmpty) return [];
    final rows = await (_database.select(_database.blocks)
          ..where(
            (t) =>
                t.isDeleted.equals(false) &
                t.content.contains(keyword.trim()),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_blockFromRow).toList();
  }

  static Future<int> getBlockCount() async {
    return (await (_database.select(_database.blocks)
              ..where((t) => t.isDeleted.equals(false)))
            .get())
        .length;
  }

  static Future<Map<String, int>> getBlockCountsByDiary() async {
    final rows = await (_database.select(_database.blocks)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row.diaryId] = (counts[row.diaryId] ?? 0) + 1;
    }
    return counts;
  }

  static Future<List<block_model.Block>> getAllVisibleBlocks() async {
    final rows = await (_database.select(_database.blocks)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_blockFromRow).toList();
  }

  /// 导出/备份用：返回全部 Block（含软删除墓碑，保证往返一致）
  static Future<List<block_model.Block>> getAllBlocks() async {
    final rows = await (_database.select(_database.blocks)
          ..orderBy([(t) => OrderingTerm.asc(t.diaryId)]))
        .get();
    return rows.map(_blockFromRow).toList();
  }

  /// 按业务主键查询单个 Block
  static Future<block_model.Block?> getBlockById(String id) async {
    final row = await (_database.select(_database.blocks)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _blockFromRow(row);
  }

  /// 双模态聚合投影刷新：以 Blocks 为真相层，重算 diary.content/contentText
  /// 并落库（智能详情页-双模态架构设计 3.1/3.3）。
  ///
  /// 返回聚合后的 Markdown（供调用方同步内存对象）。
  static Future<String> refreshDiaryProjection(Diary diary) async {
    final blocks = await getBlocksByDiary(diary.id);
    final projection = MarkdownProjection.aggregate(blocks);
    diary
      ..content = projection
      ..contentText = projection.removeLineBreaks();
    await updateADiary(newDiary: diary);
    return projection;
  }

  static Future<void> upsertDiaryTextBlock(Diary diary) async {
    final blocks = await getBlocksByDiary(diary.id);
    final textBlocks = blocks
        .where((b) => b.blockType == block_model.BlockType.text)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final now = DateTime.now();
    if (textBlocks.isNotEmpty) {
      final block = textBlocks.first
        ..content = diary.content
        ..updatedAt = now;
      await updateBlock(block);
    } else {
      await insertBlock(
        block_model.Block()
          ..diaryId = diary.id
          ..blockType = block_model.BlockType.text
          ..content = diary.content
          ..sortOrder = 0
          ..createdAt = now
          ..updatedAt = now,
      );
    }
  }

  // ==================== CRM 实体缓存 ====================

  static Future<crm_model.CrmEntityCache?> getCrmEntityByTwentyId(
    String twentyId,
  ) async {
    final row = await (_database.select(_database.crmEntityCaches)
          ..where((t) => t.twentyId.equals(twentyId)))
        .getSingleOrNull();
    return row == null ? null : _crmFromRow(row);
  }

  static Future<void> upsertCrmEntities(
    List<crm_model.CrmEntityCache> entities,
  ) async {
    await _database.transaction(() async {
      for (final entity in entities) {
        await _database
            .into(_database.crmEntityCaches)
            .insertOnConflictUpdate(_crmCompanion(entity));
      }
    });
  }

  static Future<List<crm_model.CrmEntityCache>> getCrmEntitiesByType(
    String entityType, {
    bool includeDeleted = false,
  }) async {
    final query = _database.select(_database.crmEntityCaches)
      ..where(
        (t) =>
            t.entityType.equals(entityType) &
            (includeDeleted ? const Constant(true) : t.isDeleted.equals(false)),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_crmFromRow).toList();
  }

  static Future<List<crm_model.CrmEntityCache>> searchCrmByName(
    String keyword,
  ) async {
    if (keyword.trim().isEmpty) return [];
    final rows = await (_database.select(_database.crmEntityCaches)
          ..where(
            (t) =>
                t.isDeleted.equals(false) &
                t.name.contains(keyword.trim()),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_crmFromRow).toList();
  }

  static Future<void> removeCrmEntityByTwentyId(String twentyId) async {
    await (_database.delete(_database.crmEntityCaches)
          ..where((t) => t.twentyId.equals(twentyId)))
        .go();
  }

  static Future<int> countCrmEntitiesByType(String entityType) async {
    return (await (_database.select(_database.crmEntityCaches)
              ..where(
                (t) =>
                    t.entityType.equals(entityType) &
                    t.isDeleted.equals(false),
              ))
            .get())
        .length;
  }

  static Future<void> clearCrmCache() async {
    await _database.delete(_database.crmEntityCaches).go();
  }

  static Future<List<crm_model.CrmEntityCache>> getAllCrmEntities() async {
    final rows = await (_database.select(_database.crmEntityCaches)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_crmFromRow).toList();
  }

  // ==================== 内容同步映射（CrmContentLink） ====================

  static CrmContentLinksCompanion _linkCompanion(link_model.CrmContentLink l) {
    return CrmContentLinksCompanion.insert(
      id: l.id,
      localType: Value(l.localType),
      localId: Value(l.localId),
      remoteType: Value(l.remoteType),
      remoteId: Value(l.remoteId),
      targetType: Value(l.targetType),
      targetId: Value(l.targetId),
      status: Value(l.status),
      error: Value(l.error),
      createdAt: l.createdAt,
      updatedAt: l.updatedAt,
    );
  }

  static link_model.CrmContentLink _linkFromRow(CrmContentLinkRow row) {
    return link_model.CrmContentLink()
      ..id = row.id
      ..localType = row.localType
      ..localId = row.localId
      ..remoteType = row.remoteType
      ..remoteId = row.remoteId
      ..targetType = row.targetType
      ..targetId = row.targetId
      ..status = row.status
      ..error = row.error
      ..createdAt = row.createdAt
      ..updatedAt = row.updatedAt;
  }

  static Future<void> upsertCrmContentLinks(
    List<link_model.CrmContentLink> links,
  ) async {
    await _database.transaction(() async {
      for (final link in links) {
        await _database
            .into(_database.crmContentLinks)
            .insertOnConflictUpdate(_linkCompanion(link));
      }
    });
  }

  static Future<link_model.CrmContentLink?> getCrmContentLinkByLocal(
    String localType,
    String localId,
  ) async {
    final row = await (_database.select(_database.crmContentLinks)
          ..where(
            (t) => t.localType.equals(localType) & t.localId.equals(localId),
          ))
        .getSingleOrNull();
    return row == null ? null : _linkFromRow(row);
  }

  static Future<List<link_model.CrmContentLink>> getCrmContentLinks({
    String? localType,
    String? status,
  }) async {
    final query = _database.select(_database.crmContentLinks);
    if (localType != null) {
      query.where((t) => t.localType.equals(localType));
    }
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_linkFromRow).toList();
  }

  static Future<void> removeCrmContentLink(String id) async {
    await (_database.delete(_database.crmContentLinks)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  static Future<void> removeCrmContentLinkByLocal(
    String localType,
    String localId,
  ) async {
    await (_database.delete(_database.crmContentLinks)
          ..where(
            (t) => t.localType.equals(localType) & t.localId.equals(localId),
          ))
        .go();
  }
}
