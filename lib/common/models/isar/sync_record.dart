import 'package:uuid/uuid.dart';

class SyncRecord {
  // 业务主键，使用 uuid
  String syncId = const Uuid().v7();

  // 兼容旧接口
  int get isarId => fastHash(syncId);

  // 日记id
  late String diaryId;

  // 日记json
  late String diaryJson;

  late DateTime time = DateTime.now();

  late SyncType syncType;
}

enum SyncType { upload, download, update, delete }

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
