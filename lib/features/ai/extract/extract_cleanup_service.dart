import 'package:moodiary/features/ai/extract/ai_extract_meta.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';

/// 抽取结果双向联动（a）：删除日记/块时级联清理其产生的日程，避免孤儿数据。
class ExtractCleanupService {
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  /// 删除某块后：软删该块 `aiExtract` 生成的日程。
  Future<void> onBlockDeleted(Block block) async {
    final meta = AiExtractMeta.read(block);
    if (meta == null) return;
    for (final id in meta.scheduleIds) {
      await _scheduleRepo.softDelete(id);
    }
  }

  /// 删除某日记后：软删所有 `linkedDiaryId` 指向它的日程。
  Future<void> onDiaryDeleted(String diaryId) async {
    final active = await _scheduleRepo.listActive();
    for (final s in active) {
      if (s.linkedDiaryId == diaryId) {
        await _scheduleRepo.softDelete(s.id);
      }
    }
  }
}
