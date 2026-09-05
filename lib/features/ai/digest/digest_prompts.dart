/// 周期回望粒度。
enum DigestPeriod { daily, weekly }

/// 参与回望的单条摘要。
class DigestItem {
  final String title;
  final String summary;
  final List<String> tags;

  const DigestItem({
    required this.title,
    required this.summary,
    this.tags = const [],
  });
}

/// 回望 Prompt 构建（纯函数，可单测）。
class DigestPrompts {
  DigestPrompts._();

  static const String system =
      '你是一个善于梳理的个人知识助理，用中文输出，语气克制、有洞察，不空话。';

  static String build(
    DigestPeriod period,
    String dateLabel,
    List<DigestItem> items,
  ) {
    final name = period == DigestPeriod.daily ? '每日回顾' : '每周总结';
    final lines = items.isEmpty
        ? '（本周期暂无记录）'
        : items
              .map(
                (i) =>
                    '- 《${i.title}》${i.summary.isNotEmpty ? '：${i.summary}' : ''}'
                    '${i.tags.isEmpty ? '' : '  [#${i.tags.join(' #')}]'}',
              )
              .join('\n');
    return '''
$system

请生成「$name（$dateLabel）」，包含：
1. 本周/今日记录概况（数量、高频话题）；
2. 2-3 条值得回看的要点；
3. 1 条面向下一步的提示（可关联待办/知识库）。
直接输出正文，用 Markdown。

记录清单：
$lines
''';
  }
}
