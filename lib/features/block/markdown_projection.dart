import 'dart:convert';

import 'models/block.dart';

/// 双模态数据架构的"投影层"（智能详情页-双模态架构设计 3.3）。
///
/// 把任意 Block 投影为 Markdown 文本，作为阅读渲染 / 导出 / 全文搜索 /
/// 向量化（RAG）的统一输入。纯函数，禁止 IO。
class MarkdownProjection {
  /// 「内容即产物」的 AI 模板：先落地管线生成的正文（抓取正文/图片识别/语音转写）
  /// —— 这些要进笔记正文与列表预览。
  ///
  /// 其余 AI 卡片（提取待办/点评/发芽/作品/模板处理…）属于**派生结果**，
  /// 不进正文投影：否则列表预览会掺进 AI 生成的内容，搜索、向量检索、以及
  /// 再次喂给模型的语料都会被 AI 自己的输出污染（批次 96 用户反馈「内容干扰」）。
  static const Set<String> contentAiTemplates = {
    'link_fetch',
    'vision_ocr',
    'voice_transcribe',
  };

  /// 单条记录聚合投影：未删除 Block 按 sortOrder 升序拼接。
  static String aggregate(List<Block> blocks) {
    final visible = blocks.where((b) => !b.isDeleted).where((b) {
      if (!b.meta.isAi) return true; // 普通卡片
      if (b.meta.role.isNotEmpty) return false; // AI 对话：与笔记分区
      return contentAiTemplates.contains(b.meta.aiTemplate); // 派生卡片不进正文
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return visible
        .map(blockToMarkdown)
        .where((s) => s.trim().isNotEmpty)
        .join('\n\n');
  }

  /// 单个 Block → Markdown
  static String blockToMarkdown(Block block) {
    switch (block.blockType) {
      case BlockType.text:
        return block.content.trim();
      case BlockType.code:
        final content = block.content.trim();
        if (content.isEmpty) return '';
        return '```\n$content\n```';
      case BlockType.todo:
        return _todoToMarkdown(block.content);
      case BlockType.smartEntity:
        return _entityToMarkdown(block.content);
      case BlockType.image:
        final name = block.content.trim();
        return name.isEmpty ? '' : '![]($name)';
      case BlockType.chart:
        return _chartToMarkdown(block.content);
      case BlockType.aiStream:
        final text = block.streamComplete
            ? block.content
            : block.streamBuffer.isNotEmpty
            ? block.streamBuffer
            : block.content;
        return text.trim();
    }
  }

  /// todo：`- [ ]/[-x] 文本`（兼容 `[x]` 前缀与 JSON 两种存量格式）
  static String _todoToMarkdown(String raw) {
    var content = raw.trim();
    if (content.isEmpty) return '';
    final json = _tryDecodeObject(content);
    if (json != null) {
      final text = (json['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return '';
      final done = json['done'] == true;
      return '- [${done ? 'x' : ' '}] $text';
    }
    if (RegExp(r'^\[[ xX]\]\s*').hasMatch(content)) {
      return '- $content';
    }
    // 去掉已存在的列表前缀（`- ` / `* `），避免 `- [ ] - xxx` 双横线
    content = content.replaceFirst(RegExp(r'^[-*]\s+'), '');
    return '- [ ] $content';
  }

  /// smartEntity：`**类型**：名称 · 状态`
  static String _entityToMarkdown(String raw) {
    final json = _tryDecodeObject(raw.trim());
    if (json == null) return raw.trim();
    final name = (json['name'] as String?)?.trim() ?? '';
    final entityType = (json['entity_type'] as String?)?.trim() ?? '';
    final status = (json['status'] as String?)?.trim() ?? '';
    if (name.isEmpty) return raw.trim();
    final label = entityType.isEmpty ? '实体' : entityType;
    final parts = [name, if (status.isNotEmpty) status];
    return '**$label**：${parts.join(' · ')}';
  }

  /// chart：`**图表**：<类型> <n> 项`
  static String _chartToMarkdown(String raw) {
    final json = _tryDecodeObject(raw.trim());
    if (json == null) return raw.trim();
    final chartType = (json['type'] as String?)?.trim() ?? 'chart';
    final data = json['data'];
    final count = data is List
        ? data.length
        : data is Map
        ? data.length
        : 0;
    return '**图表**：$chartType $count 项';
  }

  static Map<String, dynamic>? _tryDecodeObject(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
