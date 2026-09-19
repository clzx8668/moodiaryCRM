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

  const VoicePlayerCard({super.key, required this.path, this.durationMs = 0});

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

  @override
  void initState() {
    super.initState();
    _total = Duration(milliseconds: widget.durationMs);
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
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
    _player.dispose();
    super.dispose();
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
