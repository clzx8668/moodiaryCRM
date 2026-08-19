import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'crm_entity_cache.g.dart';

/// CRM 实体本地缓存（架构文档 3.1 CrmContactCache 的通用化版本）
///
/// 支持 company / person / opportunity / task / custom 等对象，
/// 以 twentyId 关联远端，dataJson 保存全量快照，UI 优先读本地缓存。
@collection
class CrmEntityCache {
  /// 业务主键（UUID）
  String id = const Uuid().v7();

  /// 数据库主键
  @Id()
  int get isarId => fastHash(id);

  /// Twenty 远端对象 ID
  @Index()
  String twentyId = '';

  /// 对象类型：company/person/opportunity/task/custom
  @Index()
  String entityType = '';

  /// 展示名称
  String name = '';

  /// 远端全量快照（JSON 字符串）
  String dataJson = '{}';

  /// 软删除标记（远端删除后本地保留墓碑以便增量同步）
  bool isDeleted = false;

  /// 本地版本号（每次本地修改 +1）
  int localVersion = 0;

  DateTime lastSyncedAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  CrmEntityCache();

  Map<String, dynamic> get data =>
      (jsonDecode(dataJson) as Map<String, dynamic>?) ?? <String, dynamic>{};

  void setData(Map<String, dynamic> value) {
    dataJson = jsonEncode(value);
  }

  CrmEntityCache clone() {
    return CrmEntityCache()
      ..id = id
      ..twentyId = twentyId
      ..entityType = entityType
      ..name = name
      ..dataJson = dataJson
      ..isDeleted = isDeleted
      ..localVersion = localVersion
      ..lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(
        lastSyncedAt.millisecondsSinceEpoch,
      )
      ..updatedAt = DateTime.fromMillisecondsSinceEpoch(
        updatedAt.millisecondsSinceEpoch,
      );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'twentyId': twentyId,
      'entityType': entityType,
      'name': name,
      'dataJson': dataJson,
      'isDeleted': isDeleted,
      'localVersion': localVersion,
      'lastSyncedAt': lastSyncedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CrmEntityCache.fromJson(Map<String, dynamic> json) {
    return CrmEntityCache()
      ..id = json['id'] as String
      ..twentyId = json['twentyId'] as String
      ..entityType = json['entityType'] as String
      ..name = json['name'] as String
      ..dataJson = json['dataJson'] as String
      ..isDeleted = json['isDeleted'] as bool? ?? false
      ..localVersion = (json['localVersion'] as num?)?.toInt() ?? 0
      ..lastSyncedAt = DateTime.parse(json['lastSyncedAt'] as String)
      ..updatedAt = DateTime.parse(json['updatedAt'] as String);
  }
}

int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
