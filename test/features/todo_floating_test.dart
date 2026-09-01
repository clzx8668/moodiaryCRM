import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/todo/todo_aggregator.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final yesterday = today.subtract(const Duration(days: 1));

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  test('今日收件箱聚合所有未完成（含浮动/未来/过期），其它日仅当日且排除浮动', () async {
    final repo = ScheduleRepository();
    await repo.create(
      Schedule()
        ..title = '浮动待办'
        ..startTime = today
        ..floating = true
        ..priority = SchedulePriority.high,
    );
    await repo.create(Schedule()..title = '今天日程'..startTime = today.add(const Duration(hours: 9)));
    await repo.create(Schedule()..title = '明天日程'..startTime = tomorrow.add(const Duration(hours: 9)));
    await repo.create(Schedule()..title = '昨天过期'..startTime = yesterday.add(const Duration(hours: 9)));
    await repo.create(
      Schedule()
        ..title = '已办'
        ..startTime = today.add(const Duration(hours: 10))
        ..done = true,
    );

    // 今日收件箱
    final todayItems = await TodoAggregator.load(date: today);
    expect(todayItems.any((e) => e.text == '浮动待办' && e.isFloating), isTrue);
    expect(todayItems.any((e) => e.text == '明天日程'), isTrue);
    expect(todayItems.any((e) => e.text == '昨天过期' && e.isOverdue), isTrue);
    expect(todayItems.any((e) => e.text == '已办'), isFalse); // 未完成才聚合

    // 指定"明天"＝仅当日，排除浮动
    final tomorrowItems = await TodoAggregator.load(date: tomorrow);
    expect(tomorrowItems.any((e) => e.text == '明天日程'), isTrue);
    expect(tomorrowItems.any((e) => e.text == '浮动待办'), isFalse);
  });
}
