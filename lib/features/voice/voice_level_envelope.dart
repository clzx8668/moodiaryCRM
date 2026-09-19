/// 整段录音的电平包络（纯逻辑，便于单测）。
///
/// 录音过程中把电平随时间长成一条"响度曲线"，保存时降采样成固定长度随笔记一起存；
/// 之后在详情页播放时即可**按真实响度**显示波形，并让播放进度高亮扫过。
class VoiceLevelEnvelope {
  VoiceLevelEnvelope({this.sampleIntervalMs = 200});

  /// 采样间隔（毫秒）：200ms 一条，1 分钟 300 条，内存可忽略
  final int sampleIntervalMs;

  final List<double> _samples = [];

  int get length => _samples.length;

  /// 已录时长（按采样条数估算）
  Duration get duration =>
      Duration(milliseconds: _samples.length * sampleIntervalMs);

  void add(double level) {
    final v = level.isFinite ? level.clamp(0.0, 1.0) : 0.0;
    _samples.add(v);
  }

  void clear() => _samples.clear();

  List<double> get raw => List<double>.unmodifiable(_samples);

  /// 降采样成固定 [buckets] 条（每桶取最大值，保留峰值形态），用于持久化与渲染。
  List<double> downsample(int buckets) {
    if (_samples.isEmpty || buckets <= 0) return const [];
    if (_samples.length <= buckets) {
      // 条数不足：原样返回（渲染端自行补零）
      return List<double>.from(_samples);
    }
    final out = List<double>.filled(buckets, 0);
    for (var i = 0; i < buckets; i++) {
      final start = (i * _samples.length / buckets).floor();
      final end = (((i + 1) * _samples.length) / buckets).ceil();
      var peak = 0.0;
      for (var j = start; j < end && j < _samples.length; j++) {
        if (_samples[j] > peak) peak = _samples[j];
      }
      out[i] = peak;
    }
    return out;
  }

  /// 容错解析存储里的包络（历史数据可能缺失/类型不对/越界）
  static List<double> decode(Object? raw, {int maxBuckets = 256}) {
    if (raw is! List || raw.isEmpty) return const [];
    final out = <double>[];
    for (final item in raw) {
      final v = item is num ? item.toDouble() : double.tryParse('$item');
      if (v == null || !v.isFinite) continue;
      out.add(v.clamp(0.0, 1.0));
      if (out.length >= maxBuckets) break;
    }
    return out;
  }
}
