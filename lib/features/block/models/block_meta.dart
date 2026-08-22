import 'dart:convert';

/// Block 业务元数据（`metaJson` 列的 Dart 视图）。
///
/// 设计依据：智能详情页-双模态架构设计 3.2。`Blocks` 表只增加一列
/// `metaJson`（JSON 文本），业务语义收敛到这个类，避免频繁改表。
class BlockMeta {
  /// 卡片来源（决定详情页来源徽标与初始卡判定）
  static const String sourceInitial = 'initial';
  static const String sourceAppended = 'appended';
  static const String sourceAi = 'ai';
  static const String sourceImported = 'imported';

  /// 同步状态（与 Rust SyncStatus 对应）
  static const String syncSynced = 'synced';
  static const String syncPending = 'pending';
  static const String syncConflict = 'conflict';

  /// 卡片来源
  String source;

  /// 同步状态
  String syncStatus;

  /// AI 模板标识（summary/expand/polish/translate/meeting/todo/checkin）
  String aiTemplate;

  /// 实体类型（smartEntity：company/person/opportunity/task/custom）
  String entityType;

  /// 关联实体 Twenty ID（本地 CRM 缓存的 twentyId，认领/自动关联用）
  String entityId;

  /// 关联实体展示名（便于列表与徽标展示）
  String entityName;

  /// 卡片标题（折叠态展示，可选）
  String title;

  /// AI 处理源内容快照（aiStream 断点恢复用，P2.9）
  String sourceContent;

  /// 到期时间（ISO 8601 文本，待办类 Block 用；空串表示无到期）
  String dueDate;

  /// 内容向 Twenty 推送的状态：''（未推送）/ pending / synced / error
  String crmSyncStatus;

  BlockMeta({
    this.source = sourceInitial,
    this.syncStatus = syncSynced,
    this.aiTemplate = '',
    this.entityType = '',
    this.entityId = '',
    this.entityName = '',
    this.title = '',
    this.sourceContent = '',
    this.dueDate = '',
    this.crmSyncStatus = '',
  });

  bool get isAi => source == sourceAi;

  bool get isAppended => source == sourceAppended;

  bool get isInitial => source == sourceInitial;

  bool get isPending => syncStatus == syncPending;

  bool get isConflict => syncStatus == syncConflict;

  BlockMeta clone() {
    return BlockMeta(
      source: source,
      syncStatus: syncStatus,
      aiTemplate: aiTemplate,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      title: title,
      sourceContent: sourceContent,
      dueDate: dueDate,
      crmSyncStatus: crmSyncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'syncStatus': syncStatus,
      'aiTemplate': aiTemplate,
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'title': title,
      'sourceContent': sourceContent,
      'dueDate': dueDate,
      'crmSyncStatus': crmSyncStatus,
    };
  }

  factory BlockMeta.fromJson(Map<String, dynamic> json) {
    return BlockMeta(
      source: json['source'] as String? ?? sourceInitial,
      syncStatus: json['syncStatus'] as String? ?? syncSynced,
      aiTemplate: json['aiTemplate'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      entityName: json['entityName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceContent: json['sourceContent'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      crmSyncStatus: json['crmSyncStatus'] as String? ?? '',
    );
  }

  String encode() => jsonEncode(toJson());

  factory BlockMeta.decode(String raw) {
    if (raw.trim().isEmpty) return BlockMeta();
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return BlockMeta.fromJson(json);
    } catch (_) {
      // 容错：损坏的 metaJson 回退默认值
    }
    return BlockMeta();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockMeta &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          syncStatus == other.syncStatus &&
          aiTemplate == other.aiTemplate &&
          entityType == other.entityType &&
          entityId == other.entityId &&
          entityName == other.entityName &&
          title == other.title &&
          sourceContent == other.sourceContent &&
          dueDate == other.dueDate &&
          crmSyncStatus == other.crmSyncStatus;

  @override
  int get hashCode =>
      Object.hash(
        source,
        syncStatus,
        aiTemplate,
        entityType,
        entityId,
        entityName,
        title,
        sourceContent,
        dueDate,
        crmSyncStatus,
      );
}
