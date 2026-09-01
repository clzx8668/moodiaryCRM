import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

/// 完全清空所有数据（调试用）。
///
/// 删除全部表（含日记/Block/分类、CRM 各实体 + 同步映射、知识库/向量、
/// AI 会话/消息/任务、日程/待办、同步记录等），并重置为"新库"状态。
/// 仅清数据行；应用级设置与 AI 密钥（安全存储）保留。
class DatabaseResetService {
  static Future<void> clearAllData({AppDatabase? db}) async {
    final d = db ?? IsarUtil.database;
    // 临时关闭外键，避免亲子表删除顺序限制
    await d.customStatement('PRAGMA foreign_keys = OFF');
    await d.transaction(() async {
      for (final table in d.allTables) {
        await d.customStatement('DELETE FROM "${table.aliasedName}"');
      }
    });
    await d.customStatement('PRAGMA foreign_keys = ON');
  }
}
