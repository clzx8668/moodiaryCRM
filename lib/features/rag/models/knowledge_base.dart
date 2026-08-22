import 'package:uuid/uuid.dart';

/// 知识库元数据（P3.2 多知识空间）
class KnowledgeBase {
  /// 业务主键（UUID）
  String id = const Uuid().v7();

  String name = '';

  String description = '';

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  KnowledgeBase();

  KnowledgeBase clone() {
    return KnowledgeBase()
      ..id = id
      ..name = name
      ..description = description
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
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory KnowledgeBase.fromJson(Map<String, dynamic> json) {
    return KnowledgeBase()
      ..id = json['id'] as String
      ..name = json['name'] as String
      ..description = json['description'] as String? ?? ''
      ..createdAt = DateTime.parse(json['createdAt'] as String)
      ..updatedAt = DateTime.parse(json['updatedAt'] as String);
  }
}
