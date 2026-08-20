import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// `List<String>` ↔ JSON 文本
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// `Map<String, dynamic>` ↔ JSON 文本
class MapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const MapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map).cast<String, dynamic>();

  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}

/// 日记表（对应原 Isar Diary）
@DataClassName('DiaryRow')
class Diaries extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get contentText => text().withDefault(const Constant(''))();
  TextColumn get yM => text().withDefault(const Constant(''))();
  TextColumn get yMd => text().withDefault(const Constant(''))();
  DateTimeColumn get time => dateTime()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get show => boolean().withDefault(const Constant(true))();
  RealColumn get mood => real().withDefault(const Constant(0.5))();
  TextColumn get weather =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get imageName =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get audioName =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get videoName =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get tags =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get position =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get keywords =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get tokenizer =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get type =>
      text().withDefault(const Constant('markdown'))();
  IntColumn get imageColor => integer().nullable()();
  RealColumn get aspect => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 分类表（对应原 Isar Category）
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get categoryName => text()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 字体表（对应原 Isar Font）
@DataClassName('FontRow')
class Fonts extends Table {
  TextColumn get fontFileName => text()();
  TextColumn get fontWghtAxisMap =>
      text().map(const MapConverter()).withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {fontFileName};
}

/// Block 表（智能块协议）
@DataClassName('BlockRow')
class Blocks extends Table {
  TextColumn get id => text()();
  TextColumn get diaryId => text()();
  IntColumn get blockType => integer()();
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get streamBuffer => text().withDefault(const Constant(''))();
  BoolColumn get streamComplete => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 应用元数据表（db_version、迁移历史等）
@DataClassName('AppMetadataRow')
class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// CRM 实体缓存表
@DataClassName('CrmEntityCacheRow')
class CrmEntityCaches extends Table {
  TextColumn get id => text()();
  TextColumn get twentyId => text()();
  TextColumn get entityType => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get localVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 同步记录表
@DataClassName('SyncRecordRow')
class SyncRecords extends Table {
  TextColumn get syncId => text()();
  TextColumn get diaryId => text()();
  TextColumn get diaryJson => text()();
  DateTimeColumn get time => dateTime()();
  IntColumn get syncType => integer()();

  @override
  Set<Column> get primaryKey => {syncId};
}

@DriftDatabase(
  tables: [
    Diaries,
    Categories,
    Fonts,
    Blocks,
    AppMetadata,
    CrmEntityCaches,
    SyncRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      // 数据级迁移（v1→v2→v3）由 MigrationService 在打开后执行
    },
  );

  /// 打开应用数据库（桌面/移动端均使用 sqlite3）
  static Future<AppDatabase> open() async {
    return AppDatabase(driftDatabase(name: 'moodiary'));
  }
}
