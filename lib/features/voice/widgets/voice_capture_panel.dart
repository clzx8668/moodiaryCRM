import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/voice/voice_capture_controller.dart';
import 'package:moodiary/features/voice/voice_media_player.dart';

/// 快速收集面板里的「语音输入」页（批次 94）。
///
/// 设计（对标 Get 笔记，但按本地优先的思路收敛）：
/// - 点按麦克风即切到本页并**直接开始录音**（少一步、不打断表达）；
/// - 录音中可**暂停 / 继续 / 停止**；
/// - 停止后由用户决定：**保存**（立刻入库 + 后台转写）或**取消**（删掉音频，
///   不留记录、不消耗转写额度），也能直接**重录**；
/// - 音频从开始录就写在本地文件里——网络/进程异常都不会丢内容；
/// - 实时转写留作后期能力（本页只录音，转写一律走后台任务）。
class VoiceCapturePanel extends StatelessWidget {
  final VoiceCaptureController controller;

  /// 返回键盘输入（丢弃未保存录音）
  final VoidCallback onExitKeyboard;

  /// 取消（丢弃录音并返回键盘输入）
  final VoidCallback onCancel;

  /// 重录
  final VoidCallback onRetake;

  /// 保存并转写
  final VoidCallback onSave;

  /// 试听组件（默认内联播放器；单测注入占位，避免依赖音频插件）
  final Widget Function(String path)? previewBuilder;

  const VoiceCapturePanel({
    super.key,
    required this.controller,
    required this.onExitKeyboard,
    required this.onCancel,
    required this.onRetake,
    required this.onSave,
    this.previewBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<VoiceCapturePhase>(
          valueListenable: controller.phase,
          builder: (context, phase, _) => _header(context, phase),
        ),
        const SizedBox(height: 10),
        _levelMeter(colorScheme),
        const SizedBox(height: 10),
        ValueListenableBuilder<VoiceCapturePhase>(
          valueListenable: controller.phase,
          builder: (context, phase, _) => _hint(context, phase),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<VoiceCapturePhase>(
          valueListenable: controller.phase,
          builder: (context, phase, _) => switch (phase) {
            VoiceCapturePhase.recording => _recordingControls(context),
            VoiceCapturePhase.paused => _pausedControls(context),
            VoiceCapturePhase.stopped => _stoppedControls(context),
            VoiceCapturePhase.idle => _readyControls(context),
          },
        ),
      ],
    );
  }

  Widget _header(BuildContext context, VoiceCapturePhase phase) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (phase) {
      VoiceCapturePhase.recording => (
        '正在录音',
        colorScheme.error,
        Icons.fiber_manual_record_rounded,
      ),
      VoiceCapturePhase.paused => (
        '已暂停',
        colorScheme.tertiary,
        Icons.pause_rounded,
      ),
      VoiceCapturePhase.stopped => (
        '录音完成',
        colorScheme.primary,
        Icons.check_circle_outline_rounded,
      ),
      VoiceCapturePhase.idle => (
        '准备录音',
        colorScheme.onSurfaceVariant,
        Icons.mic_none_rounded,
      ),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textTheme.titleSmall?.copyWith(color: color),
        ),
        const Spacer(),
        ValueListenableBuilder<Duration>(
          valueListenable: controller.elapsed,
          builder: (context, elapsed, _) => Text(
            VoiceCaptureController.formatDuration(elapsed),
            style: context.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onExitKeyboard,
          tooltip: '切回键盘输入',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.keyboard_alt_outlined, size: 20),
        ),
      ],
    );
  }

  Widget _levelMeter(ColorScheme colorScheme) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: controller.level,
        builder: (context, level, _) => CustomPaint(
          painter: _LevelPainter(
            level: level,
            color: colorScheme.primary,
            idleColor: colorScheme.outlineVariant,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, VoiceCapturePhase phase) {
    final text = switch (phase) {
      VoiceCapturePhase.recording => '说话就行；可暂停、可继续，停止后再决定是否保存',
      VoiceCapturePhase.paused => '已暂停录音（音频文件已保留），可继续或直接停止',
      VoiceCapturePhase.stopped => '音频已存在本地：保存即入库并后台转写，取消则丢弃不留记录',
      VoiceCapturePhase.idle => '点「开始录音」即可说话',
    };
    return Text(
      text,
      style: context.textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _recordingControls(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.pause,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('暂停'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: controller.stop,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('停止'),
          ),
        ),
      ],
    );
  }

  Widget _pausedControls(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: controller.resume,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('继续'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.stop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('停止'),
          ),
        ),
      ],
    );
  }

  Widget _readyControls(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => controller.start(),
      icon: const Icon(Icons.mic_rounded),
      label: const Text('开始录音'),
    );
  }

  Widget _stoppedControls(BuildContext context) {
    final path = controller.audioPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (path != null)
          previewBuilder?.call(path) ??
              VoiceMediaPlayer(path: path, label: '试听这段录音'),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('取消'),
            ),
            TextButton.icon(
              onPressed: onRetake,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重录'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('保存并转写'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 电平条：录音时随音量起伏，暂停/停止时静止。
class _LevelPainter extends CustomPainter {
  final double level;
  final Color color;
  final Color idleColor;

  _LevelPainter({
    required this.level,
    required this.color,
    required this.idleColor,
  });

  /// 每根柱子的固定形状系数（避免随机数导致每帧抖动）
  static const List<double> _shape = [
    0.35,
    0.55,
    0.8,
    1.0,
    0.7,
    0.45,
    0.6,
    0.9,
    1.0,
    0.75,
    0.5,
    0.65,
    0.95,
    1.0,
    0.8,
    0.55,
    0.4,
    0.6,
    0.85,
    0.95,
    0.7,
    0.5,
    0.35,
    0.55,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final count = _shape.length;
    const gap = 3.0;
    final barWidth = (size.width - gap * (count - 1)) / count;
    final centerY = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < count; i++) {
      final factor = _shape[i] * level;
      final barHeight = (4 + (size.height - 4) * factor).clamp(
        4.0,
        size.height,
      );
      paint.color = factor > 0.02 ? color : idleColor;
      final left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, centerY - barHeight / 2, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LevelPainter old) =>
      old.level != level || old.color != color || old.idleColor != idleColor;
}
