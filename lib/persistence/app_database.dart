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

/// 本地 CRM 客户/账户表（统一承载 company / person / org，Contact 从属于此）
@DataClassName('CrmAccountRow')
class CrmAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  /// company / person / org
  TextColumn get type => text().withDefault(const Constant('company'))();
  TextColumn get industry => text().withDefault(const Constant(''))();
  /// vip / normal / potential
  TextColumn get level => text().withDefault(const Constant('normal'))();
  TextColumn get source => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get website => text().withDefault(const Constant(''))();
  TextColumn get creditCode => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  /// active / inactive / blacklist
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地 CRM 联系人表（从属 Account）
@DataClassName('CrmContactRow')
class CrmContacts extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get department => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get wechat => text().withDefault(const Constant(''))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get isDecisionMaker => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地 CRM 机会/线索表（stage 覆盖全生命周期，合并线索）
@DataClassName('CrmOpportunityRow')
class CrmOpportunities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get accountId => text().nullable()();
  TextColumn get contactId => text().nullable()();
  /// newLead/contacted/qualified/proposal/negotiation/closedWon/closedLost/abandoned
  TextColumn get stage => text().withDefault(const Constant('newLead'))();
  IntColumn get probability => integer().withDefault(const Constant(0))();
  RealColumn get amount => real().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get source => text().withDefault(const Constant(''))();
  TextColumn get leadContactName => text().withDefault(const Constant(''))();
  TextColumn get leadPhone => text().withDefault(const Constant(''))();
  TextColumn get leadEmail => text().withDefault(const Constant(''))();
  DateTimeColumn get expectedCloseDate => dateTime().nullable()();
  DateTimeColumn get actualCloseDate => dateTime().nullable()();
  TextColumn get lossReason => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 本地 CRM 合同表（含冗余已回款/已开票金额）
@DataClassName('CrmContractRow')
class CrmContracts extends Table {
  TextColumn get id => text()();
  TextColumn get contractNo => text().withDefault(const Constant(''))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get accountId => text().nullable()();
  TextColumn get contactId => text().nullable()();
  TextColumn get opportunityId => text().nullable()();
  TextColumn get quoteId => text().nullable()();
  /// draft/active/completed/terminated/expired
  TextColumn get status => text().withDefault(const Constant('draft'))();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get invoicedAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get signDate => dateTime().nullable()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get warrantyEndDate => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 产品分类（支持两级）
@DataClassName('CrmProductCategoryRow')
class CrmProductCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 产品/服务
@DataClassName('CrmProductRow')
class CrmProducts extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  /// product / service
  TextColumn get type => text().withDefault(const Constant('product'))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  RealColumn get price => real().withDefault(const Constant(0))();
  RealColumn get cost => real().withDefault(const Constant(0))();
  IntColumn get warrantyMonths => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 报价单
@DataClassName('CrmQuoteRow')
class CrmQuotes extends Table {
  TextColumn get id => text()();
  TextColumn get quoteNo => text()();
  TextColumn get opportunityId => text().nullable()();
  TextColumn get accountId => text().nullable()();
  TextColumn get contactId => text().nullable()();
  /// draft/sent/accepted/rejected/expired
  TextColumn get status => text().withDefault(const Constant('draft'))();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get validUntil => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 报价明细
@DataClassName('CrmQuoteItemRow')
class CrmQuoteItems extends Table {
  TextColumn get id => text()();
  TextColumn get quoteId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get productName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  RealColumn get unitPrice => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(1))();
  RealColumn get amount => real().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 合同明细（产品名快照防篡改）
@DataClassName('CrmContractItemRow')
class CrmContractItems extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get productName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  RealColumn get unitPrice => real().withDefault(const Constant(0))();
  RealColumn get amount => real().withDefault(const Constant(0))();
  IntColumn get warrantyMonths => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 回款计划
@DataClassName('CrmPaymentPlanRow')
class CrmPaymentPlans extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  TextColumn get planName => text()();
  RealColumn get planAmount => real().withDefault(const Constant(0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get planDate => dateTime()();
  /// pending/partial/completed/overdue
  TextColumn get status => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 回款记录
@DataClassName('CrmPaymentRow')
class CrmPayments extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  TextColumn get planId => text().nullable()();
  RealColumn get amount => real()();
  DateTimeColumn get paymentDate => dateTime()();
  /// cash/transfer/check/wechat/alipay
  TextColumn get method => text().withDefault(const Constant('transfer'))();
  TextColumn get invoiceId => text().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 发票
@DataClassName('CrmInvoiceRow')
class CrmInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  TextColumn get invoiceNo => text().withDefault(const Constant(''))();
  /// vat_special/vat_normal/electronic
  TextColumn get type => text().withDefault(const Constant('vat_normal'))();
  RealColumn get amount => real()();
  RealColumn get taxRate => real().withDefault(const Constant(0.13))();
  DateTimeColumn get issueDate => dateTime().nullable()();
  /// pending/issued/delivered/void
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get receiverName => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 质保
@DataClassName('CrmWarrantyRow')
class CrmWarranties extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text()();
  TextColumn get contractItemId => text().nullable()();
  TextColumn get productId => text().nullable()();
  TextColumn get serialNo => text().withDefault(const Constant(''))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  /// active/expired/void
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 售后工单
@DataClassName('CrmAfterSalesRow')
class CrmAfterSales extends Table {
  TextColumn get id => text()();
  TextColumn get ticketNo => text()();
  TextColumn get accountId => text()();
  TextColumn get contactId => text().nullable()();
  TextColumn get contractId => text().nullable()();
  TextColumn get warrantyId => text().nullable()();
  /// repair/install/consult/complaint/other
  TextColumn get type => text().withDefault(const Constant('other'))();
  /// low/medium/high/urgent
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  /// open/inProgress/waitingCustomer/resolved/closed
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get subject => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get resolution => text().withDefault(const Constant(''))();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
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
    CrmAccounts,
    CrmContacts,
    CrmOpportunities,
    CrmContracts,
    CrmProductCategories,
    CrmProducts,
    CrmQuotes,
    CrmQuoteItems,
    CrmContractItems,
    CrmPaymentPlans,
    CrmPayments,
    CrmInvoices,
    CrmWarranties,
    CrmAfterSales,
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
  int get schemaVersion => 12;

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
        await m.createTable(db.crmObjectDefs);
        await m.createTable(db.crmCustomRecords);
        await m.createTable(db.crmEntityLinks);
      }
      // v8 → v9：R1 决策 —— Account 统一承载客户，Contact 从属；
      // 机会/合同按 19 表设计文档重建（v8 CRM 表仅测试数据，直接重建）
      if (from < 9) {
        final db = m.database as AppDatabase;
        await db.customStatement('DROP TABLE IF EXISTS crm_companies');
        await db.customStatement('DROP TABLE IF EXISTS crm_people');
        await db.customStatement('DROP TABLE IF EXISTS crm_opportunities');
        await db.customStatement('DROP TABLE IF EXISTS crm_contracts');
        await m.createTable(db.crmAccounts);
        await m.createTable(db.crmContacts);
        await m.createTable(db.crmOpportunities);
        await m.createTable(db.crmContracts);
      }
      // v9 → v10：产品/分类、报价单/明细、合同明细
      if (from < 10) {
        final db = m.database as AppDatabase;
        await m.createTable(db.crmProductCategories);
        await m.createTable(db.crmProducts);
        await m.createTable(db.crmQuotes);
        await m.createTable(db.crmQuoteItems);
        await m.createTable(db.crmContractItems);
      }
      // v10 → v11：回款计划/回款记录/发票
      if (from < 11) {
        final db = m.database as AppDatabase;
        await m.createTable(db.crmPaymentPlans);
        await m.createTable(db.crmPayments);
        await m.createTable(db.crmInvoices);
      }
      // v11 → v12：质保 + 售后工单
      if (from < 12) {
        final db = m.database as AppDatabase;
        await m.createTable(db.crmWarranties);
        await m.createTable(db.crmAfterSales);
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
