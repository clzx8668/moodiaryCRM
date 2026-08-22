import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// `List<String>` ↔ JSON 文本
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// `Map<String, dynamic>` ↔ JSON 文本
class MapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const MapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map).cast<String, dynamic>();

  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}

/// `List<dynamic>` ↔ JSON 文本
class JsonListConverter extends TypeConverter<List<dynamic>, String> {
  const JsonListConverter();

  @override
  List<dynamic> fromSql(String fromDb) => jsonDecode(fromDb) as List;

  @override
  String toSql(List<dynamic> value) => jsonEncode(value);
}

/// 日记表（对应原 Isar Diary）
@DataClassName('DiaryRow')
class Diaries extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get contentText => text().withDefault(const Constant(''))();
  TextColumn get yM => text().withDefault(const Constant(''))();
  TextColumn get yMd => text().withDefault(const Constant(''))();
  DateTimeColumn get time => dateTime()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get show => boolean().withDefault(const Constant(true))();
  RealColumn get mood => real().withDefault(const Constant(0.5))();
  TextColumn get weather =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get imageName =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get audioName =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get videoName =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get tags =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get position =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get keywords =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get tokenizer =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get type =>
      text().withDefault(const Constant('markdown'))();
  IntColumn get imageColor => integer().nullable()();
  RealColumn get aspect => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 分类表（对应原 Isar Category）
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get categoryName => text()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 字体表（对应原 Isar Font）
@DataClassName('FontRow')
class Fonts extends Table {
  TextColumn get fontFileName => text()();
  TextColumn get fontWghtAxisMap =>
      text().map(const MapConverter()).withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {fontFileName};
}

/// Block 表（智能块协议）
@DataClassName('BlockRow')
class Blocks extends Table {
  TextColumn get id => text()();
  TextColumn get diaryId => text()();
  IntColumn get blockType => integer()();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get streamBuffer => text().withDefault(const Constant(''))();
  BoolColumn get streamComplete => boolean().withDefault(const Constant(false))();
  /// 业务元数据（JSON 文本）：source/syncStatus/aiTemplate/entityType/title
  /// （智能详情页-双模态架构设计 3.2，v3→v4 迁移新增）
  TextColumn get metaJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 应用元数据表（db_version、迁移历史等）
@DataClassName('AppMetadataRow')
class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// CRM 实体缓存表
@DataClassName('CrmEntityCacheRow')
class CrmEntityCaches extends Table {
  TextColumn get id => text()();
  TextColumn get twentyId => text()();
  TextColumn get entityType => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get localVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地内容（Diary / Todo Block）↔ Twenty 对象同步映射表
@DataClassName('CrmContentLinkRow')
class CrmContentLinks extends Table {
  TextColumn get id => text()();
  TextColumn get localType => text().withDefault(const Constant(''))();
  TextColumn get localId => text().withDefault(const Constant(''))();
  TextColumn get remoteType => text().withDefault(const Constant(''))();
  TextColumn get remoteId => text().withDefault(const Constant(''))();
  TextColumn get targetType => text().withDefault(const Constant(''))();
  TextColumn get targetId => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get error => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {localType, localId},
  ];
}

/// 本地 CRM 公司表（本地优先 CRM，参考成熟 CRM 数据模型）
@DataClassName('CrmCompanyRow')
class CrmCompanies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get domainName => text().withDefault(const Constant(''))();
  TextColumn get addressJson =>
      text().map(const MapConverter()).withDefault(const Constant('{}'))();
  IntColumn get employees => integer().nullable()();
  TextColumn get linkedinLink => text().withDefault(const Constant(''))();
  TextColumn get xLink => text().withDefault(const Constant(''))();
  IntColumn get arrMicros => integer().nullable()();
  TextColumn get icp => text().withDefault(const Constant(''))();
  TextColumn get customerStatus => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地 CRM 联系人表
@DataClassName('CrmPersonRow')
class CrmPeople extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get firstName => text().withDefault(const Constant(''))();
  TextColumn get lastName => text().withDefault(const Constant(''))();
  TextColumn get jobTitle => text().withDefault(const Constant(''))();
  TextColumn get emailsJson =>
      text().map(const MapConverter()).withDefault(const Constant('{}'))();
  TextColumn get phonesJson =>
      text().map(const MapConverter()).withDefault(const Constant('{}'))();
  TextColumn get city => text().withDefault(const Constant(''))();
  TextColumn get wechat => text().withDefault(const Constant(''))();
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();
  TextColumn get linkedinLink => text().withDefault(const Constant(''))();
  TextColumn get xLink => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地 CRM 机会/线索表
@DataClassName('CrmOpportunityRow')
class CrmOpportunities extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get pointOfContactId => text().nullable()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get amountMicros => integer().nullable()();
  DateTimeColumn get closeDate => dateTime().nullable()();
  TextColumn get stage => text().withDefault(const Constant(''))();
  TextColumn get customStatus => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地 CRM 合同表
@DataClassName('CrmContractRow')
class CrmContracts extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().nullable()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get amountMicros => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get status => text().withDefault(const Constant(''))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get terms => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 自定义数据对象定义（元数据驱动，类似 Twenty metadata）
@DataClassName('CrmObjectDefRow')
class CrmObjectDefs extends Table {
  /// 对象键（如 payments / invoices）
  TextColumn get id => text()();
  TextColumn get labelSingular => text()();
  TextColumn get labelPlural => text()();
  TextColumn get icon => text().withDefault(const Constant(''))();
  /// 字段定义 JSON 数组：[{name,label,type,options,required,order}]
  TextColumn get fieldsJson =>
      text().map(const JsonListConverter()).withDefault(const Constant('[]'))();
  BoolColumn get builtin => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 自定义对象记录（JSON 宽表；label 为展示名，支持 json_extract 排序筛选）
@DataClassName('CrmCustomRecordRow')
class CrmCustomRecords extends Table {
  TextColumn get id => text()();
  TextColumn get objectId => text()();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get dataJson =>
      text().map(const MapConverter()).withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地实体 ↔ 日记/待办关联表（跟进记录/认领/时间线）
@DataClassName('CrmEntityLinkRow')
class CrmEntityLinks extends Table {
  TextColumn get id => text()();
  /// entityType：company / person / opportunity / contract / `custom:<objectId>`
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  /// localType：diary / block
  TextColumn get localType => text()();
  TextColumn get localId => text()();
  /// relation：followup / note / todo
  TextColumn get relation => text().withDefault(const Constant('followup'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {entityType, entityId, localType, localId, relation},
  ];
}

/// 同步记录表
@DataClassName('SyncRecordRow')
class SyncRecords extends Table {
  TextColumn get syncId => text()();
  TextColumn get diaryId => text()();
  TextColumn get diaryJson => text()();
  DateTimeColumn get time => dateTime()();
  IntColumn get syncType => integer()();

  @override
  Set<Column> get primaryKey => {syncId};
}

/// 知识库表（P3.2：多知识空间）
@DataClassName('KnowledgeBaseRow')
class KnowledgeBases extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 块向量表（P3.3：Text Block → Embedding → 本地向量库）
@DataClassName('BlockEmbeddingRow')
class BlockEmbeddings extends Table {
  TextColumn get blockId => text()();
  TextColumn get diaryId => text()();
  TextColumn get knowledgeBaseId => text()();
  /// 文本快照（用于重新生成向量与检索摘要）
  TextColumn get textContent => text()();
  /// f32 小端字节的 base64（避免 drift_dev 2.31 blob 代码生成路径的内部错误）
  TextColumn get embedding => text()();
  IntColumn get dimension => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {blockId, knowledgeBaseId};
}

/// AI 对话会话表（历史话题）
@DataClassName('AiChatSessionRow')
class AiChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('新话题'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// AI 对话消息表
@DataClassName('AiChatMessageRow')
class AiChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  /// 引用来源（RagHit JSON 数组，可选）
  TextColumn get sourcesJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Diaries,
    Categories,
    Fonts,
    Blocks,
    AppMetadata,
    CrmEntityCaches,
    CrmContentLinks,
    CrmCompanies,
    CrmPeople,
    CrmOpportunities,
    CrmContracts,
    CrmObjectDefs,
    CrmCustomRecords,
    CrmEntityLinks,
    SyncRecords,
    KnowledgeBases,
    BlockEmbeddings,
    AiChatSessions,
    AiChatMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v3 → v4：Blocks 增加 metaJson 列（数据级回填由 MigrationService 处理）
      if (from < 4) {
        final db = m.database as AppDatabase;
        await m.addColumn(db.blocks, db.blocks.metaJson);
      }
      // v4 → v5：新增知识库表与块向量表
      if (from < 5) {
        final db = m.database as AppDatabase;
        await m.createTable(db.knowledgeBases);
        await m.createTable(db.blockEmbeddings);
      }
      // v5 → v6：AI 对话会话与消息表
      if (from < 6) {
        final db = m.database as AppDatabase;
        await m.createTable(db.aiChatSessions);
        await m.createTable(db.aiChatMessages);
      }
      // v6 → v7：本地内容 ↔ Twenty 对象同步映射表
      if (from < 7) {
        final db = m.database as AppDatabase;
        await m.createTable(db.crmContentLinks);
      }
      // v7 → v8：本地优先 CRM（基础对象 + 自定义对象引擎 + 实体关联）
      if (from < 8) {
        final db = m.database as AppDatabase;
        await m.createTable(db.crmCompanies);
        await m.createTable(db.crmPeople);
        await m.createTable(db.crmOpportunities);
        await m.createTable(db.crmContracts);
        await m.createTable(db.crmObjectDefs);
        await m.createTable(db.crmCustomRecords);
        await m.createTable(db.crmEntityLinks);
      }
    },
    beforeOpen: (details) async {
      // 数据级迁移（v1→v2→v3）由 MigrationService 在打开后执行
    },
  );

  /// 打开应用数据库（桌面/移动端均使用 sqlite3）
  static Future<AppDatabase> open() async {
    return AppDatabase(driftDatabase(name: 'moodiary'));
  }
}
