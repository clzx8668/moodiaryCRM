import 'dart:convert';

import 'package:flutter/material.dart';

/// 图表卡片：JSON 摘要展示（Phase 3 前不引入图表库渲染）。
class ChartCard extends StatelessWidget {
  final String content;

  const ChartCard({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String summary = content;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString() ?? 'chart';
        final data = decoded['data'];
        final count = data is List
            ? data.length
            : data is Map
            ? data.length
            : 0;
        summary = '$type · $count 项数据';
      }
    } catch (_) {
      // 非 JSON 回退原文
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.bar_chart_rounded, color: colorScheme.primary),
      title: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
