import 'dart:async';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/attachments/attachment_manager.dart';
import 'package:moodiary/features/ai/colloquial/colloquial_detector.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 快速收集保存器：写入 Diary + Block（Block 协议），并持久化图片附件。
class QuickCaptureSaver {
  static Future<Diary> save({
    required String text,
    required List<QuickAttachment> attachments,
    String template = '',
  }) async {
    final now = DateTime.now();

    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = _deriveTitle(text)
      ..contentText = text
      ..type = DiaryType.markdown.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    if (template.isNotEmpty) {
      diary.tags.add(template);
    }

    // 图片附件走现有媒体管线（压缩保存到 image 目录）
    final images = attachments.where((a) => a.isImage).toList();
    final imageNameMap = <String, String>{};
    if (images.isNotEmpty) {
    imageNameMap.addAll(await MediaUtil.saveImages(
        imageFileList: images.map((a) => XFile(a.path)).toList(),
      ));
    // 内容中引用保存后的图片名（避免引用临时路径/编码名导致图片丢失）
    imageNameMap.forEach((tempPath, name) {
      diary.imageName.add(name);
    });
    }

    // 音频附件：复制到 audio 目录
    final audios = attachments
        .where((a) => a.type == QuickAttachmentType.audio)
        .toList();
    final audioNames = <String>[];
    for (final audio in audios) {
      final ext = p.extension(audio.path).isEmpty ? '.m4a' : p.extension(audio.path);
      final name = 'audio-${const Uuid().v7()}$ext';
      await File(audio.path).copy(FileUtil.getRealPath('audio', name));
      audioNames.add(name);
    }
    diary.audioName = audioNames;

    // 文档/其他附件：走 Obsidian 模式附件管线（Attachments/Documents/YYYY/MM）
    final documents = attachments
        .where(
          (a) =>
              a.type == QuickAttachmentType.document ||
              a.type == QuickAttachmentType.other,
        )
        .toList();
    final docRefs = <String>[];
    if (documents.isNotEmpty) {
      for (final doc in documents) {
        final rel = await AttachmentManager.saveFile(
          sourcePath: doc.path,
          category: 'documents',
        );
        docRefs.add(rel);
      }
    }

    diary.content = _buildContent(
      text,
      attachments,
      docRefs,
      audioNames,
      imageNameMap,
    );
    await IsarUtil.insertADiary(diary);

    // Block 协议：每条速记生成一个 text Block（数据层 P1.1 提供）
    final block = Block()
      ..diaryId = diary.id
      ..blockType = BlockType.text
      ..content = diary.content
      ..sortOrder = 0
      ..createdAt = now
      ..updatedAt = now;
    await IsarUtil.insertBlock(block);

    // 登记附件引用（metadata.json）
    for (final rel in docRefs) {
      await AttachmentManager.addReference(
        rel,
        diaryId: diary.id,
        blockId: block.id,
      );
    }

    // M1：提交 AI 自动标签/分类任务（异步，不阻塞保存）
    unawaited(
      AiTaskQueueWorker.instance.submitTask(
        type: 'auto_tag',
        refId: diary.id,
      ),
    );

    // P0 去口语化：仅当"口语特征明显"才入队（本地检测 0 token，不阻塞保存）
    final report = ColloquialDetector.analyze(text);
    if (report.shouldClean) {
      unawaited(
        AiTaskQueueWorker.instance.submitTask(
          type: 'de_colloquial',
          refId: diary.id,
        ),
      );
    }

    // P1 extract_plan：仅当命中待办/日程/CRM 信号词时触发（避免每条都跑大抽取）
    if (_looksExtractable(text)) {
      unawaited(
        AiTaskQueueWorker.instance.submitTask(
          type: 'extract_plan',
          refId: diary.id,
        ),
      );
    }

    return diary;
  }

  static bool _looksExtractable(String text) {
    const signals = [
      '待办',
      '提醒',
      '记得',
      '明天',
      '后天',
      '下周',
      '开会',
      '联系',
      '客户',
      '合同',
      '报价',
      '跟进',
      '拜访',
      '预约',
      '回款',
      '发票',
      '方案',
    ];
    return signals.any(text.contains);
  }

  static String _deriveTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '速记';
    if (trimmed.length <= 20) return trimmed;
    return '${trimmed.substring(0, 20)}…';
  }

  static String _buildContent(
    String text,
    List<QuickAttachment> attachments,
    List<String> docRefs,
    List<String> audioNames,
    Map<String, String> imageNameMap,
  ) {
    final buffer = StringBuffer(text.trim());
    var docIndex = 0;
    var audioIndex = 0;
    for (final attachment in attachments) {
      if (buffer.isNotEmpty) buffer.writeln();
      if (attachment.isImage) {
        buffer.write(
          '![](${imageNameMap[attachment.path] ?? p.basename(attachment.path)})',
        );
      } else if (attachment.type == QuickAttachmentType.audio) {
        final name = audioIndex < audioNames.length ? audioNames[audioIndex] : '';
        audioIndex++;
        buffer.write('🔊 [${attachment.name}]($name)');
      } else {
        final rel = docIndex < docRefs.length ? docRefs[docIndex] : '';
        docIndex++;
        buffer.write('- 📎 [${attachment.name}]($rel)');
      }
    }
    return buffer.toString();
  }
}
