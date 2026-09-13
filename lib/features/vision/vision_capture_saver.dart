import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/vision/vision_capture_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:uuid/uuid.dart';

/// 图片速记落库：原图保留（initial image 块）+ 视觉整理文本落 AI 生成区。
class VisionCaptureSaver {
  VisionCaptureSaver._();

  /// 从本地图片路径保存；返回 null 表示视觉识别失败（由调用方提示）。
  static Future<Diary?> saveFromImagePath(String sourcePath) async {
    final imageNameMap = await MediaUtil.saveImages(
      imageFileList: [XFile(sourcePath)],
    );
    final name = imageNameMap[sourcePath];
    if (name == null || name.isEmpty) return null;
    // 用压缩后的本地图片做识别，避免超大 base64
    final localPath = FileUtil.getRealPath('image', name);
    final result = await VisionCaptureService.extractFile(localPath);
    if (result == null) return null;

    final now = DateTime.now();
    final title = result.title.isEmpty ? '图片笔记' : result.title;
    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = title
      ..contentText = result.markdown
      ..content = result.markdown
      ..type = DiaryType.markdown.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    diary.imageName.add(name);
    await IsarUtil.insertADiary(diary);

    // 原始图片块（原文保留）
    final imageBlock = Block()
      ..diaryId = diary.id
      ..blockType = BlockType.image
      ..content = name
      ..sortOrder = 0
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceInitial,
        captureType: 'photo',
        title: title,
      );
    await IsarUtil.insertBlock(imageBlock);

    // 视觉整理结果（AI 生成区）
    final aiBlock = Block()
      ..diaryId = diary.id
      ..blockType = BlockType.text
      ..content = result.markdown
      ..sortOrder = 1
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceAi,
        aiTemplate: 'vision_ocr',
        sourceContent: '[图片] $name',
      );
    await IsarUtil.insertBlock(aiBlock);

    unawaited(
      AiTaskQueueWorker.instance.submitTask(type: 'auto_tag', refId: diary.id),
    );
    return diary;
  }
}
