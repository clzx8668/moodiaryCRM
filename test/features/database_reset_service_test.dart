import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/health/database_reset_service.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  test('清空所有表（日记/Block/日程/CRM）后计数为 0', () async {
    await IsarUtil.insertADiary(
      Diary()
        ..title = '测试'
        ..content = '正文'
        ..contentText = '正文'
        ..type = 'markdown',
    );
    await ScheduleRepository().create(
      Schedule()..title = '日程'..startTime = DateTime(2026, 9, 1, 10),
    );
    expect((await db.select(db.diaries).get()), hasLength(1));
    expect((await db.select(db.schedules).get()), hasLength(1));

    await DatabaseResetService.clearAllData(db: db);

    expect((await db.select(db.diaries).get()), isEmpty);
    expect((await db.select(db.schedules).get()), isEmpty);
    expect((await db.select(db.blocks).get()), isEmpty);
  });
}
