import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 语音笔记的置顶播放器卡片（对标 Get 笔记的录音卡片）。
///
/// 进度条可拖动、±15 秒快进快退、倍速循环（1.0 → 1.25 → 1.5 → 2.0）。
class VoicePlayerCard extends StatefulWidget {
  final String path;

  /// 已知时长（毫秒，来自 meta；0 = 由播放器解析）
  final int durationMs;

  /// 录音的响度包络（0..1）：非空时按下方的波形条渲染并随进度高亮
  final List<double> waveform;

  const VoicePlayerCard({
    super.key,
    required this.path,
    this.durationMs = 0,
    this.waveform = const [],
  });

  /// 播放进度对应到第几根波形柱（纯函数，便于单测）
  static int playedBars({
    required int barCount,
    required Duration position,
    required Duration total,
  }) {
    if (barCount <= 0) return 0;
    if (total <= Duration.zero) return 0;
    final ratio = position.inMilliseconds / total.inMilliseconds;
    return (ratio.clamp(0.0, 1.0) * barCount).ceil().clamp(0, barCount);
  }

  /// 播放头附近柱子的跳动倍率（纯函数，便于单测）。
  ///
  /// 只在播放中生效：倍率随 [phase] 摆动，**摆动幅度由该处真实响度 [level] 决定**——
  /// 响度大的地方跳得明显，静音处几乎不动。
  static double pulseFactor({
    required double level,
    required double phase,
    required int offset,
  }) {
    final l = level.clamp(0.0, 1.0);
    if (l <= 0.02) return 1.0;
    final wave = math.sin(phase + offset * 0.7);
    return 1.0 + 0.45 * l * wave;
  }

  /// 可选倍速档位
  static const List<double> speeds = [1.0, 1.25, 1.5, 2.0];

  /// 倍速循环（纯函数，便于单测）
  static double nextSpeed(double current) {
    final index = speeds.indexWhere((s) => (s - current).abs() < 0.001);
    if (index < 0) return speeds.first;
    return speeds[(index + 1) % speeds.length];
  }

  /// 快进/快退后的目标位置（纯函数）：夹在 [0, 时长] 内
  static Duration shiftPosition(
    Duration position,
    Duration total,
    int seconds,
  ) {
    final target = position + Duration(seconds: seconds);
    if (target < Duration.zero) return Duration.zero;
    if (total > Duration.zero && target > total) return total;
    return target;
  }

  static String format(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  State<VoicePlayerCard> createState() => _VoicePlayerCardState();
}

class _VoicePlayerCardState extends State<VoicePlayerCard> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  double _speed = VoicePlayerCard.speeds.first;
  Timer? _pulseTimer;
  double _pulsePhase = 0;

  bool get _playing => _state == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _total = Duration(milliseconds: widget.durationMs);
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() => _state = s);
        _syncPulse(s == PlayerState.playing);
      }
    });
    _player.onPositionChanged.listen((p) {
      if (mounted && !_dragging) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _total = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
    _player.setSourceDeviceFile(widget.path);
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  /// 播放时让播放头附近的波形轻微起伏（幅度跟随该处真实响度）
  void _syncPulse(bool playing) {
    if (playing) {
      _pulseTimer ??= Timer.periodic(const Duration(milliseconds: 90), (_) {
        if (!mounted) return;
        setState(() => _pulsePhase += 0.55);
      });
    } else {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      if (mounted) setState(() => _pulsePhase = 0);
    }
  }

  bool _dragging = false;

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_total > Duration.zero && _position >= _total) {
      await _player.seek(Duration.zero);
    }
    await _player.resume();
  }

  Future<void> _seekBy(int seconds) async {
    final target = VoicePlayerCard.shiftPosition(_position, _total, seconds);
    setState(() => _position = target);
    await _player.seek(target);
  }

  Future<void> _cycleSpeed() async {
    final next = VoicePlayerCard.nextSpeed(_speed);
    setState(() => _speed = next);
    await _player.setPlaybackRate(next);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final playing = _state == PlayerState.playing;
    final maxMs =
        (_total.inMilliseconds > 0 ? _total : const Duration(seconds: 1))
            .inMilliseconds
            .toDouble();
    final valueMs = _position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

    return Card.filled(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 真实响度波形（有包络时）：已播放部分用主色高亮，随进度扫过
            if (widget.waveform.isNotEmpty) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null || _total <= Duration.zero) return;
                  final width = box.size.width;
                  final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0);
                  _player.seek(
                    Duration(
                      milliseconds: (ratio * _total.inMilliseconds).round(),
                    ),
                  );
                },
                child: SizedBox(
                  height: 34,
                  child: CustomPaint(
                    painter: _WaveformProgressPainter(
                      waveform: widget.waveform,
                      played: VoicePlayerCard.playedBars(
                        barCount: widget.waveform.length,
                        position: _position,
                        total: _total,
                      ),
                      pulsePhase: _pulsePhase,
                      pulsing: _playing,
                      playedColor: colorScheme.primary,
                      restColor: colorScheme.outlineVariant,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ] else if (_playing) ...[
              // 旧录音没有响度包络：至少给一条会走的进度轨，播放时有反馈
              SizedBox(
                height: 6,
                child: CustomPaint(
                  painter: _TrackProgressPainter(
                    played: VoicePlayerCard.playedBars(
                      barCount: 100,
                      position: _position,
                      total: _total,
                    ),
                    playedColor: colorScheme.primary,
                    restColor: colorScheme.outlineVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Text(
                  VoicePlayerCard.format(_position),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: valueMs,
                      max: maxMs,
                      onChangeStart: (_) => _dragging = true,
                      onChanged: (v) => setState(
                        () => _position = Duration(milliseconds: v.round()),
                      ),
                      onChangeEnd: (v) async {
                        _dragging = false;
                        await _player.seek(Duration(milliseconds: v.round()));
                      },
                    ),
                  ),
                ),
                Text(
                  VoicePlayerCard.format(_total),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: '快退 15 秒',
                  onPressed: () => _seekBy(-15),
                  icon: const Icon(Icons.replay_rounded),
                ),
                IconButton.filled(
                  tooltip: playing ? '暂停' : '播放',
                  onPressed: _toggle,
                  iconSize: 30,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: '快进 15 秒',
                  onPressed: () => _seekBy(15),
                  icon: const Icon(Icons.forward_rounded),
                ),
                TextButton(
                  onPressed: _cycleSpeed,
                  child: Text(
                    '${_speed.toStringAsFixed(_speed == 1.0 ? 1 : 2)}x',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 真实响度波形 + 播放进度：已播放柱用主色，未播放用弱色。
class _WaveformProgressPainter extends CustomPainter {
  final List<double> waveform;
  final int played;
  final double pulsePhase;
  final bool pulsing;
  final Color playedColor;
  final Color restColor;

  _WaveformProgressPainter({
    required this.waveform,
    required this.played,
    required this.pulsePhase,
    required this.pulsing,
    required this.playedColor,
    required this.restColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final count = waveform.length;
    if (count == 0) return;
    final barWidth = ((size.width - gap * (count - 1)) / count).clamp(1.0, 6.0);
    final centerY = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < count; i++) {
      final value = waveform[i].clamp(0.0, 1.0);
      // 播放中：播放头附近按"该处真实响度"轻微起伏，动静看得见
      final near = pulsing && (i - (played - 1)).abs() <= 3;
      final factor = near
          ? VoicePlayerCard.pulseFactor(
              level: value,
              phase: pulsePhase,
              offset: i - played,
            )
          : 1.0;
      final barHeight = (3 + (size.height - 3) * value)
          .clamp(3.0, size.height)
          .clamp(0.0, size.height) *
          factor;
      paint.color = i < played ? playedColor : restColor;
      final left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left,
            centerY - barHeight.clamp(3.0, size.height) / 2,
            barWidth,
            barHeight.clamp(3.0, size.height),
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformProgressPainter old) =>
      old.played != played ||
      old.waveform != waveform ||
      old.pulsePhase != pulsePhase ||
      old.pulsing != pulsing ||
      old.playedColor != playedColor ||
      old.restColor != restColor;
}

/// 没有响度包络时的进度轨（旧录音）
class _TrackProgressPainter extends CustomPainter {
  final int played;
  final Color playedColor;
  final Color restColor;

  _TrackProgressPainter({
    required this.played,
    required this.playedColor,
    required this.restColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final centerY = size.height / 2;
    const height = 4.0;
    paint.color = restColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - height / 2, size.width, height),
        const Radius.circular(height / 2),
      ),
      paint,
    );
    final playedWidth = size.width * (played / 100).clamp(0.0, 1.0);
    paint.color = playedColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - height / 2, playedWidth, height),
        const Radius.circular(height / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackProgressPainter old) =>
      old.played != played ||
      old.playedColor != playedColor ||
      old.restColor != restColor;
}

