import 'package:drift/native.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

/// 打开内存 Drift 测试库并注入 IsarUtil
AppDatabase openTestDb() {
  final db = AppDatabase(NativeDatabase.memory());
  IsarUtil.overrideDbForTest(db);
  return db;
}

/// 关闭并还原测试库
void closeTestDb(AppDatabase db) {
  IsarUtil.restoreDbForTest();
  db.close();
}
