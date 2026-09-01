import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// 内联音频播放器（不依赖 EditLogic，可在卡片/独立页复用）。
class VoiceMediaPlayer extends StatefulWidget {
  final String path;
  final String label;

  const VoiceMediaPlayer({
    super.key,
    required this.path,
    this.label = '播放录音',
  });

  @override
  State<VoiceMediaPlayer> createState() => _VoiceMediaPlayerState();
}

class _VoiceMediaPlayerState extends State<VoiceMediaPlayer> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.setSourceDeviceFile(widget.path);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      if (_position == _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      await _player.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: _toggle,
              icon: Icon(
                _state == PlayerState.playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 34,
                color: theme.colorScheme.primary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '${_fmt(_position)} / ${_fmt(_duration)}',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
