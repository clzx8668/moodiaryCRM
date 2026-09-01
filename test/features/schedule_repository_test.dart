import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/app_database.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create 回填 id/时间戳，getById 读取', () async {
    final created = await repo.create(
      Schedule()..title = '和客户对方案'..startTime = DateTime(2026, 8, 20, 10),
    );
    expect(created.id, isNotEmpty);

    final loaded = await repo.getById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.title, '和客户对方案');
    expect(loaded.startTime, DateTime(2026, 8, 20, 10));
  });

  test('update 修改标题与完成状态', () async {
    final created = await repo.create(Schedule()..title = 'A');
    final updated = created.clone()..title = 'B'..done = true;
    await repo.update(updated);

    final loaded = await repo.getById(created.id);
    expect(loaded!.title, 'B');
    expect(loaded.done, isTrue);
  });

  test('softDelete 后 listActive 排除', () async {
    final a = await repo.create(Schedule()..title = 'A');
    final b = await repo.create(Schedule()..title = 'B');
    await repo.softDelete(a.id);

    final active = await repo.listActive();
    expect(active.map((s) => s.id), isNot(contains(a.id)));
    expect(active.map((s) => s.id), contains(b.id));
  });

  test('byDay 返回当天日程（含重复）', () async {
    await repo.create(
      Schedule()
        ..title = '周一例会'
        ..startTime = DateTime(2026, 8, 10, 9)
        ..repeatType = RepeatType.weekly,
    );
    final dayItems = await repo.byDay(DateTime(2026, 8, 17));
    expect(dayItems, hasLength(1));
    expect(dayItems.first.title, '周一例会');
  });

  test('byRange 展开重复规则并保持时长', () async {
    await repo.create(
      Schedule()
        ..title = '每晚跑步'
        ..startTime = DateTime(2026, 8, 10, 20)
        ..endTime = DateTime(2026, 8, 10, 21)
        ..repeatType = RepeatType.daily,
    );
    final range = await repo.byRange(
      DateTime(2026, 8, 10),
      DateTime(2026, 8, 12, 23, 59),
    );
    expect(range, hasLength(3));
    expect(range.first.endTime!.difference(range.first.startTime), const Duration(hours: 1));
  });
}
