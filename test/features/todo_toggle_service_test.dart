import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/features/todo/todo_toggle_service.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  test('schedule 来源走权威源 Schedules.done 并翻转', () async {
    final repo = ScheduleRepository();
    final created = await repo.create(
      Schedule()..title = '开会'..startTime = DateTime(2026, 9, 1, 10),
    );
    final service = TodoToggleService();
    final item = TodoItem(
      id: 'schedule:${created.id}',
      source: TodoSource.schedule,
      text: '开会',
      done: false,
      dueDate: created.startTime,
      time: created.updatedAt,
      scheduleId: created.id,
    );

    await service.toggle(item); // 未完成 → 完成
    expect((await repo.getById(created.id))!.done, isTrue);

    final item2 = TodoItem(
      id: item.id,
      source: TodoSource.schedule,
      text: item.text,
      done: true,
      dueDate: item.dueDate,
      time: item.time,
      scheduleId: created.id,
    );
    await service.toggle(item2); // 完成 → 未完成
    expect((await repo.getById(created.id))!.done, isFalse);
  });

  test('CRM 来源只读（返回 false，不改状态）', () async {
    final service = TodoToggleService();
    final item = TodoItem(
      id: 'crm:1',
      source: TodoSource.crmTask,
      text: 'x',
      done: false,
      time: DateTime.now(),
      twentyId: 't1',
    );
    expect(await service.toggle(item), isFalse);
  });
}
