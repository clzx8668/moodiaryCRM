import 'package:drift/drift.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

import 'models/calendar_list.dart';

/// 多日历仓储（唯一读写入口）。
///
/// 表在 schema v23 引入；播种由数据库 `beforeOpen` 完成
/// （`_ensureDefaultCalendars`：工作/生活/家庭 + 历史日程回填）。
class CalendarRepository {
  final AppDatabase db;

  CalendarRepository([AppDatabase? db]) : db = db ?? IsarUtil.database;

  /// 全部未删除日历（按 sortOrder 升序）。
  Future<List<CalendarList>> listAll() async {
    final rows = await (db.select(db.calendars)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(CalendarList.fromRow).toList();
  }

  /// 仅可见日历（月格/时间轴按这个过滤）。
  Future<List<CalendarList>> listVisible() async =>
      (await listAll()).where((c) => c.visible).toList();

  Future<CalendarList?> getById(String id) async {
    final row = await (db.select(db.calendars)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : CalendarList.fromRow(row);
  }

  /// 默认日历（新建事件的落点）；没有标记就取第一个可用的。
  Future<CalendarList?> defaultCalendar() async {
    final all = await listAll();
    if (all.isEmpty) return null;
    for (final c in all) {
      if (c.isDefault) return c;
    }
    return all.first;
  }

  /// id → 颜色（事件卡与月格圆点用；避免 N 次查询）。
  Future<Map<String, int>> colorMap() async => {
    for (final c in await listAll()) c.id: c.color,
  };

  Future<CalendarList> create({
    required String name,
    int? color,
    bool visible = true,
    String source = 'local',
  }) async {
    final all = await listAll();
    final entity = CalendarList(
      id: const Uuid().v7(),
      name: name.trim().isEmpty ? '新日历' : name.trim(),
      color: color ?? CalendarColors.suggestByName(name),
      visible: visible,
      source: source,
      sortOrder: all.length,
    );
    await db.into(db.calendars).insert(_toCompanion(entity, insert: true));
    return entity;
  }

  Future<void> update(CalendarList calendar) async {
    calendar.updatedAt = DateTime.now();
    await (db.update(db.calendars)..where((t) => t.id.equals(calendar.id)))
        .write(_toCompanion(calendar, insert: false));
  }

  Future<void> setVisible(String id, bool visible) async {
    await (db.update(db.calendars)..where((t) => t.id.equals(id))).write(
      CalendarsCompanion(
        visible: Value(visible),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 设默认日历（同时把其它日历的 isDefault 清掉，保持"恰一个"）。
  Future<void> setDefault(String id) async {
    final now = DateTime.now();
    await db.transaction(() async {
      await db.update(db.calendars).write(
        CalendarsCompanion(isDefault: const Value(false), updatedAt: Value(now)),
      );
      await (db.update(db.calendars)..where((t) => t.id.equals(id))).write(
        CalendarsCompanion(isDefault: const Value(true), updatedAt: Value(now)),
      );
    });
  }

  /// 软删除日历：把它的日程挪到兜底日历（不丢事件）；最后一个日历不允许删。
  ///
  /// 返回 false = 拒绝删除（只剩一个日历）。
  Future<bool> softDelete(String id) async {
    final all = await listAll();
    final remaining = all.where((c) => c.id != id).toList();
    if (remaining.isEmpty) return false;

    final fallback = remaining.firstWhere(
      (c) => c.isDefault,
      orElse: () => remaining.first,
    );
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.schedules)
            ..where((t) => t.calendarId.equals(id)))
          .write(
            SchedulesCompanion(
              calendarId: Value(fallback.id),
              updatedAt: Value(now),
            ),
          );
      await (db.update(db.calendars)..where((t) => t.id.equals(id))).write(
        CalendarsCompanion(deleted: const Value(true), updatedAt: Value(now)),
      );
      if (all.firstWhere((c) => c.id == id).isDefault) {
        await (db.update(db.calendars)
              ..where((t) => t.id.equals(fallback.id)))
            .write(
              CalendarsCompanion(
                isDefault: const Value(true),
                updatedAt: Value(now),
              ),
            );
      }
    });
    return true;
  }

  CalendarsCompanion _toCompanion(CalendarList c, {required bool insert}) =>
      CalendarsCompanion(
        id: Value(c.id),
        name: Value(c.name),
        color: Value(c.color),
        visible: Value(c.visible),
        isDefault: Value(c.isDefault),
        source: Value(c.source),
        sharedCount: Value(c.sharedCount),
        sortOrder: Value(c.sortOrder),
        deleted: Value(c.deleted),
        createdAt: insert ? Value(c.createdAt) : const Value.absent(),
        updatedAt: Value(c.updatedAt),
      );
}
