import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// 阅读态 Markdown 排版（详情页卡片正文）。
///
/// 默认 H1 为 32px（markdown_widget 默认值），在手机详情页里一篇带 `# 标题` 的
/// 笔记会占掉三行巨字，把正文挤到屏幕外。这里把标题层级整体收敛一档，
/// 保留层级差异但不再喧宾夺主。
class ReadingTypography {
  ReadingTypography._();

  static const double _h1 = 22;
  static const double _h2 = 19;
  static const double _h3 = 17;
  static const double _h4 = 15.5;

  static TextStyle heading(double size, Color color) => TextStyle(
    fontSize: size,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static List<LeafConfig> configs(ColorScheme colorScheme) => [
    H1Config(style: heading(_h1, colorScheme.onSurface)),
    H2Config(style: heading(_h2, colorScheme.onSurface)),
    H3Config(style: heading(_h3, colorScheme.onSurface)),
    H4Config(style: heading(_h4, colorScheme.onSurface)),
    H5Config(style: heading(14.5, colorScheme.onSurface)),
    H6Config(style: heading(14, colorScheme.onSurfaceVariant)),
  ];
}
