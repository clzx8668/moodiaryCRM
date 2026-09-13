import 'package:get/get.dart';
import 'package:moodiary/features/feed/feed_models.dart';
import 'package:moodiary/features/feed/feed_parser.dart';
import 'package:moodiary/features/feed/feed_saver.dart';
import 'package:moodiary/features/feed/feed_service.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/persistence/pref.dart';

/// 订阅自动刷新调度：默认关闭；启动/回前台时对「到期」的启用源做低频拉取。
///
/// - 纯判断 `isDue` 可单测；单源失败只记录 `lastError`，不打扰用户；
/// - 默认间隔 6 小时，每源每轮最多 10 条（沿用 FeedService）。
class FeedScheduler {
  FeedScheduler._();

  static const String prefKey = 'feedAutoRefreshEnabled';
  static const Duration minInterval = Duration(hours: 6);

  /// 是否到期需要刷新（启用 + 从未刷新或超过间隔）。
  static bool isDue(
    FeedSource source,
    DateTime now, {
    Duration interval = minInterval,
  }) {
    if (!source.enabled) return false;
    if (source.lastFetchedAt <= 0) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(source.lastFetchedAt);
    return now.difference(last) >= interval;
  }

  /// 启动/回前台调用：按需刷新到期订阅源（失败静默）。
  static Future<void> checkAndRun() async {
    try {
      final enabled = PrefUtil.getValue<bool>(prefKey) ?? false;
      if (!enabled) return;
      final sources = FeedService.loadSources();
      if (sources.isEmpty) return;
      final now = DateTime.now();
      var changed = false;
      for (final source in sources) {
        if (!isDue(source, now)) continue;
        final result = await FeedService.fetch(source);
        if (!result.ok) {
          source.lastError = result.error ?? '拉取失败';
          changed = true;
          continue;
        }
        final keys = <String>[];
        for (final item in result.items) {
          try {
            await FeedSaver.save(source: source, item: item);
            keys.add(FeedParser.itemKey(item));
          } catch (_) {
            // 单条失败不中断
          }
        }
        source.lastItemKeys = FeedService.updatedKeys(source.lastItemKeys, keys);
        source.lastFetchedAt = DateTime.now().millisecondsSinceEpoch;
        source.lastError = '';
        changed = true;
      }
      if (changed) {
        await FeedService.saveSources(sources);
        if (Get.isRegistered<HomeLogic>()) {
          await Get.find<HomeLogic>().refreshDiaryLists();
        }
      }
    } catch (_) {
      // 自动任务失败不打扰用户
    }
  }
}
