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

  /// 卡片标题（折叠态展示，可选）
  String title;

  BlockMeta({
    this.source = sourceInitial,
    this.syncStatus = syncSynced,
    this.aiTemplate = '',
    this.entityType = '',
    this.title = '',
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
      title: title,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'syncStatus': syncStatus,
      'aiTemplate': aiTemplate,
      'entityType': entityType,
      'title': title,
    };
  }

  factory BlockMeta.fromJson(Map<String, dynamic> json) {
    return BlockMeta(
      source: json['source'] as String? ?? sourceInitial,
      syncStatus: json['syncStatus'] as String? ?? syncSynced,
      aiTemplate: json['aiTemplate'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      title: json['title'] as String? ?? '',
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
          title == other.title;

  @override
  int get hashCode =>
      Object.hash(source, syncStatus, aiTemplate, entityType, title);
}
