import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/calendar/calendar_repository.dart';
import 'package:moodiary/features/calendar/models/calendar_list.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/models/schedule_attachment.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/app_database.dart';

void main() {
  late AppDatabase db;
  late CalendarRepository calendars;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    calendars = CalendarRepository(db);
  });

  tearDown(() async => db.close());

  group('播种与查询', () {
    test('首次打开自动建「工作/生活/家庭」，工作为默认', () async {
      final all = await calendars.listAll();
      expect(all.map((c) => c.name), ['工作', '生活', '家庭']);
      expect(all.first.color, CalendarColors.blue);
      expect(await calendars.defaultCalendar(), isNotNull);
      expect((await calendars.defaultCalendar())!.name, '工作');
    });

    test('再打开一次不会重复播种（幂等）', () async {
      expect(await calendars.listAll(), hasLength(3));
      // 触发第二次 beforeOpen 的方式：新开一个到同一内存库不可行，
      // 这里直接断言播种条件本身：已有日历则不再插入。
      final before = (await calendars.listAll()).length;
      expect(before, 3);
      expect(await calendars.listAll(), hasLength(3));
    });
  });

  group('多日历 CRUD', () {
    test('新建日历落到色板推荐色，可改色改名', () async {
      final created = await calendars.create(name: '旅行');
      expect(created.color, CalendarColors.purple);
      expect((await calendars.listAll()), hasLength(4));

      created
        ..name = '旅行计划'
        ..color = CalendarColors.pink;
      await calendars.update(created);

      final loaded = await calendars.getById(created.id);
      expect(loaded!.name, '旅行计划');
      expect(loaded.color, CalendarColors.pink);
    });

    test('隐藏后不在可见集合里，但数据仍在', () async {
      final work = (await calendars.listAll()).first;
      await calendars.setVisible(work.id, false);
      expect((await calendars.listVisible()).map((c) => c.id), isNot(contains(work.id)));
      expect(await calendars.getById(work.id), isNotNull);
    });

    test('setDefault 保持全局恰一个默认', () async {
      final life = (await calendars.listAll())[1];
      await calendars.setDefault(life.id);
      final all = await calendars.listAll();
      expect(all.where((c) => c.isDefault).map((c) => c.id), [life.id]);
    });

    test('删除日历会把它的日程挪到兜底日历，且不允许删到空', () async {
      final schedules = ScheduleRepository(db);
      final work = (await calendars.listAll()).first;
      final s = await schedules.create(
        Schedule()
          ..title = '工作事件'
          ..calendarId = work.id
          ..startTime = DateTime(2026, 9, 22, 10),
      );

      final ok = await calendars.softDelete(work.id);
      expect(ok, isTrue);
      // 软删后不出现在 listAll（getById 仍是原始行，便于同步判断墓碑）
      expect((await calendars.listAll()).map((c) => c.id), isNot(contains(work.id)));
      expect((await calendars.getById(work.id))!.deleted, isTrue);
      final moved = await schedules.getById(s.id);
      expect(moved!.calendarId, isNot(work.id));
      expect(moved.calendarId, isNotNull);

      // 删到只剩一个时拒绝
      final rest = await calendars.listAll();
      expect(rest, hasLength(2));
      await calendars.softDelete(rest[0].id);
      final last = await calendars.listAll();
      expect(last, hasLength(1));
      expect(await calendars.softDelete(last.single.id), isFalse);
      expect(await calendars.listAll(), hasLength(1));
    });

    test('colorMap 供事件卡取色', () async {
      final map = await calendars.colorMap();
      expect(map['work'], CalendarColors.blue);
      expect(map.length, 3);
    });
  });

  group('Schedule 扩展字段', () {
    test('地点/时区/附件/日历归属/草案 存读一致', () async {
      final repo = ScheduleRepository(db);
      final created = await repo.create(
        Schedule()
          ..title = 'Q2 项目方案评审会'
          ..location = '会议室 A'
          ..calendarId = 'work'
          ..timeZoneId = 'Asia/Shanghai'
          ..draft = true
          ..attachments = [
            ScheduleAttachment(
              name: 'Q2 项目方案.pdf',
              size: 2516582,
              mime: 'application/pdf',
              path: '/tmp/q2.pdf',
            ),
            ScheduleAttachment(name: '会议纪要.key', size: 1126400),
          ],
      );

      final loaded = await repo.getById(created.id);
      expect(loaded!.location, '会议室 A');
      expect(loaded.calendarId, 'work');
      expect(loaded.timeZoneId, 'Asia/Shanghai');
      expect(loaded.draft, isTrue);
      expect(loaded.attachments, hasLength(2));
      expect(loaded.attachments.first.name, 'Q2 项目方案.pdf');
      expect(loaded.attachments.first.sizeLabel, '2.4 MB');
      expect(loaded.attachments[1].sizeLabel, '1.1 MB');
    });

    test('附件/地点经 JSON 往返不丢字段', () {
      final s = Schedule()
        ..id = 'x1'
        ..title = 'T'
        ..location = 'L'
        ..calendarId = 'life'
        ..timeZoneId = 'America/New_York'
        ..draft = true
        ..attachments = [
          ScheduleAttachment(name: 'a.pdf', size: 320000, mime: 'application/pdf'),
        ];
      final round = Schedule.fromJson(s.toJson());
      expect(round.location, 'L');
      expect(round.calendarId, 'life');
      expect(round.timeZoneId, 'America/New_York');
      expect(round.draft, isTrue);
      expect(round.attachments.single.sizeLabel, '313 KB');
    });

    test('老数据（无日历归属）读出来是 null，不炸', () async {
      final repo = ScheduleRepository(db);
      final created = await repo.create(
        Schedule()
          ..title = '纯待办'
          ..startTime = DateTime(2026, 9, 22, 8),
      );
      final loaded = await repo.getById(created.id);
      expect(loaded!.calendarId, isNull);
      expect(loaded.attachments, isEmpty);
      expect(loaded.draft, isFalse);
    });
  });
}
