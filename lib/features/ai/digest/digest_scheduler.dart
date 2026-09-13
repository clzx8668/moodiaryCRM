import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/digest/digest_prompts.dart';
import 'package:moodiary/features/ai/digest/digest_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';

/// 回望自动生成调度：默认关闭，开启后在每天 21:00 后（周一含周报）自动生成一次。
///
/// - 纯判断函数（shouldRunDaily/shouldRunWeekly）可单测；
/// - 未配置 AI 或已存在当日/当周回望时跳过，避免重复与无谓消耗。
class DigestScheduler {
  DigestScheduler._();

  static const String prefKey = 'digestAutoEnabled';

  /// 自动生成的触发时刻（小时，24 制）。
  static const int autoHour = 21;

  static bool shouldRunDaily({
    required DateTime now,
    required int hour,
    required Iterable<String> existingTitles,
  }) {
    if (now.hour < hour) return false;
    final title = '每日回望 ${DigestService.label(DigestPeriod.daily, now)}';
    return !existingTitles.contains(title);
  }

  static bool shouldRunWeekly({
    required DateTime now,
    required int hour,
    required Iterable<String> existingTitles,
  }) {
    if (now.weekday != DateTime.monday) return false;
    if (now.hour < hour) return false;
    final title = '每周回望 ${DigestService.label(DigestPeriod.weekly, now)}';
    return !existingTitles.contains(title);
  }

  /// 启动/回前台时调用：按需自动生成回望（失败静默，不打扰用户）。
  static Future<void> checkAndRun() async {
    try {
      final enabled = PrefUtil.getValue<bool>(prefKey) ?? false;
      if (!enabled) return;
      final provider = await AiProviderFactory.loadLight();
      if (!provider.isConfigured) return;

      final now = DateTime.now();
      final all = await IsarUtil.getAllDiaries();
      final titles = all.map((d) => d.title).toList();
      if (shouldRunDaily(
        now: now,
        hour: autoHour,
        existingTitles: titles,
      )) {
        await DigestService.generateAndSave(DigestPeriod.daily);
      }
      if (shouldRunWeekly(
        now: now,
        hour: autoHour,
        existingTitles: titles,
      )) {
        await DigestService.generateAndSave(DigestPeriod.weekly);
      }
    } catch (_) {
      // 自动任务失败不打扰用户
    }
  }
}
