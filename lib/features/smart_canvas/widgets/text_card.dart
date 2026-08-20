import 'package:flutter/material.dart';
import 'package:moodiary/features/block/block_renderer.dart';

/// 文本卡片：Markdown 预览，长文折叠。
class TextCard extends StatelessWidget {
  final String content;
  final bool expanded;
  final VoidCallback onToggleExpand;

  /// 折叠阈值（与 SmartCanvasLogic.collapseThreshold 一致）
  final int collapseThreshold;

  const TextCard({
    super.key,
    required this.content,
    required this.expanded,
    required this.onToggleExpand,
    this.collapseThreshold = 500,
  });

  @override
  Widget build(BuildContext context) {
    final text = content.trim();
    final needCollapse = text.length > collapseThreshold;
    final display = expanded || !needCollapse ? text : text.substring(0, 300);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownContentView(data: display),
        if (needCollapse)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggleExpand,
              icon: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(expanded ? '收起' : '展开全文'),
            ),
          ),
      ],
    );
  }
}
