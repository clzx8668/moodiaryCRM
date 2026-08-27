import 'package:flutter/material.dart';

import 'models/block.dart';

/// Block 类型 → 主色（现代分类色，Linear/Notion/ima 柔和色系）。
///
/// 首页「块视图」卡片色条与详情页卡片背景共用，保证同一 Block
/// 在两个视图的颜色一一对应。
Color blockAccent(BlockType type) {
  return switch (type) {
    BlockType.text => const Color(0xFF4C9AFF),
    BlockType.todo => const Color(0xFF2EB67D),
    BlockType.image => const Color(0xFF9B6EF3),
    BlockType.aiStream => const Color(0xFF00B8D9),
    BlockType.smartEntity => const Color(0xFF7A5AF8),
    BlockType.chart => const Color(0xFFFFAB00),
    BlockType.code => const Color(0xFF64748B),
  };
}

/// 首页块视图色条颜色（沿用主色，保证与详情页背景对应）。
Color blockTypeColor(BlockType type, ColorScheme colorScheme) {
  return blockAccent(type);
}

/// 详情页块卡片背景色：主色在应用表面色上做低透明度混合，
/// 随当前主题（亮/暗）自适应，形成柔和的现代分类块背景。
Color blockBackground(BlockType type, ColorScheme colorScheme) {
  final accent = blockAccent(type);
  return Color.alphaBlend(
    accent.withAlpha(0x1A),
    colorScheme.surfaceContainerLow,
  );
}

/// Block 类型 → 简短中文标签。
String blockTypeLabel(BlockType type) {
  return switch (type) {
    BlockType.text => '笔记',
    BlockType.todo => '待办',
    BlockType.image => '图片',
    BlockType.aiStream => 'AI',
    BlockType.smartEntity => '实体',
    BlockType.chart => '图表',
    BlockType.code => '代码',
  };
}

/// meta.source → 来源徽标文案（详情页笔记卡展示）。
String blockSourceLabel(String source) {
  return switch (source) {
    BlockMeta.sourceInitial => '原始',
    BlockMeta.sourceAppended => '追加',
    BlockMeta.sourceAi => 'AI',
    BlockMeta.sourceImported => '导入',
    _ => source,
  };
}
