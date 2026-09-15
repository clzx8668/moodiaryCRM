import 'package:flutter/material.dart';
import 'package:moodiary/features/block/block_renderer.dart';

/// 文本卡片：Markdown 预览，长文折叠（高度限制 + 底部渐变遮罩 + 展开/收起）。
class TextCard extends StatelessWidget {
  final String content;
  final bool expanded;
  final VoidCallback onToggleExpand;

  /// 是否允许文本选择；详情页卡片内关闭（点击优先进入编辑器）。
  final bool selectable;

  /// 折叠阈值（与 SmartCanvasLogic.collapseThreshold 一致）
  final int collapseThreshold;

  /// 折叠态内容最大高度（主流 App 风格：淡出 + 展开全文）
  final double collapsedMaxHeight;

  const TextCard({
    super.key,
    required this.content,
    required this.expanded,
    required this.onToggleExpand,
    this.selectable = true,
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
                    child: MarkdownContentView(
                      data: text,
                      selectable: selectable,
                      headingScale: MarkdownHeadingScale.card,
                    ),
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
          MarkdownContentView(
            data: text,
            selectable: selectable,
            headingScale: MarkdownHeadingScale.card,
          ),
        if (needCollapse)
          // 整行可点的轻量「展开全文 / 收起」：可点区域覆盖整行宽度，
          // 文案明确（旧版只有一个 18px 箭头，手机上很难点、语义也弱）
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 34,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    expanded ? '收起' : '展开全文',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
