import 'dart:io';

import 'package:dio/dio.dart';
import 'package:moodiary/features/ai/voice/audio_transcribe_service.dart';
import 'package:moodiary/features/ai/voice/wav_splitter.dart';
import 'package:path/path.dart' as p;

/// 长录音转写进度。
class LongTranscribeProgress {
  const LongTranscribeProgress({required this.done, required this.total});

  final int done;
  final int total;

  String get label => total <= 1 ? '转写中' : '转写中 $done/$total';

  @override
  String toString() => label;
}

/// 长录音转写结果。
class LongTranscribeResult {
  const LongTranscribeResult({
    required this.text,
    required this.parts,
    required this.chunked,
  });

  final String text;
  final List<String> parts;

  /// 是否走了切片（长录音）。
  final bool chunked;

  int get chunkCount => parts.length;
}

/// 分段转写结果的合并（纯函数）。
class TranscriptMerger {
  TranscriptMerger._();

  /// 按段落拼接：去空白、丢弃空段与紧邻重复段（模型偶发整段复读）。
  static String merge(List<String> parts) {
    final merged = <String>[];
    for (final raw in parts) {
      final text = raw.trim();
      if (text.isEmpty) continue;
      if (merged.isNotEmpty && merged.last == text) continue;
      merged.add(text);
    }
    return merged.join('\n');
  }
}

/// 长录音转写：把大文件切成小段逐段识别后合并。
///
/// - 可切分的 WAV（PCM/float）按 [maxChunkBytes] 切段，切点优先落在静音处；
/// - 其余格式（m4a/mp3 等无本地解码器）不切分，仍走单发；超过体积上限时由
///   [AudioTranscribeService] 给出明确提示。
class LongAudioTranscribeService {
  LongAudioTranscribeService._();

  /// 单片目标体积：Base64 后约 5.3MB，稳妥落在接口体积限制内。
  static const int maxChunkBytes = 4 * 1024 * 1024;

  /// 单片数上限（防止异常超长文件把额度耗光）：
  /// 44.1kHz 单声道 WAV 约 1.5 小时，16kHz 约 4 小时。
  static const int maxChunks = 240;

  static Future<LongTranscribeResult> transcribe(
    String audioPath, {
    Dio? dio,
    VoiceEndpoint? endpointOverride,
    void Function(LongTranscribeProgress progress)? onProgress,
    int chunkBytes = maxChunkBytes,
    int maxChunkCount = maxChunks,
    Directory? tempDir,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const TranscribeException('音频文件不存在');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const TranscribeException('音频文件为空');

    final format = WavSplitter.parse(bytes);
    final splittable =
        format != null && format.isSplittable && format.dataSize > chunkBytes;
    if (!splittable) {
      final single = await AudioTranscribeService.transcribeFile(
        audioPath,
        dio: dio,
        endpointOverride: endpointOverride,
      );
      onProgress?.call(const LongTranscribeProgress(done: 1, total: 1));
      return LongTranscribeResult(
        text: single.text,
        parts: [single.text],
        chunked: false,
      );
    }

    final chunks = WavSplitter.plan(
      format,
      maxBytesPerChunk: chunkBytes,
      pcm: bytes,
    );
    if (chunks.isEmpty) {
      throw const TranscribeException('音频切片失败：文件结构不受支持');
    }
    if (chunks.length > maxChunkCount) {
      throw TranscribeException(
        '录音过长（约 ${_durationLabel(format.duration)}，需 ${chunks.length} 段）：'
        '单次上限 $maxChunkCount 段，请先拆分文件',
      );
    }

    final dir = tempDir ?? await Directory.systemTemp.createTemp('moodiary_asr_');
    final parts = <String>[];
    try {
      for (var i = 0; i < chunks.length; i++) {
        final chunkPath = p.join(
          dir.path,
          'chunk_${i.toString().padLeft(3, '0')}.wav',
        );
        final chunkFile = File(chunkPath);
        await chunkFile.writeAsBytes(
          WavSplitter.extract(bytes, format, chunks[i]),
          flush: true,
        );
        try {
          final part = await AudioTranscribeService.transcribeFile(
            chunkPath,
            dio: dio,
            endpointOverride: endpointOverride,
          );
          parts.add(part.text);
        } finally {
          try {
            await chunkFile.delete();
          } catch (_) {
            // 临时文件清理失败不影响转写结果
          }
        }
        onProgress?.call(
          LongTranscribeProgress(done: i + 1, total: chunks.length),
        );
      }
    } finally {
      if (tempDir == null) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // 忽略清理失败
        }
      }
    }

    return LongTranscribeResult(
      text: TranscriptMerger.merge(parts),
      parts: parts,
      chunked: true,
    );
  }

  static String _durationLabel(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours} 小时 ${d.inMinutes.remainder(60)} 分钟';
    }
    if (d.inMinutes > 0) return '${d.inMinutes} 分钟';
    return '${d.inSeconds} 秒';
  }
}
