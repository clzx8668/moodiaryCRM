import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/reminder/reminder_scheduler.dart';
import 'package:moodiary/features/reminder/reminder_store.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 提醒调度的接线验证：真实（内存）数据库 → 引擎 → 状态落 Pref。
///
/// 测试环境无 UI 上下文，提醒卡自动跳过，因此只校验「命中 + 落状态」这一段。
void main() {
  late AppDatabase db;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PrefUtil.prefAllowList,
      ),
    );
    PrefUtil.overridePrefsForTest(prefs);
    db = AppDatabase(NativeDatabase.memory());
    IsarUtil.overrideDbForTest(db);
    ReminderScheduler.reset();
  });

  tearDown(() async {
    ReminderScheduler.reset();
    IsarUtil.restoreDbForTest();
    await db.close();
  });

  test('到点日程：命中一次并写入已提醒状态', () async {
    await PrefUtil.setValue(ReminderScheduler.prefKey, true);
    await ScheduleRepository(db).create(
      Schedule()
        ..title = '给李总回电'
        ..startTime = DateTime.now()
        ..remindOffsetMin = 0,
    );

    await ReminderScheduler.checkAndRun();

    final state = ReminderStore.load();
    expect(state.fired, hasLength(1));
    expect(state.fired.keys.first, startsWith('schedule:'));

    // 再跑一次不重复提醒
    await ReminderScheduler.checkAndRun();
    expect(ReminderStore.load().fired, hasLength(1));
  });

  test('开关关闭时不提醒', () async {
    await PrefUtil.setValue(ReminderScheduler.prefKey, false);
    await ScheduleRepository(db).create(
      Schedule()
        ..title = '给李总回电'
        ..startTime = DateTime.now()
        ..remindOffsetMin = 0,
    );

    await ReminderScheduler.checkAndRun();

    expect(ReminderStore.load().fired, isEmpty);
  });

  test('CRM 提醒到点同样命中', () async {
    await PrefUtil.setValue(ReminderScheduler.prefKey, true);
    await CrmLocalRepository(db).createReminder(
      LocalReminder(
        id: '',
        type: 'paymentDue',
        title: '合同回款',
        remindAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    );

    await ReminderScheduler.checkAndRun();

    final state = ReminderStore.load();
    expect(state.fired, hasLength(1));
    expect(state.fired.keys.first, startsWith('crm:'));
  });

  test('状态可跨轮次持久化（延后 → 期满补提醒）', () async {
    await PrefUtil.setValue(ReminderScheduler.prefKey, true);
    final repo = ScheduleRepository(db);
    await repo.create(
      Schedule()
        ..title = '客户回访'
        ..startTime = DateTime.now()
        ..remindOffsetMin = 0,
    );

    await ReminderScheduler.checkAndRun();
    final firstKey = ReminderStore.load().fired.keys.first;

    await ReminderStore.snoozeKeys([firstKey]);
    final snoozed = ReminderStore.load();
    expect(snoozed.fired, isEmpty);
    expect(snoozed.snoozed.keys, [firstKey]);
  });
}
