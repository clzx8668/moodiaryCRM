/// AI 模板定义与 Prompt 表（遗留项 1：模板 AI 处理真实接入）。
///
/// 模板 id 与快速收集面板的模板选择一致（待办/打卡/扩写/润色/会议记录/翻译）。
/// Prompt 是纯字符串常量，方便测试快照与后续多语言化。
class AiTemplates {
  AiTemplates._();

  static const String todo = 'todo';
  static const String checkin = 'checkin';
  static const String expand = 'expand';
  static const String polish = 'polish';
  static const String meeting = 'meeting';
  static const String translate = 'translate';
  static const String summary = 'summary';

  static const List<String> all = [
    todo,
    checkin,
    expand,
    polish,
    meeting,
    translate,
    summary,
  ];

  static String label(String id) {
    switch (id) {
      case todo:
        return '待办';
      case checkin:
        return '打卡';
      case expand:
        return '扩写';
      case polish:
        return '润色';
      case meeting:
        return '会议记录';
      case translate:
        return '翻译';
      case summary:
        return '总结';
      default:
        return id;
    }
  }

  /// 模板系统 Prompt。`{content}` 占位符由调用方替换为原文。
  static String prompt(String id) {
    switch (id) {
      case todo:
        return '请把下面的内容整理为可执行的待办清单：\n'
            '1. 每行一个待办，使用 Markdown 任务列表语法 `- [ ] `；\n'
            '2. 保留关键时间与责任人信息；\n'
            '3. 不要输出其他解释文字。\n\n'
            '内容：\n{content}';
      case checkin:
        return '请把下面的内容整理为打卡记录：\n'
            '1. 输出一段简洁的总结（3 句话以内）；\n'
            '2. 保留日期与关键数据。\n\n'
            '内容：\n{content}';
      case expand:
        return '请扩写下面的内容：\n'
            '1. 保持原意，补充合理的细节与上下文；\n'
            '2. 使用 Markdown 排版，适当分段与小标题；\n'
            '3. 语气自然，不要编造事实。\n\n'
            '内容：\n{content}';
      case polish:
        return '请润色下面的内容：\n'
            '1. 修正语病与错别字，让表达更流畅专业；\n'
            '2. 保留原意与全部事实信息；\n'
            '3. 直接输出润色结果，不要解释。\n\n'
            '内容：\n{content}';
      case meeting:
        return '请把下面的内容整理为会议记录：\n'
            '1. 结构：会议要点 / 结论 / 行动项（- [ ] 开头）；\n'
            '2. 行动项标注责任人（如可推断）；\n'
            '3. 使用 Markdown 排版。\n\n'
            '内容：\n{content}';
      case translate:
        return '请把下面的内容翻译成英文（若原文是英文则翻译成中文）：\n'
            '1. 保留 Markdown 格式；\n'
            '2. 直接输出译文，不要解释。\n\n'
            '内容：\n{content}';
      case summary:
        return '请总结下面的内容：\n'
            '1. 输出 3~5 条要点（每条一行）；\n'
            '2. 保留关键数字与结论；\n'
            '3. 使用 Markdown 列表。\n\n'
            '内容：\n{content}';
      default:
        return '请处理下面的内容：\n{content}';
    }
  }

  /// 组装最终请求 Prompt
  static String build(String id, String content) {
    return prompt(id).replaceAll('{content}', content);
  }
}
