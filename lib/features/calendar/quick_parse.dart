/// 自然语言快速建日程（本地规则解析，离线可用）。
///
/// iOS 日历支持"打字即建日程"（配合自然语言），这里把中文口语里最常见的
/// 时间/地点表达解析成结构化字段，先填进编辑器让用户确认，**不直接落库**。
///
/// 支持：
/// - 日期：今天/明天/后天/大后天、周X/下周X/本周X、X月X日/ X号
/// - 时刻：上午/下午/晚上/中午/凌晨 + N点(半|N分)、N:MM、整点
/// - 时段：到 X点 / N小时 / N分钟
/// - 地点：在 XX / @XX / 含「室 厅 楼 机场 酒店 公司 咖啡 家」的尾缀短语
class QuickParseResult {
  final String title;
  final DateTime? start;
  final DateTime? end;
  final String? location;

  /// 0~1，命中的要素越多越高（调用方可据此决定是否高亮提示）
  final double confidence;

  const QuickParseResult({
    required this.title,
    this.start,
    this.end,
    this.location,
    this.confidence = 0,
  });
}

const _weekdayNames = {
  '一': DateTime.monday,
  '二': DateTime.tuesday,
  '三': DateTime.wednesday,
  '四': DateTime.thursday,
  '五': DateTime.friday,
  '六': DateTime.saturday,
  '日': DateTime.sunday,
  '天': DateTime.sunday,
};

/// 解析一句中文（可含英文/数字），返回可预填的事件字段。
QuickParseResult parseQuickAdd(String input, {DateTime? now}) {
  final base = now ?? DateTime.now();
  var text = input.trim();
  if (text.isEmpty) {
    return const QuickParseResult(title: '');
  }

  double confidence = 0;
  DateTime? day;
  DateTime? start;
  DateTime? end;
  String? location;

  // ---------- 1) 日期 ----------
  final dayPatterns = <RegExp, DateTime Function(DateTime)>{
    RegExp(r'大后天'): (n) => n.add(const Duration(days: 3)),
    RegExp(r'后天'): (n) => n.add(const Duration(days: 2)),
    RegExp(r'明天|明日'): (n) => n.add(const Duration(days: 1)),
    RegExp(r'今天|今日'): (n) => n,
  };
  for (final entry in dayPatterns.entries) {
    final m = entry.key.firstMatch(text);
    if (m != null) {
      day = _dateOnly(entry.value(base));
      text = text.replaceRange(m.start, m.end, ' ');
      confidence += 0.35;
      break;
    }
  }

  if (day == null) {
    final weekMatch = RegExp(r'(下|本|这)?(周|星期|礼拜)([一二三四五六日天])').firstMatch(text);
    if (weekMatch != null) {
      final prefix = weekMatch.group(1) ?? '';
      final target = _weekdayNames[weekMatch.group(3)!]!;
      var delta = (target - base.weekday + 7) % 7;
      if (prefix == '下') delta += 7;
      // 不带前缀且已经过了那天，按"下周"理解（口语习惯）
      day = _dateOnly(base.add(Duration(days: delta)));
      text = text.replaceRange(weekMatch.start, weekMatch.end, ' ');
      confidence += 0.3;
    }
  }

  if (day == null) {
    final md = RegExp(r'(\d{1,2})月(\d{1,2})[日号]').firstMatch(text);
    if (md != null) {
      final month = int.parse(md.group(1)!);
      final dayOfMonth = int.parse(md.group(2)!);
      var candidate = DateTime(base.year, month, dayOfMonth);
      if (candidate.isBefore(_dateOnly(base))) {
        candidate = DateTime(base.year + 1, month, dayOfMonth);
      }
      day = candidate;
      text = text.replaceRange(md.start, md.end, ' ');
      confidence += 0.35;
    } else {
      final d = RegExp(r'(?<![\d:])(\d{1,2})[日号]').firstMatch(text);
      if (d != null) {
        final dayOfMonth = int.parse(d.group(1)!);
        var candidate = DateTime(base.year, base.month, dayOfMonth);
        if (candidate.isBefore(_dateOnly(base))) {
          candidate = DateTime(base.year, base.month + 1, dayOfMonth);
        }
        day = candidate;
        text = text.replaceRange(d.start, d.end, ' ');
        confidence += 0.25;
      }
    }
  }

  // ---------- 2) 时刻 ----------
  var hour = -1;
  var minute = 0;
  final hm = RegExp(r'(\d{1,2})[:：](\d{2})').firstMatch(text);
  if (hm != null) {
    hour = int.parse(hm.group(1)!);
    minute = int.parse(hm.group(2)!);
    text = text.replaceRange(hm.start, hm.end, ' ');
    confidence += 0.3;
  } else {
    final hz = RegExp(r'(\d{1,2}|两|半)(?:点|时)(半|一刻|(\d{1,2})分?)?').firstMatch(text);
    if (hz != null) {
      final raw = hz.group(1)!;
      hour = raw == '两' ? 2 : raw == '半' ? -1 : int.parse(raw);
      final tail = hz.group(2) ?? '';
      if (tail.startsWith('半')) {
        minute = 30;
      } else if (tail.startsWith('一刻')) {
        minute = 15;
      } else if (hz.group(3) != null) {
        minute = int.parse(hz.group(3)!);
      }
      text = text.replaceRange(hz.start, hz.end, ' ');
      confidence += 0.3;
    }
  }

  // 上午/下午/晚上/中午/凌晨/傍晚
  final meridiem = RegExp(r'(凌晨|早上|上午|中午|下午|傍晚|晚上|夜里)').firstMatch(text);
  if (meridiem != null) {
    final word = meridiem.group(1)!;
    if (hour < 0) hour = _defaultHourOf(word);
    if (hour >= 0) {
      if ((word == '下午' || word == '傍晚' || word == '晚上' || word == '夜里') &&
          hour < 12) {
        hour += 12;
      } else if (word == '中午' && hour < 12) {
        hour = hour <= 1 ? 12 + hour : hour;
      } else if (word == '凌晨' && hour == 12) {
        hour = 0;
      }
    }
    text = text.replaceRange(meridiem.start, meridiem.end, ' ');
    confidence += 0.2;
  }

  if (hour >= 0) {
    start = DateTime(
      (day ?? _dateOnly(base)).year,
      (day ?? _dateOnly(base)).month,
      (day ?? _dateOnly(base)).day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );
  }

  // ---------- 3) 时长 / 结束时间 ----------
  final until = RegExp(r'(?:到|至|-|~)(\d{1,2}|两)(?:点|时)(半)?').firstMatch(text);
  final durH = RegExp(r'(\d+(?:\.\d+)?)\s*(?:个)?小时').firstMatch(text);
  final durM = RegExp(r'(\d+)\s*分钟').firstMatch(text);
  if (until != null && start != null) {
    final raw = until.group(1)!;
    var endHour = raw == '两' ? 2 : int.parse(raw);
    if (endHour < start.hour && endHour + 12 <= 23) endHour += 12;
    end = DateTime(
      start.year,
      start.month,
      start.day,
      endHour,
      until.group(2) != null ? 30 : 0,
    );
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    text = text.replaceRange(until.start, until.end, ' ');
    confidence += 0.2;
  } else if (durH != null || durM != null) {
    final hours = durH == null ? 0.0 : double.parse(durH.group(1)!);
    final minutes = durM == null ? 0 : int.parse(durM.group(1)!);
    final span = Duration(
      minutes: (hours * 60).round() + minutes,
    );
    if (start != null && span > Duration.zero) {
      end = start.add(span);
    }
    final m2 = durH ?? durM!;
    text = text.replaceRange(m2.start, m2.end, ' ');
    confidence += 0.2;
  }
  if (start != null && end == null) {
    end = start.add(const Duration(hours: 1));
  }

  // ---------- 4) 地点 ----------
  final loc = RegExp(r'(?:在|@|地点[:：]?)([\u4e00-\u9fa5A-Za-z0-9\-_·]{2,20})')
      .firstMatch(text);
  if (loc != null) {
    final originalRaw = loc.group(1)!;
    var raw = originalRaw.trim();
    // 「在会议室A评审方案」要截到「会议室A」，而不是把后面的动作一起吞掉：
    // 优先截到常见场所后缀（含），否则最多保留 6 个字。
    final withSuffix = RegExp(
      r'^([\u4e00-\u9fa5A-Za-z0-9\-_·]{0,10}?'
      r'(?:会议室|会议厅|办公室|培训室|展厅|会客厅|机场|车站|酒店|咖啡|餐厅'
      r'|健身房|医院|学校|家|中心|大厦|园区)[A-Za-z0-9\-]*)',
    ).firstMatch(raw);
    if (withSuffix != null) {
      raw = withSuffix.group(1)!;
    } else if (raw.length > 6) {
      raw = raw.substring(0, 6);
    }
    location = raw;
    // 只吃掉真正认作地点的部分，剩下的词留给标题
    final rawStart = loc.end - originalRaw.length;
    text = text.replaceRange(
      rawStart,
      (rawStart + raw.length).clamp(0, text.length),
      ' ',
    );
    confidence += 0.15;
  } else {
    // 常见场所后缀：会议室 / 3号厅 / 虹桥机场 / 星巴克 …
    final tail = RegExp(
      r'([\u4e00-\u9fa5A-Za-z0-9]{2,12}(?:会议室|会议厅|办公室|培训室|展厅|会客厅|机场|车站|酒店|咖啡|餐厅|健身房|医院|学校|家))',
    ).firstMatch(text);
    if (tail != null) {
      location = tail.group(1)!.trim();
      text = text.replaceRange(tail.start, tail.end, ' ');
      confidence += 0.1;
    }
  }

  // ---------- 5) 标题 = 剩下的词 ----------
  var title = text
      .replaceAll(RegExp(r'[，,。.、;；!！?？]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (location != null) {
    // 地点已经抽走，前导的「在/@」就没意义了
    title = title.replaceFirst(RegExp(r'^(在|@)\s*'), '').trim();
  }

  return QuickParseResult(
    title: title,
    start: start,
    end: end,
    location: location,
    confidence: confidence.clamp(0.0, 1.0),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _defaultHourOf(String word) => switch (word) {
  '凌晨' => 6,
  '早上' => 8,
  '上午' => 10,
  '中午' => 12,
  '下午' => 15,
  '傍晚' => 18,
  '晚上' || '夜里' => 20,
  _ => 9,
};
