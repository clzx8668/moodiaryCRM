import 'package:isar/isar.dart';

part 'app_metadata.g.dart';

/// 应用元数据表（对齐架构文档 3.4：app_metadata 中的 db_version 等）。
/// 使用 Isar 内建表存储，避免依赖平台插件，便于单元测试与迁移事务一致。
@collection
class AppMetadata {
  /// 业务主键（key 本身）
  String key;

  /// 数据库主键（沿用 fastHash 惯例）
  @Id()
  int get isarId => fastHash(key);

  String value;

  AppMetadata({required this.key, required this.value});
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
