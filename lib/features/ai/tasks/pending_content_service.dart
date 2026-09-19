import 'dart:async';
import 'dart:io';

import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/features/ai/ai_block_writer.dart';
import 'package:moodiary/features/ai/tasks/note_refresh_service.dart';
import 'package:moodiary/features/ai/voice/audio_transcribe_service.dart';
import 'package:moodiary/features/ai/voice/long_audio_transcribe_service.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/link_capture/link_capture_service.dart';
import 'package:moodiary/features/vision/vision_capture_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:uuid/uuid.dart';

/// 「先落地，异步处理」的统一实现（图片 / 链接 / 语音）。
///
/// 交互原则（用户要求）：采集动作**立刻落一条本地笔记**（含原始附件/来源），
/// 同时在 AI 生成区放一张「⏳ 处理中」占位卡并入队后台任务；
/// 处理完成后由 [PendingContentService] 把结果写回这张卡 —— 用户全程即时可交互，
/// 不会被网络或大模型耗时卡住。
class PendingContentService {
  PendingContentService._();

  /// 占位卡前缀（用于识别未完成的卡片）
  static const String pendingPrefix = '⏳ ';

  /// 图片：立即落「图片笔记」+ 占位卡 + `vision_ocr` 任务。
  static Future<Diary> savePhotoFast({
    required String imageName,
    String title = '图片笔记',
  }) async {
    final now = DateTime.now();
    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = title
      // 列表立即可读：后台转写完成前先显示"处理中"占位，避免空白卡片
      ..contentText = '⏳ 正在识别图片内容…'
      ..content = ''
      ..type = DiaryType.markdown.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    diary.imageName.add(imageName);
    await IsarUtil.insertADiary(diary);

    // 原始图片块（原文保留）
    await IsarUtil.insertBlock(
      Block()
        ..diaryId = diary.id
        ..blockType = BlockType.image
        ..content = imageName
        ..sortOrder = 0
        ..createdAt = now
        ..updatedAt = now
        ..meta = BlockMeta(
          source: BlockMeta.sourceInitial,
          captureType: 'photo',
          title: title,
        ),
    );

    await _createPendingBlock(
      diaryId: diary.id,
      template: 'vision_ocr',
      text: '$pendingPrefix正在识别图片内容，稍后自动整理成笔记…',
      sourceContent: '[图片] $imageName',
    );
    unawaited(
      AiTaskQueueWorker.instance.submitTask(
        type: AiTaskType.visionOcr,
        refId: diary.id,
        payload: imageName,
      ),
    );
    return diary;
  }

  /// 链接：立即落「待抓取」笔记（保留 URL）+ 占位卡 + `link_fetch` 任务。
  static Future<Diary> saveLinkFast(String url) async {
    final now = DateTime.now();
    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = url
      ..contentText = url
      ..content = '🔗 $url'
      ..type = DiaryType.markdown.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    await IsarUtil.insertADiary(diary);

    await IsarUtil.insertBlock(
      Block()
        ..diaryId = diary.id
        ..blockType = BlockType.text
        ..content = '🔗 $url'
        ..sortOrder = 0
        ..createdAt = now
        ..updatedAt = now
        ..meta = BlockMeta(
          source: BlockMeta.sourceInitial,
          captureType: 'link',
          sourceUrl: url,
        ),
    );

    await _createPendingBlock(
      diaryId: diary.id,
      template: 'link_fetch',
      text: '$pendingPrefix正在抓取链接正文，稍后自动补全…',
      sourceContent: url,
    );
    unawaited(
      AiTaskQueueWorker.instance.submitTask(
        type: AiTaskType.linkFetch,
        refId: diary.id,
        payload: url,
      ),
    );
    return diary;
  }

  /// 语音：立即落「语音笔记」（音频保真）+ 占位卡 + `voice_transcribe` 任务。
  static Future<Diary> saveVoiceFast({
    required String audioFileName,
    String title = '语音速记',
  }) async {
    final now = DateTime.now();
    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = title
      // 列表立即可读：后台转写完成前先显示"处理中"占位，避免空白卡片
      ..contentText = '⏳ 录音转写中…'
      ..content = ''
      ..type = DiaryType.markdown.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    diary.audioName = [audioFileName];
    await IsarUtil.insertADiary(diary);

    await IsarUtil.insertBlock(
      Block()
        ..diaryId = diary.id
        ..blockType = BlockType.text
        ..content = ''
        ..sortOrder = 0
        ..createdAt = now
        ..updatedAt = now
        ..meta = BlockMeta(
          source: BlockMeta.sourceInitial,
          captureType: 'voice',
        ),
    );
    await _createPendingBlock(
      diaryId: diary.id,
      template: 'voice_transcribe',
      text: '$pendingPrefix正在转写录音，稍后自动写入正文…',
      sourceContent: audioFileName,
    );
    unawaited(
      AiTaskQueueWorker.instance.submitTask(
        type: AiTaskType.voiceTranscribe,
        refId: diary.id,
        payload: audioFileName,
      ),
    );
    return diary;
  }

  /// 在 AI 生成区放一张「处理中」占位卡，返回该卡 id。
  static Future<String> _createPendingBlock({
    required String diaryId,
    required String template,
    required String text,
    String sourceContent = '',
  }) async {
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final sortOrder = blocks.isEmpty
        ? 0
        : blocks.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final now = DateTime.now();
    final block = Block()
      ..id = const Uuid().v7()
      ..diaryId = diaryId
      ..blockType = BlockType.text
      ..content = text
      ..sortOrder = sortOrder
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceAi,
        aiTemplate: template,
        sourceContent: sourceContent,
      );
    await IsarUtil.insertBlock(block);
    return block.id;
  }

  /// 把处理结果写回占位卡，并同步笔记标题/投影文本（后台任务调用）。
  static Future<void> applyResult({
    required String diaryId,
    required String template,
    required String text,
    String? title,
  }) async {
    // 同模板只保留最新一份（历史重复卡自动软删，见 AiBlockWriter）
    await AiBlockWriter.upsert(
      diaryId: diaryId,
      template: template,
      content: text,
    );
    final diary = await IsarUtil.getDiaryById(diaryId);
    if (diary == null) return;
    diary.contentText = text;
    diary.content = text;
    final t = (title ?? '').trim();
    if (t.isNotEmpty) diary.title = t;
    diary.lastModified = DateTime.now();
    await IsarUtil.updateADiary(oldDiary: diary, newDiary: diary);
    // 首页列表/已打开的详情页立即刷新：不必再「进详情页看一眼」才有内容
    await NoteRefreshService.afterWriteBack(diaryId);
  }

  /// 处理失败：把占位卡改成明确的失败提示（保留原因，不静默）。
  static Future<void> markFailed({
    required String diaryId,
    required String template,
    required String reason,
  }) async {
    await AiBlockWriter.upsert(
      diaryId: diaryId,
      template: template,
      content: '⚠️ 处理未完成：$reason\n（原始内容已保留，可稍后重试）',
    );
    // 列表卡片别一直停在"处理中"：同步写一句失败原因（详情页另有完整说明）
    final diary = await IsarUtil.getDiaryById(diaryId);
    if (diary != null && diary.contentText.trim().startsWith('⏳')) {
      diary
        ..contentText = '⚠️ 处理未完成：$reason'
        ..lastModified = DateTime.now();
      await IsarUtil.updateADiary(oldDiary: diary, newDiary: diary);
    }
    await NoteRefreshService.afterWriteBack(diaryId);
  }

  /// 重试：把占位卡改回「处理中」文案（随后由调用方重新入队任务）。
  static Future<bool> markPending({
    required String diaryId,
    required String template,
    required String text,
  }) async {
    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final target = blocks
        .where((b) => !b.isDeleted && b.meta.aiTemplate == template)
        .lastOrNull;
    if (target == null) return false;
    target.content = text;
    await IsarUtil.updateBlock(target);
    return true;
  }

  // ---- 后台处理实现（供 AiTaskQueueWorker 调用）----

  /// 图片 → 视觉整理
  static Future<void> processVision({
    required String diaryId,
    required String imageName,
  }) async {
    const template = 'vision_ocr';
    final path = FileUtil.getRealPath('image', imageName);
    if (!await File(path).exists()) {
      await markFailed(diaryId: diaryId, template: template, reason: '图片文件不存在');
      return;
    }
    final result = await VisionCaptureService.extractFile(path);
    if (result == null) {
      await markFailed(
        diaryId: diaryId,
        template: template,
        reason: '未配置视觉模型或识别失败（可在 设置 → AI 设置 配置）',
      );
      return;
    }
    await applyResult(
      diaryId: diaryId,
      template: template,
      text: result.markdown,
      title: result.title.isEmpty ? null : result.title,
    );
  }

  /// 链接 → 抓取正文
  static Future<void> processLink({
    required String diaryId,
    required String url,
  }) async {
    const template = 'link_fetch';
    final content = await LinkCaptureService.instance.capture(url);
    final text = _linkMarkdown(
      content.title,
      content.author,
      content.textContent,
      url,
    );
    await applyResult(
      diaryId: diaryId,
      template: template,
      text: text,
      title: content.title.isEmpty ? null : content.title,
    );
  }

  /// 语音 → 云端转写
  static Future<void> processTranscription({
    required String diaryId,
    required String audioFileName,
  }) async {
    const template = 'voice_transcribe';
    final path = FileUtil.getRealPath('audio', audioFileName);
    if (!await File(path).exists()) {
      await markFailed(diaryId: diaryId, template: template, reason: '录音文件不存在');
      return;
    }
    try {
      final result = await LongAudioTranscribeService.transcribe(path);
      await applyResult(
        diaryId: diaryId,
        template: template,
        text: result.text,
        title: result.text.length > 16
            ? '${result.text.substring(0, 16)}…'
            : result.text,
      );
    } on TranscribeException catch (e) {
      await markFailed(diaryId: diaryId, template: template, reason: e.message);
    }
  }

  static String _linkMarkdown(
    String title,
    String? author,
    String body,
    String url,
  ) {
    final buf = StringBuffer();
    if (title.isNotEmpty) buf.writeln('# $title');
    if (author != null && author.isNotEmpty) buf.writeln('> 来源：$author');
    if (body.isNotEmpty) buf.writeln(body);
    buf
      ..writeln()
      ..writeln('🔗 $url');
    return buf.toString().trim();
  }
}
