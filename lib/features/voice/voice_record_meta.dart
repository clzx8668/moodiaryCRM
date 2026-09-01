import 'dart:convert';

import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/utils/file_util.dart';

/// 「语音/录音转写」在 `Block.metaJson` 上的读写视图。
///
/// 键 `audio`：保留录音文件、原始转写文本、清洗文本。块的 `content` 仍为原始转写，
/// 参与日记投影；原始/清洗文本各自保存，可回放、可重新转写。
class VoiceRecordMeta {
  static const String key = 'audio';
  static const String sourceVoice = 'voice';

  final String file;
  final String rawTranscript;
  final String cleaned;
  final int durationMs;
  final String source;

  const VoiceRecordMeta({
    required this.file,
    this.rawTranscript = '',
    this.cleaned = '',
    this.durationMs = 0,
    this.source = sourceVoice,
  });

  String? get absolutePath {
    if (file.trim().isEmpty) return null;
    return FileUtil.getRealPath('audio', file);
  }

  bool get hasAudio => absolutePath != null;

  static VoiceRecordMeta? read(Block block) {
    final map = _mapOf(block);
    final raw = map[key];
    if (raw is! Map) return null;
    return VoiceRecordMeta(
      file: raw['file']?.toString() ?? '',
      rawTranscript: raw['rawTranscript']?.toString() ?? '',
      cleaned: raw['cleaned']?.toString() ?? '',
      durationMs: (raw['durationMs'] as num?)?.toInt() ?? 0,
      source: raw['source']?.toString() ?? sourceVoice,
    );
  }

  static bool has(Block block) => read(block) != null;

  static void write(Block block, VoiceRecordMeta meta) {
    final map = _mapOf(block);
    map[key] = {
      'file': meta.file,
      'rawTranscript': meta.rawTranscript,
      'cleaned': meta.cleaned,
      'durationMs': meta.durationMs,
      'source': meta.source,
    };
    block.metaJson = jsonEncode(map);
  }

  static Map<String, dynamic> _mapOf(Block block) {
    final raw = block.metaJson.trim();
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // 容错：损坏的 metaJson 当作空 map
    }
    return <String, dynamic>{};
  }
}
