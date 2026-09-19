import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/voice/voice_note_info.dart';
import 'package:moodiary/features/voice/widgets/voice_player_card.dart';

/// 含录音的详情页顶部专属区块（区别于普通详情页）。
///
/// 结构对标 Get 笔记的录音笔记：置顶播放器 → 转写状态 → 「录音原文 / 笔记内容」切换。
/// - 转写中：骨架条 + 「约需 10 秒 - 1 分钟，可以先返回继续别的」；
/// - 失败：显示原因 + 「重试转写」；
/// - 完成：出现两个 Tab（原文与正文一致时不显示，避免无意义的切换）。
class VoiceNoteHeader extends StatelessWidget {
  final VoiceNoteInfo info;

  /// 音频文件绝对路径（由调用方解析，便于测试注入）
  final String audioPath;

  final VoiceNoteTab tab;
  final ValueChanged<VoiceNoteTab> onTabChanged;
  final VoidCallback onRetry;

  /// 播放器（单测注入占位，避免依赖音频插件）
  final Widget Function(String path)? playerBuilder;

  const VoiceNoteHeader({
    super.key,
    required this.info,
    required this.audioPath,
    required this.tab,
    required this.onTabChanged,
    required this.onRetry,
    this.playerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '录音笔记',
              style: context.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (info.hasDistinctRaw)
              Text(
                tab == VoiceNoteTab.raw ? '查看笔记内容' : '查看录音原文',
                style: context.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        playerBuilder?.call(audioPath) ??
            VoicePlayerCard(path: audioPath, waveform: info.waveform),
        const SizedBox(height: 10),
        switch (info.status) {
          VoiceNoteStatus.transcribing => _transcribing(context),
          VoiceNoteStatus.failed => _failed(context, colorScheme),
          VoiceNoteStatus.done => _tabs(context, colorScheme),
        },
      ],
    );
  }

  Widget _transcribing(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text('录音转写中…', style: context.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '约需 10 秒 - 1 分钟，可以先返回或继续写别的，转好会自动写入正文。',
          style: context.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        // 骨架条：先把「即将出现的正文」占住位置
        for (final factor in const [0.4, 0.92, 0.88, 0.9, 0.6])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _failed(BuildContext context, ColorScheme colorScheme) {
    return Card.filled(
      margin: EdgeInsets.zero,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  '转写未完成',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            if (info.failureReason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                info.failureReason,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '原始录音已保留，可重试转写或直接编辑正文。',
              style: context.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试转写'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context, ColorScheme colorScheme) {
    if (!info.hasDistinctRaw) return const SizedBox.shrink();
    return Row(
      children: [
        _tabButton(context, colorScheme, VoiceNoteTab.raw, '录音原文'),
        const SizedBox(width: 18),
        _tabButton(context, colorScheme, VoiceNoteTab.note, '笔记内容'),
      ],
    );
  }

  Widget _tabButton(
    BuildContext context,
    ColorScheme colorScheme,
    VoiceNoteTab value,
    String label,
  ) {
    final selected = value == tab;
    return InkWell(
      onTap: () => onTabChanged(value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.textTheme.titleSmall?.copyWith(
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              height: 2,
              width: label.length * 15.0,
              decoration: BoxDecoration(
                color: selected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
