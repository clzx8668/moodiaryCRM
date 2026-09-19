import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_meta.dart';
import 'package:moodiary/features/ai/tasks/pending_content_service.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/voice/voice_record_meta.dart';

/// 语音笔记的转写状态。
enum VoiceNoteStatus {
  /// 已入库、转写任务还在后台跑（占位卡为 ⏳）
  transcribing,

  /// 转写失败（占位卡为 ⚠️，保留原因可重试）
  failed,

  /// 已有正文
  done,
}

/// 详情页顶部「录音原文 / 笔记内容」两态。
enum VoiceNoteTab { note, raw }

/// 含录音的笔记在详情页需要的数据视图（纯函数，便于单测）。
///
/// 一条语音笔记有三份内容：音频文件（Diary.audioName）、录音原文
/// （去口语化前 / 转写原始结果）、笔记内容（清洗稿，即卡片正文）。
class VoiceNoteInfo {
  /// 转写占位卡使用的 aiTemplate
  static const String transcribeTemplate = 'voice_transcribe';

  static const String pendingPrefix = PendingContentService.pendingPrefix;

  final String audioFile;
  final VoiceNoteStatus status;
  final String failureReason;
  final String rawText;
  final String noteText;

  /// 录音响度包络（0..1）：播放器按真实响度画波形并随进度高亮
  final List<double> waveform;

  const VoiceNoteInfo({
    required this.audioFile,
    required this.status,
    this.failureReason = '',
    this.rawText = '',
    this.noteText = '',
    this.waveform = const [],
  });

  /// 原文与正文有无差异（一致时不必显示两个 Tab）
  bool get hasDistinctRaw {
    final raw = rawText.trim();
    final note = noteText.trim();
    return raw.isNotEmpty && raw != note;
  }

  bool get hasText => rawText.trim().isNotEmpty || noteText.trim().isNotEmpty;

  /// 从日记 + 块列表提取；非语音笔记返回 null。
  static VoiceNoteInfo? from({
    required Diary diary,
    required List<Block> blocks,
  }) {
    final audio = diary.audioName.isNotEmpty ? diary.audioName.first : '';
    if (audio.trim().isEmpty) return null;

    final alive = blocks.where((b) => !b.isDeleted).toList();
    final aiCard = alive
        .where((b) => b.meta.aiTemplate == transcribeTemplate)
        .lastOrNull;
    final voiceBlock = alive
        .where((b) => b.meta.captureType == VoiceRecordMeta.sourceVoice)
        .lastOrNull;
    final sourceBlock =
        voiceBlock ?? alive.where((b) => !b.meta.isAi).lastOrNull;

    var status = VoiceNoteStatus.done;
    var failureReason = '';
    final aiText = (aiCard?.content ?? '').trim();
    if (aiCard != null && aiText.startsWith(pendingPrefix.trim())) {
      status = VoiceNoteStatus.transcribing;
    } else if (aiText.startsWith('⚠️')) {
      status = VoiceNoteStatus.failed;
      failureReason = _failureReasonOf(aiText);
    }

    final dc = sourceBlock == null ? null : DeColoquialMeta.read(sourceBlock);
    final vr = sourceBlock == null ? null : VoiceRecordMeta.read(sourceBlock);
    final transcript = status == VoiceNoteStatus.done ? aiText : '';

    final raw = _firstNonEmpty([
      dc?.original ?? '',
      vr?.rawTranscript ?? '',
      transcript,
      sourceBlock?.content ?? '',
      diary.contentText,
    ]);
    final note = _firstNonEmpty([
      if (dc != null && dc.changed) dc.cleaned,
      sourceBlock?.content ?? '',
      transcript,
      diary.contentText,
    ]);

    return VoiceNoteInfo(
      audioFile: audio,
      status: status,
      failureReason: failureReason,
      rawText: raw,
      noteText: note,
      waveform: vr?.waveform ?? const [],
    );
  }

  /// 从「⚠️ 处理未完成：原因\n（原始内容已保留…）」里取出原因。
  static String _failureReasonOf(String text) {
    var body = text.replaceFirst('⚠️', '').trim();
    if (body.startsWith('处理未完成：')) {
      body = body.substring('处理未完成：'.length);
    }
    final newline = body.indexOf('\n');
    if (newline >= 0) body = body.substring(0, newline);
    return body.trim();
  }

  static String _firstNonEmpty(List<String> values) {
    for (final v in values) {
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }
}
