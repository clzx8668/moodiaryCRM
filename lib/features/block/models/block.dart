import 'package:uuid/uuid.dart';

/// Block 类型（架构文档：Text/SmartEntity/Todo/Chart/AiStream/Image/Code）
enum BlockType {
  text(0),
  smartEntity(1),
  todo(2),
  chart(3),
  aiStream(4),
  image(5),
  code(6);

  /// 显式数值，保证序列化稳定（不受枚举声明顺序影响）
  final int value;

  const BlockType(this.value);

  static BlockType fromValue(int value) {
    return BlockType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BlockType.text,
    );
  }
}

/// Block 数据模型：所有模块数据的底层统一协议（JSON 数组 + Markdown/结构化 JSON）。
///
/// 设计要点（对齐架构文档三、3.1）：
/// - 独立表，通过 [diaryId] 关联 Diary，支持单独查询；
/// - [isDeleted] 软删除标记；
/// - [streamBuffer]/[streamComplete] 支持 AI 流式输出断点恢复；
/// - [content] 为 Markdown 文本或结构化 JSON 字符串。
class Block {
  /// 业务主键（UUID）
  String id = const Uuid().v7();

  /// 关联日记 ID（外键）
  String diaryId = '';

  /// 块类型
  BlockType blockType = BlockType.text;

  /// 内容：Markdown 文本或 JSON 字符串
  String content = '';

  /// 块在列表中的排序
  int sortOrder = 0;

  /// 软删除标记
  bool isDeleted = false;

  /// AI 流式输出缓存（仅 aiStream 类型使用），定期持久化以支持断点恢复
  String streamBuffer = '';

  /// 标记流式输出是否已完成
  bool streamComplete = false;

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  Block();

  /// 深拷贝
  Block clone() {
    return Block()
      ..id = id
      ..diaryId = diaryId
      ..blockType = blockType
      ..content = content
      ..sortOrder = sortOrder
      ..isDeleted = isDeleted
      ..streamBuffer = streamBuffer
      ..streamComplete = streamComplete
      ..createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdAt.millisecondsSinceEpoch,
      )
      ..updatedAt = DateTime.fromMillisecondsSinceEpoch(
        updatedAt.millisecondsSinceEpoch,
      );
  }

  /// 基础校验：必须有关联日记、非空内容（aiStream 允许空，因流式未完成）
  bool isValid() {
    if (diaryId.isEmpty) return false;
    if (blockType == BlockType.aiStream) return true;
    return content.trim().isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'diaryId': diaryId,
      'blockType': blockType.value,
      'content': content,
      'sortOrder': sortOrder,
      'isDeleted': isDeleted,
      'streamBuffer': streamBuffer,
      'streamComplete': streamComplete,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block()
      ..id = json['id'] as String
      ..diaryId = json['diaryId'] as String
      ..blockType = BlockType.fromValue((json['blockType'] as num).toInt())
      ..content = json['content'] as String
      ..sortOrder = (json['sortOrder'] as num).toInt()
      ..isDeleted = json['isDeleted'] as bool
      ..streamBuffer = json['streamBuffer'] as String? ?? ''
      ..streamComplete = json['streamComplete'] as bool? ?? false
      ..createdAt = DateTime.parse(json['createdAt'] as String)
      ..updatedAt = DateTime.parse(json['updatedAt'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Block &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          diaryId == other.diaryId &&
          blockType == other.blockType &&
          content == other.content &&
          sortOrder == other.sortOrder &&
          isDeleted == other.isDeleted &&
          streamBuffer == other.streamBuffer &&
          streamComplete == other.streamComplete &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode {
    return Object.hash(
      id,
      diaryId,
      blockType,
      content,
      sortOrder,
      isDeleted,
      streamBuffer,
      streamComplete,
      createdAt,
      updatedAt,
    );
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
