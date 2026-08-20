import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';

/// 时间轴条目：日记 或 CRM 记录（架构文档"二、2. 时间轴视图"）
class TimelineItem {
  final DateTime time;
  final Diary? diary;
  final CrmEntityCache? crm;

  const TimelineItem({required this.time, this.diary, this.crm});

  bool get isDiary => diary != null;

  bool get isCrm => crm != null;

  String get title {
    if (diary != null) {
      return diary!.title.isEmpty ? '未命名日记' : diary!.title;
    }
    return crm?.name ?? '';
  }
}
