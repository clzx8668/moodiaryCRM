import 'package:drift/drift.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

import 'models/schedule.dart';
import 'schedule_recurrence.dart';

/// 待办/日程仓储层（唯一读写入口，批次 B）。
///
/// 覆盖基础 CRUD、按日/按范围查询（含重复规则展开）与完成状态切换。
class ScheduleRepository {
  final AppDatabase db;

  ScheduleRepository([AppDatabase? db]) : db = db ?? IsarUtil.database;

  /// 全部未删除日程（按开始时间升序）。
  Future<List<Schedule>> listActive() async {
    final rows = await (db.select(db.schedules)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<Schedule?> getById(String id) async {
    final row = await (db.select(db.schedules)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<Schedule> create(Schedule schedule) async {
    final now = DateTime.now();
    final entity = schedule
      ..id = schedule.id.isEmpty ? const Uuid().v7() : schedule.id
      ..createdAt = now
      ..updatedAt = now;
    await db.into(db.schedules).insert(_toCompanion(entity));
    return entity;
  }

  Future<Schedule> update(Schedule schedule) async {
    schedule.updatedAt = DateTime.now();
    await (db.update(db.schedules)..where((t) => t.id.equals(schedule.id)))
        .write(_toCompanion(schedule));
    return schedule;
  }

  Future<void> softDelete(String id) async {
    await (db.update(db.schedules)..where((t) => t.id.equals(id))).write(
      SchedulesCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> toggleDone(String id, {bool? value}) async {
    final row = await (db.select(db.schedules)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (db.update(db.schedules)..where((t) => t.id.equals(id))).write(
      SchedulesCompanion(
        done: Value(value ?? !row.done),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 按范围查询并展开重复规则，返回 `[from, to]` 内的日程实例（含跨天）。
  Future<List<Schedule>> byRange(DateTime from, DateTime to) async {
    // 起点不晚于 to 的日程种子（含历史重复种子），再在内存中展开过滤。
    final rows = await (db.select(db.schedules)
          ..where((t) => t.deleted.equals(false) & t.startTime.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
    final seeds = rows.map(_fromRow).toList();
    return expand(seeds, from, to);
  }

  /// 某一天的日程（含跨天落在此日的 + 重复展开）。
  Future<List<Schedule>> byDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final expanded = await byRange(dayStart, dayEnd.subtract(const Duration(seconds: 1)));
    return expanded
        .where(
          (s) =>
              !s.endDay.isBefore(dayStart) &&
              !s.day.isAfter(dayEnd.subtract(const Duration(seconds: 1))),
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Schedule _fromRow(ScheduleRow row) => Schedule()
    ..id = row.id
    ..title = row.title
    ..notes = row.notes
    ..startTime = row.startTime
    ..endTime = row.endTime
    ..allDay = row.allDay
    ..floating = row.floating
    ..repeatType = RepeatType.fromValue(row.repeatType)
    ..remindOffsetMin = row.remindOffsetMin
    ..priority = SchedulePriority.fromValue(row.priority)
    ..tag = row.tag
    ..bgColor = row.bgColor
    ..done = row.done
    ..subtasks = [
      for (final s in row.subtasks) ScheduleSubtask.fromJson(s),
    ]
    ..imageNames = List.of(row.imageNames)
    ..linkedDiaryId = row.linkedDiaryId
    ..linkedBlockId = row.linkedBlockId
    ..deleted = row.deleted
    ..createdAt = row.createdAt
    ..updatedAt = row.updatedAt;

  SchedulesCompanion _toCompanion(Schedule s) => SchedulesCompanion.insert(
    id: s.id,
    title: s.title,
    notes: Value(s.notes),
    startTime: s.startTime,
    endTime: Value(s.endTime),
    allDay: Value(s.allDay),
    floating: Value(s.floating),
    repeatType: Value(s.repeatType.value),
    remindOffsetMin: Value(s.remindOffsetMin),
    priority: Value(s.priority.value),
    tag: Value(s.tag),
    bgColor: Value(s.bgColor),
    done: Value(s.done),
    subtasks: Value([
      for (final st in s.subtasks) st.toJson(),
    ]),
    imageNames: Value(s.imageNames),
    linkedDiaryId: Value(s.linkedDiaryId),
    linkedBlockId: Value(s.linkedBlockId),
    deleted: Value(s.deleted),
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  );
}
