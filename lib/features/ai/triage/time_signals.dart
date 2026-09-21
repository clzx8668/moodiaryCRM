/// 时间/日期表达识别（第一级规则里**最强**的信号）。
///
/// 为什么单独成文件：日程与待办几乎一定带时间表达，
/// "命中时间"比"命中某个词"可靠得多，所以给它最高权重（+3）。
/// 这里只做**纯正则**，毫秒级、完全离线。
class TimeSignals {
  TimeSignals._();

  /// 相对日期词
  static final RegExp _relativeDay = RegExp(
    r'(今天|今日|明天|明日|后天|大后天|昨晚|今晚|明晚|前天|昨天)',
  );

  /// **低特异性**时间词：只是给句子一个时间框架，不代表"有事要办"。
  /// （"今天心情不错"不该因为一个"今天"就送 AI；但它仍是时间信号，给 +1 分。）
  static final RegExp _lowSpecificity = RegExp(r'^(今天|今日|昨天|前天|昨晚)$');

  /// 星期：下周三 / 周三 / 星期日 / 礼拜一
  static final RegExp _weekday = RegExp(
    r'((下|下下|本|这)?(周|星期|礼拜)[一二三四五六日天末])',
  );

  /// 绝对日期：3月5日 / 3月5号 / 5日 / 5号 / 2026-03-05 / 3/5
  static final RegExp _absoluteDate = RegExp(
    r'(\d{4}[-/年]\d{1,2}[-/月]\d{1,2}[日号]?'
    r'|\d{1,2}[-/]\d{1,2}'
    r'|\d{1,2}\s*月\s*\d{1,2}\s*[日号]'
    r'|\d{1,2}\s*[日号](?![前以]))',
  );

  /// 时刻：15:30 / 15：30 / 下午3点 / 晚上八点半 / 6点半 / 三点
  static final RegExp _clock = RegExp(
    r'((上午|下午|晚上|早上|中午|凌晨|傍晚|夜里)?\s*'
    r'(\d{1,2}|[一二三四五六七八九十两]+)\s*[点时]'
    r'(\s*半|\s*\d{1,2}\s*分?)?'
    r'|\d{1,2}\s*[:：]\s*\d{2}'
    r'|\d{1,2}\s*[点时]\s*前)',
  );

  /// 时间范围/截止表达：三天内 / 一周后 / 月底前 / 下个月
  // 两选一：① 数量 + 时间单位（三天内 / 一周后 / 2个月以内 / 半小时后）
  //         ② 相对周期（月底前 / 下个月 / 周末 / 尽快）
  static final RegExp _range = RegExp(
    r'(([一二三四五六七八九十两]|半|\d{1,3})\s*个?\s*'
    r'(天|日|周|星期|月|小时|分钟|分)(内|后|前|之前|以内|以后|之内)?'
    r'|(这|本|下|下下)?\s*个?\s*(周|月|季度|年)(内|前|之前|底|初|末|后|周末)'
    // 「下个月」这类"量词夹在中间"的写法单独列出，正则分支里容易漏
    r'|(这|本|下|上)\s*个月'
    r'|待会儿|一会儿|马上|尽快|月底|年底|周末|今晚|明早)',
  );

  /// 所有时间表达模式（按"越具体越靠前"排列，便于命中优先项）
  static final List<({String name, RegExp pattern})> patterns = [
    (name: '具体时刻', pattern: _clock),
    (name: '绝对日期', pattern: _absoluteDate),
    (name: '相对日期', pattern: _relativeDay),
    (name: '星期', pattern: _weekday),
    (name: '时间范围', pattern: _range),
  ];

  /// 命中的时间表达（去重，保留原文片段）
  static List<String> find(String text) {
    if (text.trim().isEmpty) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final p in patterns) {
      for (final m in p.pattern.allMatches(text)) {
        final hit = m.group(0)!.trim();
        if (hit.isEmpty) continue;
        if (seen.add(hit)) out.add(hit);
      }
    }
    return out;
  }

  /// 是否只是"低特异性"时间词（今天/昨天…）
  static bool isLowSpecificity(String token) =>
      _lowSpecificity.hasMatch(token.trim());

  /// 命中的时间表达里，是否包含**真正指向未来安排**的（非低特异性）
  static bool hasSpecific(String text) =>
      find(text).any((t) => !isLowSpecificity(t));

  /// 是否含时间表达
  static bool has(String text) => hasAny(text);

  static bool hasAny(String text) {
    for (final p in patterns) {
      if (p.pattern.hasMatch(text)) return true;
    }
    return false;
  }
}
