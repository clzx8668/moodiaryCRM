import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/voice/voice_capture_controller.dart';
import 'package:moodiary/features/voice/voice_level_wave.dart';
import 'package:moodiary/features/voice/voice_media_player.dart';

/// 快速收集面板里的「语音输入」页（批次 94）。
///
/// 设计（对标 Get 笔记，但按本地优先的思路收敛）：
/// - 点按麦克风即切到本页并**直接开始录音**（少一步、不打断表达）；
/// - 录音中可**暂停 / 继续 / 停止**；
/// - 停止后由用户决定：**保存**（立刻入库 + 后台转写）或**取消**（删掉音频，
///   不留记录、不消耗转写额度），也能直接**重录**；
/// - 音频从开始录就写在本地文件里——网络/进程异常都不会丢内容；
/// - 端侧模型就绪时走**本地实时转写**（边说边出字）；未就绪则退回"录完再云端转写"。
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

  /// 开始 / 继续录音（播放键）：**由用户决定真正开始**，不再自动开录
  final VoidCallback? onStart;

  /// 本地转写未启用时，点「去设置」的回调（可空：不传则不显示入口）
  final VoidCallback? onSetupOnDevice;

  /// 试听组件（默认内联播放器；单测注入占位，避免依赖音频插件）
  final Widget Function(String path)? previewBuilder;

  const VoiceCapturePanel({
    super.key,
    required this.controller,
    required this.onExitKeyboard,
    required this.onCancel,
    required this.onRetake,
    required this.onSave,
    this.onStart,
    this.onSetupOnDevice,
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
        _onDeviceBanner(context),
        _liveTranscript(context),
        const SizedBox(height: 10),
        ValueListenableBuilder<VoiceCapturePhase>(
          valueListenable: controller.phase,
          builder: (context, phase, _) => _hint(context, phase),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<VoiceCapturePhase>(
          valueListenable: controller.phase,
          builder: (context, phase, _) => switch (phase) {
            // 录音中 / 暂停统一成一组互斥按钮：左播放/暂停，右停止
            VoiceCapturePhase.recording => _playStopControls(context, phase),
            VoiceCapturePhase.paused => _playStopControls(context, phase),
            VoiceCapturePhase.stopped => _stoppedControls(context),
            VoiceCapturePhase.idle => _playStopControls(context, phase),
          },
        ),
      ],
    );
  }

  /// 端侧实时字幕：说话过程中逐句上屏（未启用端侧时不占位）。
  ///
  /// 未启用端侧时**明确说明原因**（模型没装 / 引擎起不来），
  /// 而不是静默地录完走云端 —— 之前用户只看到"转写失败"，查不到原因。
  Widget _onDeviceBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // 端侧已启用：不占位
    if (controller.onDeviceActive) {
      return const SizedBox.shrink();
    }
    final reason = controller.onDeviceUnavailableReason;
    if (reason == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.offline_bolt_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '未启用本地转写：$reason（保存后仍会走云端）',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ),
            if (onSetupOnDevice != null)
              TextButton(
                onPressed: onSetupOnDevice,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('去设置'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _liveTranscript(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ValueListenableBuilder<String>(
      valueListenable: controller.liveTranscript,
      builder: (context, transcript, _) {
        final hasText = transcript.trim().isNotEmpty;
        if (!controller.onDeviceActive && !hasText) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64, maxHeight: 132),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant, width: 0.6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: controller.speaking,
                      builder: (context, speaking, _) => Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: speaking
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '端侧实时转写',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasText ? '本地 · 不耗流量' : '等待人声…',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      hasText ? transcript : '开始说话，这里会实时出字…',
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: hasText
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        if (controller.onDeviceActive) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '本地',
              style: context.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
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
      // 滚动波形：把电平随时间推成一条"历史波形"，比原地缩放的电平条好看得多
      child: _LevelWave(
        controller: controller,
        color: colorScheme.primary,
        idleColor: colorScheme.outlineVariant,
      ),
    );
  }

  Widget _hint(BuildContext context, VoiceCapturePhase phase) {
    final onDevice = controller.onDeviceActive;
    final text = switch (phase) {
      VoiceCapturePhase.recording => onDevice
          ? '端侧转写中（本地出字）；可暂停、可继续，停止后再决定是否保存'
          : '说话就行；可暂停、可继续，停止后再决定是否保存',
      VoiceCapturePhase.paused => onDevice
          ? '已暂停（音频与已识别文本都已落本地），可继续或直接停止'
          : '已暂停录音（音频文件已保留），可继续或直接停止',
      VoiceCapturePhase.stopped => onDevice
          ? '端侧草稿已在本地：保存即入库（不再联网转写），取消则丢弃不留记录'
          : '音频已存在本地：保存即入库并后台转写，取消则丢弃不留记录',
      VoiceCapturePhase.idle => '点左边的 ▶ 开始录音；随时可暂停或停止',
    };
    return Text(
      text,
      style: context.textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// 录音相关的**一组互斥按钮**（批次 112）：
  ///
  /// - 左键：待开始/暂停时显示 ▶（开始/继续），录音中显示 ⏸（暂停）；
  /// - 右键：停止（始终可见，待开始/暂停时禁用，避免"没录就停"）；
  /// - 进入语音页就是这个样子，**不自动开录**——不再有"先闪一下再跳走"的跳动。
  Widget _playStopControls(BuildContext context, VoiceCapturePhase phase) {
    final colorScheme = Theme.of(context).colorScheme;
    final recording = phase == VoiceCapturePhase.recording;
    final paused = phase == VoiceCapturePhase.paused;
    final idle = phase == VoiceCapturePhase.idle;
    // 没有可停止的内容时禁用停止键（未开始、或已空闲）
    final canStop = recording || paused || controller.hasAudio;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: recording
                ? controller.pause
                : (onStart ?? () => controller.start()),
            icon: Icon(
              recording ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(recording ? '暂停' : (idle ? '开始录音' : '继续')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: canStop ? controller.stop : null,
            style: FilledButton.styleFrom(
              backgroundColor: canStop
                  ? colorScheme.error
                  : colorScheme.surfaceContainerHighest,
              foregroundColor: canStop
                  ? colorScheme.onError
                  : colorScheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('停止'),
          ),
        ),
      ],
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
/// 滚动波形：把电平随时间推成一条历史波形（说话时"流动"，停止后自然衰减）。
class _LevelWave extends StatefulWidget {
  final VoiceCaptureController controller;
  final Color color;
  final Color idleColor;

  const _LevelWave({
    required this.controller,
    required this.color,
    required this.idleColor,
  });

  @override
  State<_LevelWave> createState() => _LevelWaveState();
}

class _LevelWaveState extends State<_LevelWave> {
  static const Duration _shiftInterval = Duration(milliseconds: 80);

  final VoiceLevelWave _wave = VoiceLevelWave();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.level.addListener(_onLevel);
    _timer = Timer.periodic(_shiftInterval, (_) => _shift());
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.level.removeListener(_onLevel);
    super.dispose();
  }

  void _onLevel() {
    _wave.feed(widget.controller.level.value);
  }

  void _shift() {
    if (!mounted) return;
    final active = widget.controller.phase.value == VoiceCapturePhase.recording;
    setState(() {
      _wave.advance(active: active);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WavePainter(
        samples: _wave.samples,
        revision: _wave.revision,
        color: widget.color,
        idleColor: widget.idleColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// 波形绘制：以中线为轴的镜像柱状（左旧右新）。
class _WavePainter extends CustomPainter {
  final List<double> samples;

  /// 版本号：列表是原地滚动的，必须靠它触发重绘（否则波形冻结）
  final int revision;

  final Color color;
  final Color idleColor;

  _WavePainter({
    required this.samples,
    required this.revision,
    required this.color,
    required this.idleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final count = samples.length;
    final barWidth = ((size.width - gap * (count - 1)) / count).clamp(1.5, 8.0);
    final centerY = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < count; i++) {
      final value = samples[i];
      // 最小值给 2px：静音时是一条细线而不是空白
      final barHeight = (2 + (size.height - 2) * value).clamp(2.0, size.height);
      paint.color = value > 0.04 ? color : idleColor;
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
  bool shouldRepaint(covariant _WavePainter old) =>
      old.revision != revision ||
      old.color != color ||
      old.idleColor != idleColor;
}
