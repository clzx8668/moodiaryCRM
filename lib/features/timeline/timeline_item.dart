import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';

/// 时间轴条目：日记、CRM 记录或日程（架构文档"二、2. 时间轴视图"）
class TimelineItem {
  final DateTime time;
  final Diary? diary;
  final CrmEntityCache? crm;
  final Schedule? schedule;

  const TimelineItem({required this.time, this.diary, this.crm, this.schedule});

  bool get isDiary => diary != null;

  bool get isCrm => crm != null;

  bool get isSchedule => schedule != null;

  String get title {
    if (diary != null) {
      return diary!.title.isEmpty ? '未命名日记' : diary!.title;
    }
    if (schedule != null) return schedule!.title;
    return crm?.name ?? '';
  }
}
