import 'package:flutter/material.dart';
import 'package:moodiary/features/block/block_renderer.dart';

/// 文本卡片：Markdown 预览，长文折叠（高度限制 + 底部渐变遮罩 + 展开/收起）。
class TextCard extends StatelessWidget {
  final String content;
  final bool expanded;
  final VoidCallback onToggleExpand;

  /// 折叠阈值（与 SmartCanvasLogic.collapseThreshold 一致）
  final int collapseThreshold;

  /// 折叠态内容最大高度（主流 App 风格：淡出 + 展开全文）
  final double collapsedMaxHeight;

  const TextCard({
    super.key,
    required this.content,
    required this.expanded,
    required this.onToggleExpand,
    this.collapseThreshold = 500,
    this.collapsedMaxHeight = 220,
  });

  @override
  Widget build(BuildContext context) {
    final text = content.trim();
    final needCollapse = text.length > collapseThreshold;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (needCollapse && !expanded)
          // 折叠态：完整渲染 Markdown（语法不截断），高度受限 + 底部渐变淡出
          ClipRect(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: collapsedMaxHeight),
              child: Stack(
                children: [
                  OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: MarkdownContentView(data: text),
                  ),
                  // 底部渐变遮罩：指示还有更多内容
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.surface.withValues(alpha: 0),
                              colorScheme.surface.withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          MarkdownContentView(data: text),
        if (needCollapse)
          Center(
            // 只保留箭头图标（展开 ▾ / 收起 ▴），紧凑精致、无文字
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onToggleExpand,
              child: Padding(
                // 底部不保留内边距：让箭头与下方标签/操作行贴近（≈2px）
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
