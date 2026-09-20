/// 中文语音稿的本地标点后处理（纯逻辑，可单测）。
///
/// 为什么需要它：端侧用的 Paraformer 词表里**只有字和词，没有任何标点符号**
/// （已核对 8359 条 token：句号/逗号/问号/感叹号一个都没有），
/// 所以原始识别结果必然是"一长串没有断句的字"。
///
/// 这里用**规则**补标点，而不是再挂一个标点模型：
/// - 收益：零额外下载（标点模型约 70-270MB）、零推理延迟、离线可用；
/// - 依据：口语稿的断句线索相当稳定——句末语气词（吗/呢/吧/啊）、
///   连接词（但是/所以/然后…）、长停顿处的从属标记（因为/如果/就是…）；
/// - 边界：这是**启发式**，只求"读起来有标点、能断句"，
///   不追求书面语的精确标点。详情页仍可用云端精修拿到更好的标点。
///
/// 设计为纯函数，方便以后整体替换成模型版（`applyToTranscript` 是唯一入口）。
class CnPunctuator {
  CnPunctuator._();

  /// 句末语气词：出现在句中/句尾时几乎一定是句子结束
  static const List<String> _sentenceEnders = [
    '吗',
    '吧',
    '呢',
    '啊',
    '呀',
    '嘛',
    '哦',
    '噢',
    '哈',
    '啦',
    '咯',
    '哎',
  ];

  /// 疑问词结尾 → 问号
  static const List<String> _questionEnders = [
    '什么',
    '怎么',
    '为什么',
    '怎么回事',
    '怎么样',
    '怎么办',
    '哪里',
    '哪儿',
    '是否',
  ];

  /// 转折/因果/顺序连接词：前面多半该断开
  static const List<String> _clauseBreakers = [
    '但是',
    '可是',
    '不过',
    '然后',
    '所以',
    '因此',
    '另外',
    '而且',
    '并且',
    '同时',
    '接下来',
    '首先',
    '其次',
    '最后',
    '总之',
    '另外的',
  ];

  /// 从属/条件标记：后面是一个从句，前面用逗号
  static const List<String> _commaMarkers = [
    '因为',
    '虽然',
    '即使',
    '除非',
    '只要',
    '要是',
    '比如说',
    '例如',
    '其实',
    '当然',
    '至于',
    '关于',
  ];

  /// 句首口语填充词（只在**整段开头**才敢删，句中可能是正常词）
  static const List<String> _leadingFillers = [
    '嗯',
    '呃',
    '额',
    '唉',
    '那么',
    '这个',
    '那个',
    '就是',
  ];

  /// 一段话最长多少字就强制断句（避免真的一逗到底）
  static const int _maxClauseChars = 26;

  /// 收尾：清掉多余标点、补上句末标点
  static String finish(String text) => _post(_normalize(text));

  /// 把新识别的一句并进已有文本，并在连接处补标点。
  ///
  /// 返回值一定是"可直接上屏"的文本；不会出现两个标点连在一起，
  /// 也不会出现 `。，` 这类组合。
  static String join(String base, String sentence) {
    final incoming = _normalize(sentence);
    if (incoming.isEmpty) return base;
    if (base.trim().isEmpty) return _post(incoming);

    final separator = _separatorWhenAppending(base, incoming);
    return _post(_trimEndPunct(base) + separator + incoming);
  }

  /// 决定"接下去这句"与"已有文本"之间该用什么标点。
  static String _separatorWhenAppending(String base, String incoming) {
    if (_endsWithPunct(base)) return '';
    // 已有内容以句末语气词收尾 → 前面其实已经说完了一句
    if (_endsWithSentenceEnder(base)) {
      return _looksLikeQuestion(base) ? '？' : '。';
    }
    // 新句以连接词开头 → 前面断开
    if (_startsAt(incoming, _clauseBreakers)) return '。';
    // 已有内容偏短，多半是同一句被 VAD 切成了两段 → 用逗号接起来
    if (_chineseLength(base) < 8) return '，';
    return '。';
  }

  /// 段内标点：插逗号/问号/句号，并在过长时强制断句
  static String _post(String text) {
    if (text.isEmpty) return text;
    final buf = StringBuffer();
    var clause = 0;
    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      buf.write(ch);
      clause++;
      i++;
      if (clause == 0) continue;

      final rest = text.substring(i);
      if (_isPunct(ch)) {
        clause = 0;
        continue;
      }

      // 1) 句末语气词：后面若不是紧接着更多语气词，就断句
      if (_sentenceEnders.contains(ch) &&
          !_startsAt(rest, _sentenceEnders)) {
        // 语气词后面紧跟逗号类的停顿标记 → 这是**句中**语气词
        // （如"我想说的是呢，所以…"），只补逗号，不硬断成两句
        final pause =
            rest.isNotEmpty && _isPunct(rest[0]) && _isClausePunct(rest[0]);
        if (pause) {
          clause = 0;
          continue;
        }
        final isQuestion = _looksLikeQuestion(buf.toString());
        buf.write(isQuestion ? '？' : '。');
        clause = 0;
        continue;
      }

      // 2) 连接词：新句子开始，前句收尾
      if (clause >= 3 && _startsAt(rest, _clauseBreakers)) {
        buf.write('。');
        clause = 0;
        continue;
      }

      // 3) 从句标记：这里多半是个停顿，用逗号
      if (clause >= 2 && _startsAt(rest, _commaMarkers)) {
        buf.write('，');
        clause = 0;
        continue;
      }

      // 4) 太长强制断句
      if (clause >= _maxClauseChars) {
        buf.write('。');
        clause = 0;
      }
    }
    return _finalizeEnding(buf.toString());
  }

  /// 结尾收口：以标点结束；否则按语气补句号/问号
  static String _finalizeEnding(String text) {
    final t = _trimEndPunct(text);
    if (t.isEmpty) return t;
    return t + (_looksLikeQuestion(t) ? '？' : '。');
  }

  /// 是否像疑问句（结尾或整体含疑问标记）
  static bool _looksLikeQuestion(String text) {
    final t = text.trimRight();
    if (t.isEmpty) return false;
    if (t.endsWith('吗') || t.endsWith('呢')) return true;
    for (final q in _questionEnders) {
      if (t.endsWith(q)) return true;
    }
    return false;
  }

  /// 归一化：去空白、统一全角标点、去掉句首填充词与重复标点
  static String _normalize(String raw) {
    var t = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(',', '，')
        .replaceAll('.', '。')
        .replaceAll('?', '？')
        .replaceAll('!', '！');
    // 合并连续标点，只保留第一个
    t = t.replaceAllMapped(
      RegExp(r'([，。？！、；：])\1+'),
      (m) => m.group(1)!,
    );
    t = _stripLeadingFillers(t);
    // 去掉开头的标点（口语稿常见"嗯，"被删后残留的逗号）
    while (t.isNotEmpty && _isPunct(t[0])) {
      t = t.substring(1);
    }
    return t.trim();
  }

  static String _stripLeadingFillers(String text) {
    var t = text;
    var changed = true;
    while (changed) {
      changed = false;
      for (final f in _leadingFillers) {
        if (t.startsWith(f)) {
          t = t.substring(f.length);
          while (t.isNotEmpty && _isPunct(t[0])) {
            t = t.substring(1);
          }
          changed = true;
        }
      }
    }
    return t;
  }

  static String _trimEndPunct(String text) {
    var t = text.trimRight();
    while (t.isNotEmpty && _isPunct(t[t.length - 1])) {
      t = t.substring(0, t.length - 1).trimRight();
    }
    return t;
  }

  static bool _endsWithPunct(String text) {
    final t = text.trimRight();
    return t.isNotEmpty && _isPunct(t[t.length - 1]);
  }

  static bool _endsWithSentenceEnder(String text) {
    final t = _trimEndPunct(text);
    if (t.isEmpty) return false;
    return _sentenceEnders.contains(t[t.length - 1]);
  }

  static bool _startsAt(String text, List<String> cues) {
    for (final c in cues) {
      if (text.startsWith(c)) return true;
    }
    return false;
  }

  static bool _isPunct(String ch) => '，。？！、；：“”‘’《》（）'.contains(ch);

  /// 逗号类（句中）标点
  static bool _isClausePunct(String ch) => '，、；：'.contains(ch);

  /// 只数中文字符（ASCII/数字不计入断句长度）
  static int _chineseLength(String text) {
    var n = 0;
    for (final r in text.runes) {
      if (r >= 0x4E00 && r <= 0x9FFF) n++;
    }
    return n;
  }
}
