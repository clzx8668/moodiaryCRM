import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 把 AI 回答落地为笔记（新建 Diary + text Block，保持双模态一致性）。
class AiNoteSaver {
  AiNoteSaver._();

  static Future<Diary> save(
    String content, {
    List<String> tags = const ['AI'],
  }) async {
    final now = DateTime.now();
    final trimmed = content.trim();
    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = _title(trimmed)
      ..content = trimmed
      ..contentText = trimmed.replaceAll(RegExp(r'\s+'), ' ')
      ..type = 'markdown'
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5
      ..tags = List<String>.from(tags);

    await IsarUtil.insertADiary(diary);
    await IsarUtil.insertBlock(
      Block()
        ..diaryId = diary.id
        ..blockType = BlockType.text
        ..content = trimmed
        ..sortOrder = 0
        ..createdAt = now
        ..updatedAt = now
        ..meta = BlockMeta(
          source: BlockMeta.sourceAi,
          title: diary.title,
        ),
    );
    // 双模态聚合投影刷新（content/contentText 与 Block 保持一致）
    await IsarUtil.refreshDiaryProjection(diary);
    return diary;
  }

  static String _title(String content) {
    final firstLine = content.split('\n').firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    final clean = firstLine
        .replaceAll(RegExp(r'^#+\s*'), '')
        .replaceAll(RegExp(r'^[-*]\s*'), '')
        .trim();
    if (clean.isEmpty) return 'AI 笔记';
    return clean.length <= 20 ? clean : '${clean.substring(0, 20)}…';
  }
}
