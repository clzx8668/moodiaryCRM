import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/todo/todo_aggregator.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  test('抽取生成的 Schedule 会出现在日历待办聚合（按日期）', () async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final s = await ScheduleRepository().create(
      Schedule()
        ..title = '明天开会'
        ..startTime = day.add(const Duration(hours: 9))
        ..linkedDiaryId = 'd1',
    );

    final items = await TodoAggregator.load(date: day);
    expect(items.any((e) => e.isSchedule && e.scheduleId == s.id), isTrue);
    expect(items.where((e) => e.isSchedule).length, 1);
  });
}
