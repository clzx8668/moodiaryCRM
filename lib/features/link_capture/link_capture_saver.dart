import 'dart:async';

import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/link_capture/captured_content.dart';
import 'package:moodiary/features/link_capture/link_capture_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 链接采集落库器：把 CapturedContent 保存为「Diary + 原始 text Block」。
///
/// - 原文（标题/正文/来源）保留在原始块，meta 记录 `captureType=link` 与 `sourceUrl`；
/// - AI 摘要/标签/抽取走既有无队列（不阻塞保存），不做原位改写（对齐批次 36 架构）。
class LinkCaptureSaver {
  LinkCaptureSaver._();

  static Future<Diary> saveFromUrl(String url) async {
    final content = await LinkCaptureService.instance.capture(url);
    return save(content);
  }

  static Future<Diary> save(CapturedContent content) async {
    final now = DateTime.now();
    final title = content.title.isEmpty ? content.url : content.title;

    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = title
      ..contentText = content.textContent
      ..content = _buildContent(content)
      ..type = DiaryType.markdown.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    if (content.author != null && content.author!.isNotEmpty) {
      diary.tags.add('来源 ${content.author}');
    }
    await IsarUtil.insertADiary(diary);

    final block = Block()
      ..diaryId = diary.id
      ..blockType = BlockType.text
      ..content = diary.content
      ..sortOrder = 0
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceInitial,
        captureType: 'link',
        sourceUrl: content.url,
      );
    await IsarUtil.insertBlock(block);

    // 复用既有 AI 队列：标签/分类与结构化抽取（异步，不阻塞）
    unawaited(
      AiTaskQueueWorker.instance.submitTask(type: 'auto_tag', refId: diary.id),
    );
    unawaited(
      AiTaskQueueWorker.instance.submitTask(
        type: 'extract_plan',
        refId: diary.id,
      ),
    );
    return diary;
  }

  static String _buildContent(CapturedContent c) {
    final buf = StringBuffer();
    if (c.title.isNotEmpty) buf.writeln('# ${c.title}');
    if (c.author != null && c.author!.isNotEmpty) {
      buf.writeln('> 来源：${c.author}');
    }
    if (c.textContent.isNotEmpty) buf.writeln(c.textContent);
    buf.writeln();
    buf.writeln('🔗 ${c.url}');
    return buf.toString();
  }
}
