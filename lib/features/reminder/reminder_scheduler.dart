import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/reminder/reminder_engine.dart';
import 'package:moodiary/features/reminder/reminder_presenter.dart';
import 'package:moodiary/features/reminder/reminder_store.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/pref.dart';

/// 到点提醒调度：应用运行时低频轮询（默认 30 秒一次），命中即浮出提醒卡。
///
/// 边界（与产品约定一致）：
/// - 仅应用运行期间生效（系统级通知需新增依赖，另行排期）；
/// - 默认开启，可在「设置 → 工具 → 到点提醒」关闭；
/// - 失败静默，不影响主流程。
class ReminderScheduler {
  ReminderScheduler._();

  /// 开关 Pref 键（默认开）。
  static const String prefKey = 'reminderEnabled';

  /// 轮询间隔：够及时，也不至于频繁唤醒（一次检查只读两个小表）。
  static const Duration interval = Duration(seconds: 30);

  static Timer? _timer;
  static bool _checking = false;

  static bool get enabled => PrefUtil.getValue<bool>(prefKey) ?? true;

  /// 启动（首帧后调用）：立即检查一次，之后按 [interval] 轮询。
  static void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => checkAndRun());
    checkAndRun();
  }

  static Future<void> checkAndRun({DateTime? now}) async {
    if (_checking) return;
    _checking = true;
    try {
      if (!enabled) return;
      final schedules = await ScheduleRepository().listActive();
      List<LocalReminder> reminders = const [];
      try {
        reminders = await CrmLocalRepository().listReminders();
      } catch (_) {
        // CRM 未启用/未初始化时只做日程提醒
      }
      final plan = planReminders(
        now: now ?? DateTime.now(),
        schedules: schedules,
        crmReminders: reminders,
        state: ReminderStore.load(),
      );
      await ReminderStore.save(plan.state);
      if (plan.isEmpty) return;
      await ReminderPresenter.show(plan.hits);
    } catch (_) {
      // 提醒失败不打扰用户
    } finally {
      _checking = false;
    }
  }

  /// 测试接缝：停止轮询并复位状态。
  @visibleForTesting
  static void reset() {
    _timer?.cancel();
    _timer = null;
    _checking = false;
  }
}
