import 'package:uuid/uuid.dart';

/// 本地内容（Diary / Todo Block）↔ Twenty 对象的同步映射。
///
/// 设计目标（下一阶段：Twenty 数据对象对接）：
/// - 笔记（Diary）→ Twenty `note`；待办（Todo Block）→ Twenty `task`；
/// - 有客户/联系人/机会关联的自动挂 noteTarget/taskTarget，进入客户时间线；
/// - 未关联数据落到通用对象（`moodiaryGeneric`）或标准 note/task（无 target），
///   后续可编辑并在本应用内「认领关联」。
class CrmContentLink {
  /// 本地来源类型
  static const String localTypeDiary = 'diary';
  static const String localTypeBlock = 'block';

  /// Twenty 远端对象类型
  static const String remoteTypeNote = 'note';
  static const String remoteTypeTask = 'task';
  static const String remoteTypeGeneric = 'moodiaryGeneric';

  /// 同步状态
  static const String statusPending = 'pending';
  static const String statusLinked = 'linked';
  static const String statusGeneric = 'generic';
  static const String statusError = 'error';
  static const String statusDeleted = 'deleted';

  /// 业务主键（UUID）
  String id = const Uuid().v7();

  /// 本地对象类型：diary | block
  String localType = '';

  /// 本地对象 ID（Diary.id 或 Block.id）
  String localId = '';

  /// 远端对象类型：note | task | moodiaryGeneric
  String remoteType = '';

  /// Twenty 远端对象 ID
  String remoteId = '';

  /// 关联目标类型：'' | company | person | opportunity
  String targetType = '';

  /// 关联目标 Twenty ID（company/person/opportunity 的远端 id）
  String targetId = '';

  /// 同步状态：pending/linked/generic/error/deleted
  String status = statusPending;

  /// 最近一次错误信息（status=error 时有值）
  String error = '';

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  CrmContentLink();

  bool get isLinked => status == statusLinked;

  bool get isGeneric => status == statusGeneric;

  bool get hasError => status == statusError;

  bool get isPending => status == statusPending;

  CrmContentLink clone() {
    return CrmContentLink()
      ..id = id
      ..localType = localType
      ..localId = localId
      ..remoteType = remoteType
      ..remoteId = remoteId
      ..targetType = targetType
      ..targetId = targetId
      ..status = status
      ..error = error
      ..createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdAt.millisecondsSinceEpoch,
      )
      ..updatedAt = DateTime.fromMillisecondsSinceEpoch(
        updatedAt.millisecondsSinceEpoch,
      );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'localType': localType,
      'localId': localId,
      'remoteType': remoteType,
      'remoteId': remoteId,
      'targetType': targetType,
      'targetId': targetId,
      'status': status,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CrmContentLink.fromJson(Map<String, dynamic> json) {
    return CrmContentLink()
      ..id = json['id'] as String
      ..localType = json['localType'] as String? ?? ''
      ..localId = json['localId'] as String? ?? ''
      ..remoteType = json['remoteType'] as String? ?? ''
      ..remoteId = json['remoteId'] as String? ?? ''
      ..targetType = json['targetType'] as String? ?? ''
      ..targetId = json['targetId'] as String? ?? ''
      ..status = json['status'] as String? ?? statusPending
      ..error = json['error'] as String? ?? ''
      ..createdAt = DateTime.parse(json['createdAt'] as String)
      ..updatedAt = DateTime.parse(json['updatedAt'] as String);
  }
}
