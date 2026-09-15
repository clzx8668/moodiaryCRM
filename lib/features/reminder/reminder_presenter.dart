import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/crm/crm_home_page.dart';
import 'package:moodiary/features/reminder/reminder_engine.dart';
import 'package:moodiary/features/reminder/reminder_store.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/schedule/views/schedule_detail_page.dart';

/// 到点提醒的呈现层：底部浮出提醒卡（多条合并），支持稍后提醒 / 跳转。
///
/// 与引擎分离，便于在无 UI 上下文（测试/后台）时安全跳过。
class ReminderPresenter {
  ReminderPresenter._();

  /// 卡片自动消失时间（不打扰原则：不点也会自己退场）。
  static const Duration displayTime = Duration(seconds: 20);

  static bool get _hasUiContext {
    try {
      return Get.context != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> show(List<ReminderHit> hits) async {
    if (hits.isEmpty || !_hasUiContext) return;
    await SmartDialog.show(
      alignment: Alignment.bottomCenter,
      animationType: SmartAnimationType.centerFade_otherSlide,
      displayTime: displayTime,
      clickMaskDismiss: true,
      usePenetrate: true,
      backType: SmartBackType.ignore,
      debounce: true,
      maskColor: Colors.transparent,
      builder: (context) => _ReminderCard(hits: hits),
    );
  }

  /// 稍后提醒：全部延后 [delay]，随后关闭卡片。
  static Future<void> snooze(
    List<ReminderHit> hits, {
    Duration delay = ReminderStore.snoozeDelay,
  }) async {
    await ReminderStore.snoozeKeys(hits.map((h) => h.key), delay: delay);
  }

  /// 打开关联对象：日程 → 日程详情页；CRM 提醒 → CRM 首页。
  static Future<void> open(ReminderHit hit) async {
    await SmartDialog.dismiss();
    if (hit.source == ReminderSource.schedule) {
      final schedule = await ScheduleRepository().getById(hit.refId);
      if (schedule == null) return;
      await Get.to<bool>(() => ScheduleDetailPage(editable: schedule));
      return;
    }
    await Get.to(() => const CrmHomePage());
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.hits});

  final List<ReminderHit> hits;

  static const int _maxRows = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final single = hits.length == 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.alarm_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      single ? '提醒' : '${hits.length} 条提醒',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...hits.take(_maxRows).map(
                (hit) => InkWell(
                  onTap: () => ReminderPresenter.open(hit),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hit.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hit.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (hits.length > _maxRows)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '还有 ${hits.length - _maxRows} 条…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      ReminderPresenter.snooze(hits);
                      SmartDialog.dismiss();
                    },
                    child: const Text('稍后 10 分钟'),
                  ),
                  if (single)
                    TextButton(
                      onPressed: () {
                        SmartDialog.dismiss();
                        ReminderPresenter.open(hits.first);
                      },
                      child: const Text('查看'),
                    ),
                  FilledButton(
                    onPressed: () => SmartDialog.dismiss(),
                    child: const Text('知道了'),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
