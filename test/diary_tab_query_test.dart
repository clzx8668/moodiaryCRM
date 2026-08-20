import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import 'helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDb();
  });

  tearDown(() {
    closeTestDb(db);
  });

  test('getDiaryByCategory 返回最新插入的记录', () async {
    final oldDiary = Diary()
      ..id = 'old-1'
      ..title = '旧记录'
      ..contentText = '旧'
      ..type = 'markdown'
      ..time = DateTime(2026, 1, 1)
      ..lastModified = DateTime(2026, 1, 1)
      ..show = true;
    await IsarUtil.insertADiary(oldDiary);

    // 模拟快速收集：新记录 time = now
    final newDiary = Diary()
      ..id = 'new-1'
      ..title = '新记录'
      ..contentText = '新'
      ..type = 'markdown'
      ..time = DateTime.now()
      ..lastModified = DateTime.now()
      ..show = true;
    await IsarUtil.insertADiary(newDiary);

    final list = await IsarUtil.getDiaryByCategory(null, 0, 20);

    expect(list.length, 2);
    expect(list.first.id, 'new-1', reason: '新记录应按时间倒序排在首位');
  });
}
