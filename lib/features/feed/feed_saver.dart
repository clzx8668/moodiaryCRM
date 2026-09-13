import 'dart:async';

import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/feed/feed_models.dart';
import 'package:moodiary/features/feed/feed_parser.dart';
import 'package:moodiary/features/feed/feed_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 订阅条目录库：原文（标题/正文/来源）保真，落 Diary + 原始 text Block。
class FeedSaver {
  FeedSaver._();

  static Future<Diary> save({
    required FeedSource source,
    required FeedItem item,
  }) async {
    final now = DateTime.now();
    final title = item.title.trim().isEmpty ? item.link : item.title.trim();
    final body = item.body.trim().isNotEmpty
        ? item.body.trim()
        : item.summary.trim();

    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = title
      ..contentText = body
      ..content = buildContent(source, item, body)
      ..type = DiaryType.markdown.value
      ..time = item.publishedAt?.toLocal() ?? now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    diary.tags.add('订阅');
    if (source.displayName.isNotEmpty) {
      diary.tags.add(source.displayName);
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
        captureType: 'feed',
        sourceUrl: item.link,
        title: title,
        feedId: source.id,
        feedItemKey: FeedParser.itemKey(item),
        knowledgeBaseIds: FeedService.targetKnowledgeBaseId(),
      );
    await IsarUtil.insertBlock(block);

    unawaited(
      AiTaskQueueWorker.instance.submitTask(type: 'auto_tag', refId: diary.id),
    );
    return diary;
  }

  /// 组装 Markdown 原文（标题 / 来源 / 正文 / 链接）。
  static String buildContent(FeedSource source, FeedItem item, String body) {
    final buf = StringBuffer();
    if (item.title.trim().isNotEmpty) buf.writeln('# ${item.title.trim()}');
    final meta = <String>[
      if (item.author.trim().isNotEmpty) item.author.trim(),
      if (item.publishedAt != null)
        item.publishedAt!.toLocal().toString().split(' ').first,
      if (source.displayName.isNotEmpty) source.displayName,
    ];
    if (meta.isNotEmpty) buf.writeln('> 来源：${meta.join(' · ')}');
    if (body.isNotEmpty) {
      buf.writeln();
      buf.writeln(body);
    }
    if (item.link.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('🔗 ${item.link.trim()}');
    }
    return buf.toString().trimRight();
  }
}
