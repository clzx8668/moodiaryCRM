/// 录音电平的滚动波形模型（纯逻辑，便于单测）。
///
/// 语音面板把「实时电平」推进成一条**历史波形**：说话时波形向前流动，
/// 停止/暂停后自然衰减回一条细线（比原地缩放的电平条直观得多）。
class VoiceLevelWave {
  VoiceLevelWave({this.barCount = 40, this.smoothing = 0.6})
    : assert(barCount > 1),
      // 需要可增删（滚动推进），因此用可增长列表
      samples = List<double>.generate(barCount, (_) => 0, growable: true);

  /// 可见采样条数（越多覆盖的时长越长）
  final int barCount;

  /// 平滑系数：越大越"稳"，越小越灵敏（0.6 ≈ 跟手但不尖刺）
  final double smoothing;

  /// 历史采样（左旧右新）
  final List<double> samples;

  double _smoothed = 0;

  /// 平滑后的当前电平
  double get smoothed => _smoothed;

  /// 收到一次原始电平（0..1）
  void feed(double level) {
    final v = level.clamp(0.0, 1.0);
    _smoothed = _smoothed * smoothing + v * (1 - smoothing);
  }

  /// 推进一格：录音中按平滑电平前进；否则按 [decay] 衰减（波形"落下"）
  void advance({required bool active, double decay = 0.85}) {
    final next = active ? _smoothed : _smoothed * decay;
    _smoothed = next.clamp(0.0, 1.0);
    samples.removeAt(0);
    samples.add(_smoothed);
  }

  /// 清空（重新开始录音时）
  void reset() {
    _smoothed = 0;
    for (var i = 0; i < samples.length; i++) {
      samples[i] = 0;
    }
  }

  /// 当前波形峰值（供测试与"是否有声音"判断）
  double get peak => samples.reduce((a, b) => a > b ? a : b);
}
