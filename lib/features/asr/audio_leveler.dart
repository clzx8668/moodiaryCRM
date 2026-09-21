import 'dart:typed_data';

/// 录音电平自适应的"音量归一化器"（纯逻辑，可单测）。
///
/// 为什么需要：真机上量到的问题——录音峰值只有 **16%~21% 满量程**、RMS 1.5%，
/// 也就是"声音很小"。这直接影响两件事：
/// 1. 回放时人听着费劲（用户反馈"人都听不清"）；
/// 2. 端侧识别与 VAD 拿到的信号太弱，切句和识别都会变差。
///
/// 处理方式：**自适应增益**——跟踪一段时间内的峰值，把增益拉到让峰值接近
/// [targetPeak]（默认 0.6 满量程），增益限制在 [minGain]..[maxGain]，
/// 并按 [smoothing] 缓慢跟随（避免逐块跳变产生"呼吸感"）。
///
/// 说明：这是**线性增益**，不是压缩器——不会改变动态关系，只把整体抬起来。
class AudioLeveler {
  AudioLeveler({
    this.targetPeak = 0.6,
    this.minGain = 1.0,
    this.maxGain = 12.0,
    this.smoothing = 0.25,
    this.silenceFloor = 0.0005,
  });

  /// 目标峰值（相对满量程 1.0）
  final double targetPeak;

  /// 最小增益（已经是响的就不动它）
  final double minGain;

  /// 最大增益（防止把底噪也放大到听得见）
  final double maxGain;

  /// 增益跟随速度：0..1，越大跟随越快
  final double smoothing;

  /// 低于这个峰值视为静音段：不更新峰值，也不放大
  final double silenceFloor;

  double _peak = 0;
  double _gain = 1;

  /// 当前增益（供 UI/诊断展示）
  double get gain => _gain;

  /// 处理一块 int16 小端 PCM：返回**同长度**的新块（不改原数据）。
  ///
  /// 静音块原样返回收益不大，但仍走同一条路径，避免调用方分支。
  Uint8List process(Uint8List pcm) {
    if (pcm.length < 2) return pcm;
    final count = pcm.length ~/ 2;
    final src = ByteData.sublistView(pcm, 0, count * 2);
    final dst = ByteData(count * 2);

    // 1) 本块峰值
    var blockPeak = 0.0;
    for (var i = 0; i < count; i++) {
      final v = src.getInt16(i * 2, Endian.little).abs() / 32768.0;
      if (v > blockPeak) blockPeak = v;
    }

    // 2) 更新长期峰值（带衰减，适应说话间隙）
    if (blockPeak >= silenceFloor) {
      _peak = blockPeak > _peak ? blockPeak : _peak * 0.995;
      if (_peak < silenceFloor) _peak = blockPeak;
    }

    // 3) 目标增益 + 平滑跟随
    final desired = _peak < silenceFloor
        ? minGain
        : (targetPeak / _peak).clamp(minGain, maxGain);
    _gain = _gain + (desired - _gain) * smoothing;

    // 4) 应用增益。静音块里没有有效信号，放大它没有意义（也不会产生额外噪声，
    //    因为底噪本来就在同一水平上），所以统一走同一条路径。
    final applied = _gain;
    for (var i = 0; i < count; i++) {
      final v = src.getInt16(i * 2, Endian.little) * applied;
      dst.setInt16(i * 2, v.clamp(-32767.0, 32767.0).round(), Endian.little);
    }
    return dst.buffer.asUint8List();
  }

  void reset() {
    _peak = 0;
    _gain = 1;
  }
}
