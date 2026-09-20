import 'dart:math' as math;
import 'dart:typed_data';

/// 轻量「人声门卫」：在把 PCM 送进端侧模型之前，先用能量判断这一段是否值得计算。
///
/// 端侧模型自带精确 VAD（silero）；这一层是**省电的第一道闸**：
/// 纯静音/底噪直接丢掉，不触发后续推理；同时给 UI 提供"当前是否在说话"。
///
/// 纯逻辑、可单测：输入 PCM(int16 LE) 块 → 输出 [PcmGateDecision]。
class PcmGate {
  PcmGate({
    this.sampleRate = 16000,
    this.threshold = 0.012,
    this.hangoverChunks = 6,
  }) : assert(hangoverChunks >= 0);

  /// 采样率（用于把块大小换算成时长，仅用于展示/统计）
  final int sampleRate;

  /// RMS 阈值（0..1）。默认 0.012 ≈ 安静房间说话的下限
  final double threshold;

  /// 挂起块数：音量掉回阈值以下后，还要继续放行多少块（避免把句尾吃掉）
  final int hangoverChunks;

  int _hangoverLeft = 0;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  /// 判定一个 PCM 块；返回是否应放行（true = 可能有人声）
  bool accept(Uint8List pcm) {
    final level = rms(pcm);
    final loud = level >= threshold;
    if (loud) {
      _hangoverLeft = hangoverChunks;
      _speaking = true;
      return true;
    }
    if (_hangoverLeft > 0) {
      _hangoverLeft--;
      return true;
    }
    _speaking = false;
    return false;
  }

  void reset() {
    _hangoverLeft = 0;
    _speaking = false;
  }

  /// 16-bit 小端 PCM 的 RMS（0..1），纯函数
  static double rms(Uint8List pcm) {
    if (pcm.length < 2) return 0;
    final count = pcm.length ~/ 2;
    var sum = 0.0;
    final data = ByteData.sublistView(pcm, 0, count * 2);
    for (var i = 0; i < count; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
    }
    return math.sqrt(sum / count);
  }
}

/// 端侧识别事件的精简视图（UI 只关心这些）
class AsrPartialText {
  /// 本次会话已确认的完整文本（各句拼接）
  final String text;

  /// 最新一句
  final String lastSentence;

  /// 已识别的句数
  final int sentenceCount;

  const AsrPartialText({
    required this.text,
    required this.lastSentence,
    required this.sentenceCount,
  });

  /// 把新句子并进已有文本（纯函数，便于单测）：
  /// 空句忽略；已存在的前缀不重复追加。
  static String merge(String base, String sentence) {
    final s = sentence.trim();
    if (s.isEmpty) return base;
    final b = base.trimRight();
    if (b.isEmpty) return s;
    if (b.endsWith(s)) return b;
    return '$b$s';
  }
}
