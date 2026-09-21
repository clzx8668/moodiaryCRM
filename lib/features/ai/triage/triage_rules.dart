import 'package:moodiary/features/ai/triage/triage_types.dart';

/// 第一级：**本地规则引擎**（零成本、零延迟、完全离线）。
///
/// 只做确定性判断：能不能用正则/词表说清楚的事情，绝不交给模型。
/// 每条规则都要能回答"为什么"（[TriageSignal.label]），
/// 因为用户最终看到的就是这些理由。
class TriageRules {
  TriageRules._();

  /// 长度门槛：太短的内容没有任何可"深度处理"的信息量。
  static const int minUsefulChars = 4;

  /// 到这个长度，内容大概率值得整理/摘要
  static const int longContentChars = 60;

  // ------------------------------------------------------------ 敏感信息

  /// 中国大陆手机号
  static final RegExp _phone = RegExp(r'(?<!\d)1[3-9]\d{9}(?!\d)');

  /// 身份证（15/18 位）
  static final RegExp _idCard = RegExp(
    r'(?<!\d)(\d{15}|\d{17}[\dXx])(?!\d)',
  );

  /// 银行卡（16-19 位，允许空格/短横线分隔）
  static final RegExp _bankCard = RegExp(
    r'(?<!\d)(\d{4}[ -]?){3,4}\d{1,4}(?!\d)',
  );

  /// 邮箱
  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );

  /// 疑似 API Key / 密钥（长串随机字母数字）
  static final RegExp _secret = RegExp(
    r'(?<![A-Za-z0-9])(sk|api[_-]?key|token|secret)[-_:= ]*[A-Za-z0-9_\-]{16,}',
    caseSensitive: false,
  );

  /// 密码类关键词（和"密码"同句且有字符）
  static final RegExp _passwordHint = RegExp(r'密码|口令|password', caseSensitive: false);

  /// 检测敏感信息，返回命中的类型名（空 = 没有）。
  ///
  /// 这一层是**隐私闸门**：命中后默认不上云，而不是"问一下再传"。
  static List<String> detectSensitive(String text) {
    final kinds = <String>[];
    if (_phone.hasMatch(text)) kinds.add('手机号');

    // 身份证与银行卡都是长数字串，顺序很重要：
    // 先按**身份证的位数特征**（15/18/17+X）判，避免 18 位身份证被当成银行卡。
    final idMatch = _idCard.firstMatch(text);
    if (idMatch != null) {
      kinds.add('身份证号');
    } else if (_bankCard.hasMatch(text)) {
      // 银行卡：16-19 位，且不是身份证那两种位数
      final digits = _bankCard.firstMatch(text)!.group(0)!.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      if (digits.length != 15 && digits.length != 18) {
        kinds.add('银行卡号');
      }
    }
    if (_email.hasMatch(text)) kinds.add('邮箱');
    if (_secret.hasMatch(text)) kinds.add('密钥/Token');
    if (_passwordHint.hasMatch(text) && _hasDigitRun(text)) {
      kinds.add('密码');
    }
    return kinds;
  }

  /// "密码 + 像密码的值"才算敏感：≥6 位数字，或 4 位以上混合字母数字。
  /// 只写"我忘了密码"（没有值）不算。
  static bool _hasDigitRun(String text) =>
      RegExp(r'\d{6,}').hasMatch(text) ||
      RegExp(r'[A-Za-z0-9]{4,}').allMatches(text).any(
        (m) => m.group(0)!.length >= 4 &&
            RegExp(r'\d').hasMatch(m.group(0)!) &&
            RegExp(r'[A-Za-z]').hasMatch(m.group(0)!),
      );

  // ------------------------------------------------------------ 抽取信号

  /// 待办 / 日程 / 提醒信号
  static const List<String> todoSignals = [
    '待办',
    '提醒',
    '记得',
    '别忘了',
    '要交',
    '截止',
    'deadline',
    '安排',
    '预约',
    '会议',
    '开会',
    '明天',
    '后天',
    '下周',
    '下个月',
    '几点',
    '上午',
    '下午',
    '晚上',
    '点前',
    '闹钟',
  ];

  /// CRM / 商业信息信号（客户、报价、合同…）
  static const List<String> crmSignals = [
    '客户',
    '报价',
    '合同',
    '签约',
    '回款',
    '发票',
    '对接',
    '需求',
    '方案',
    '预算',
    '采购',
    '招标',
  ];

  /// 情绪 / 复盘信号（这类内容做摘要反而不合适，倾向本地）
  static const List<String> journalSignals = [
    '今天心情',
    '心情',
    '有点累',
    '好开心',
    '难过',
    '焦虑',
    '复盘',
    '反思',
  ];

  /// URL / 文件路径
  static final RegExp _url = RegExp(r'https?://\S+|www\.\S+');

  /// 是否含可抽取的结构化信息
  static bool hasExtractableSignal(String text) {
    if (_url.hasMatch(text)) return true;
    for (final s in todoSignals) {
      if (text.contains(s)) return true;
    }
    for (final s in crmSignals) {
      if (text.contains(s)) return true;
    }
    // 显式时间：03:30 / 15点 / 6点半
    if (RegExp(r'\d{1,2}\s*[:：]\s*\d{2}').hasMatch(text)) return true;
    if (RegExp(r'\d{1,2}\s*点(半|\d{1,2}分?)?').hasMatch(text)) return true;
    return false;
  }

  /// 是否含"待办"类的强信号（用于决定 extractPlan 要不要跑）
  static bool hasTodoSignal(String text) {
    for (final s in todoSignals) {
      if (text.contains(s)) return true;
    }
    return RegExp(r'\d{1,2}\s*[:：]\s*\d{2}').hasMatch(text);
  }

  /// 是否含 CRM 信号
  static bool hasCrmSignal(String text) {
    for (final s in crmSignals) {
      if (text.contains(s)) return true;
    }
    return false;
  }

  /// 是否是"私人情绪记录"（隐私倾向本地）
  static bool looksPrivateJournal(String text) {
    for (final s in journalSignals) {
      if (text.contains(s)) return true;
    }
    return false;
  }

  // ------------------------------------------------------------ 标注信号

  /// 标签信号词（出现这些词说明内容有"主题"可打标签）
  static const List<String> tagTopicSignals = [
    '项目',
    '版本',
    '发布',
    '需求',
    'bug',
    '问题',
    '方案',
    '计划',
    '读书',
    '电影',
    '旅行',
    '学习',
    '会议',
    '记录',
    '想法',
    '灵感',
    '笔记',
  ];

  /// 是否含标签/主题信号
  static bool hasTopicSignal(String text) {
    for (final s in tagTopicSignals) {
      if (text.contains(s)) return true;
    }
    return false;
  }

  /// 是否已经是"结构化文本"（有标点、分点符号）——这类内容标签更有价值
  static bool looksStructured(String text) {
    final punct = RegExp(r'[。！？；]').allMatches(text).length;
    if (punct >= 2) return true;
    final newlines = '\n'.allMatches(text).length;
    if (punct + newlines >= 3) return true;
    if (punct >= 3) return true;
    // 分点符号：`- 甲` / `* 乙` / `1. 丙` / `1、丁` 都算
    if (RegExp(r'^\s*([-*·•]\s+|\d+\s*[.、)])', multiLine: true)
        .hasMatch(text)) {
      return true;
    }
    return false;
  }

  /// 纯符号/纯数字/无实义内容（例如"。。。"、"123"）
  static bool isTrivial(String text) {
    final t = text.replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return true;
    if (!RegExp(r'[\u4e00-\u9fffA-Za-z]').hasMatch(t)) return true;
    return t.length < minUsefulChars;
  }

  /// 只含"测试/占位"痕迹的内容（开发期常见，不值得花额度）
  static const List<String> placeholderSignals = [
    'test',
    '测试',
    'asdf',
    'aaaa',
    '1234',
    '哈哈',
  ];

  static bool looksPlaceholder(String text) {
    final t = text.trim().toLowerCase();
    if (t.length > 12) return false;
    for (final s in placeholderSignals) {
      if (t.contains(s)) return true;
    }
    return false;
  }

  /// 内容长度（去掉空白后的字符数）
  static int meaningfulLength(String text) =>
      text.replaceAll(RegExp(r'\s'), '').length;
}
