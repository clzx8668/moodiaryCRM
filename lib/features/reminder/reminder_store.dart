import 'dart:convert';

import 'package:moodiary/features/reminder/reminder_engine.dart';
import 'package:moodiary/persistence/pref.dart';

/// 提醒状态持久化：单键 JSON（已提醒 + 延后中），不新增 Drift 表。
class ReminderStore {
  ReminderStore._();

  static const String statePrefKey = 'reminderState';

  /// 默认延后时长（「稍后 10 分钟」）。
  static const Duration snoozeDelay = Duration(minutes: 10);

  static ReminderState load() {
    final raw = PrefUtil.getValue<String>(statePrefKey) ?? '';
    if (raw.isEmpty) return ReminderState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ReminderState.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // 损坏数据按空状态处理
    }
    return ReminderState();
  }

  static Future<void> save(ReminderState state) async {
    await PrefUtil.setValue<String>(statePrefKey, jsonEncode(state.toJson()));
  }

  /// 把若干提醒键标记为「延后到 now + delay」。
  static Future<void> snoozeKeys(
    Iterable<String> keys, {
    DateTime? now,
    Duration delay = snoozeDelay,
  }) async {
    final state = load();
    final until = (now ?? DateTime.now()).add(delay);
    for (final key in keys) {
      state.snoozeUntil(key, until);
    }
    await save(state);
  }
}
