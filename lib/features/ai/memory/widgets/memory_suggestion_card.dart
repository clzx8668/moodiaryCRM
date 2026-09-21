import 'package:flutter/material.dart';
import 'package:moodiary/features/ai/memory/memory_suggestion.dart';
import 'package:moodiary/features/ai/memory/memory_suggestion_service.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 「要不要记下来？」建议卡（批次 120）。
///
/// 出现在 AI 回答之后，**不打断**任何操作：
/// - 点「记住」→ 写进长期记忆或技能手册（自动快照，可回滚）；
/// - 点「不用」→ 直接消失；
/// - 什么都不点 → 保持挂着，切换会话时自然消失，不会有弹窗骚扰。
class MemorySuggestionCard extends StatelessWidget {
  const MemorySuggestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MemorySuggestion?>(
      valueListenable: MemorySuggestionService.instance.pending,
      builder: (context, s, _) {
        if (s == null) return const SizedBox.shrink();
        final colorScheme = Theme.of(context).colorScheme;
        final isSkill = s.kind == MemorySuggestionKind.skill;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Card(
            margin: EdgeInsets.zero,
            color: colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSkill
                            ? Icons.auto_stories_outlined
                            : Icons.psychology_alt_outlined,
                        size: 16,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isSkill ? '要不要存成技能手册？' : '要不要记进长期记忆？',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: '不用',
                        visualDensity: VisualDensity.compact,
                        onPressed: MemorySuggestionService.instance.dismiss,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    s.reason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${s.title}\n${_preview(s.content)}',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: MemorySuggestionService.instance.dismiss,
                        child: const Text('不用'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: () async {
                          final msg =
                              await MemorySuggestionService.instance.accept();
                          if (msg.isNotEmpty) {
                            toast.success(message: msg);
                          }
                        },
                        child: Text(isSkill ? '存为手册' : '记住'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _preview(String content) {
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#') && l != '（可补充触发场景）');
    return lines.take(2).join(' · ');
  }
}
