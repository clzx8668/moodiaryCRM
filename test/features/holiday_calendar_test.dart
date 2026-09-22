import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/calendar/calendar_repository.dart';
import 'package:moodiary/features/calendar/holiday_calendar.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = openTestDb();
  });
  tearDown(() => closeTestDb(db));

  const assetJson = '''
{"year":2026,"days":[
  {"date":"2026-10-01","name":"国庆节","holiday":true},
  {"date":"2026-10-10","name":"国庆节后补班","holiday":false}
]}''';

  AssetBundle fakeBundle() => _FakeBundle(assetJson);

  test('订阅：创建只读节假日日历 + 写入全天事件（含补班标记）', () async {
    final added = await HolidayCalendar.ensure(bundle: fakeBundle());
    expect(added, 2);

    final calendar = await CalendarRepository().getById(HolidayCalendar.calendarId);
    expect(calendar, isNotNull);
    expect(calendar!.name, '中国节假日');
    expect(calendar.source, 'china-holiday');
    expect(calendar.readOnly, isTrue, reason: '订阅日历应只读');

    final events = await ScheduleRepository().listActive();
    expect(events, hasLength(2));
    expect(events.every((e) => e.allDay), isTrue);
    expect(
      events.any((e) => e.title == '国庆节后补班（补班）' && e.tag == 'workday'),
      isTrue,
    );
    expect(events.first.calendarId, HolidayCalendar.calendarId);
  });

  test('幂等：重复订阅不会重复写事件', () async {
    expect(await HolidayCalendar.ensure(bundle: fakeBundle()), 2);
    expect(await HolidayCalendar.ensure(bundle: fakeBundle()), 0);
    expect(await ScheduleRepository().listActive(), hasLength(2));
  });

  test('用户隐藏/删除订阅后不再重复安装（保留用户选择）', () async {
    await HolidayCalendar.ensure(bundle: fakeBundle());
    await CalendarRepository().softDelete(HolidayCalendar.calendarId);
    // 已删除 → 视为用户主动退订，不再自动装回来
    expect(await HolidayCalendar.ensure(bundle: fakeBundle()), 0);
  });
}

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.raw);
  final String raw;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(raw));
    return ByteData.view(bytes.buffer);
  }
}
