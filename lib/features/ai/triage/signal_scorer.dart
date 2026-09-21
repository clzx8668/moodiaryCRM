import 'package:moodiary/features/ai/triage/time_signals.dart';
import 'package:moodiary/features/ai/triage/triage_rules.dart';

/// 第一级的**打分机制**：不再"命中一个就送 AI"，而是累加分数、超过阈值才触发。
///
/// 分值设计（与产品约定一致）：
///
/// | 信号 | 分值 | 理由 |
/// | :-- | :-- | :-- |
/// | 命中时间正则 | **+3** | 日程/待办几乎一定带时间，是最强信号 |
/// | 命中待办关键词 | **+2** | "记得/别忘/要交" |
/// | 命中日程关键词 | **+2** | "开会/见面/约" |
/// | 句尾"吗/呢/？" | **-1** | 更像闲聊提问，不是要记的事 |
/// | 文本 < 8 字 | **-1** | 太短，多半是随手记 |
///
/// **总分 ≥ [threshold]（默认 3）** → 送 AI；否则本地保存。
/// 这样可以挡掉绝大多数普通笔记，只让真正含日程/待办的走 AI。
class SignalScorer {
  SignalScorer._();

  /// 触发阈值
  static const int threshold = 3;

  /// 各项权重
  static const int wTime = 3;
  /// 低特异性时间词（今天/昨天…）只给 1 分：它是时间框架，不是"有事要办"
  static const int wTimeLowSpecificity = 1;
  static const int wTodo = 2;
  static const int wSchedule = 2;
  static const int pChatty = -1;
  static const int pTooShort = -1;
  static const int pPlaceholder = -3;

  /// 最短有意义长度
  static const int minUsefulLength = 6;

  /// 评分（纯函数）
  static SignalScore score(String text) {
    final t = text.trim();
    final hits = <SignalHit>[];
    var total = 0;

    // 1) 时间表达（最强）
    final times = TimeSignals.find(t);
    if (times.isNotEmpty) {
      final specific = times.any((x) => !TimeSignals.isLowSpecificity(x));
      final delta = specific ? wTime : wTimeLowSpecificity;
      total += delta;
      hits.add(
        SignalHit(
          kind: SignalKind.time,
          delta: delta,
          detail: specific
              ? '时间：${times.take(3).join('、')}'
              : '时间框架：${times.take(3).join('、')}（低特异性）',
        ),
      );
    }

    // 2) 待办关键词
    final todos = _matches(t, TriageRules.todoKeywords);
    if (todos.isNotEmpty) {
      total += wTodo;
      hits.add(
        SignalHit(
          kind: SignalKind.todo,
          delta: wTodo,
          detail: '待办词：${todos.take(3).join('、')}',
        ),
      );
    }

    // 3) 日程关键词
    final schedules = _matches(t, TriageRules.scheduleKeywords);
    if (schedules.isNotEmpty) {
      total += wSchedule;
      hits.add(
        SignalHit(
          kind: SignalKind.schedule,
          delta: wSchedule,
          detail: '日程词：${schedules.take(3).join('、')}',
        ),
      );
    }

    // 3.5) 商业/CRM 关键词（与日程同权：这类内容做抽取同样有价值）
    final crm = _matches(t, TriageRules.crmSignals);
    if (crm.isNotEmpty) {
      total += wSchedule;
      hits.add(
        SignalHit(
          kind: SignalKind.crm,
          delta: wSchedule,
          detail: '商机词：${crm.take(3).join('、')}',
        ),
      );
    }

    // 4) 闲聊特征：句尾语气词/问号
    if (_looksChatty(t)) {
      total += pChatty;
      hits.add(
        const SignalHit(
          kind: SignalKind.chatty,
          delta: pChatty,
          detail: '像闲聊/提问（句尾语气词或问号）',
        ),
      );
    }

    // 5) 太短
    final len = TriageRules.meaningfulLength(t);
    if (len < minUsefulLength) {
      total += pTooShort;
      hits.add(
        SignalHit(
          kind: SignalKind.tooShort,
          delta: pTooShort,
          detail: '太短（$len 字）',
        ),
      );
    }

    // 6) 测试/占位内容重罚（避免开发期噪声）
    if (TriageRules.looksPlaceholder(t)) {
      total += pPlaceholder;
      hits.add(
        const SignalHit(
          kind: SignalKind.placeholder,
          delta: pPlaceholder,
          detail: '疑似测试/占位内容',
        ),
      );
    }

    return SignalScore(total: total, hits: hits);
  }

  /// 是否达到"送 AI"门槛
  static bool shouldEscalate(String text) => score(text).total >= threshold;

  /// 句尾像闲聊/提问
  static bool _looksChatty(String text) {
    final t = text.trimRight();
    if (t.isEmpty) return false;
    if (t.endsWith('？') || t.endsWith('?')) return true;
    const enders = ['吗', '呢', '吧', '么'];
    for (final e in enders) {
      if (t.endsWith(e)) return true;
    }
    return false;
  }

  static List<String> _matches(String text, List<String> words) {
    final out = <String>[];
    for (final w in words) {
      if (text.contains(w)) out.add(w);
    }
    return out;
  }
}

/// 信号类别（用于 UI 展示与测试断言）
enum SignalKind { time, todo, schedule, crm, chatty, tooShort, placeholder }

/// 单个命中项
class SignalHit {
  final SignalKind kind;
  final int delta;
  final String detail;

  const SignalHit({
    required this.kind,
    required this.delta,
    required this.detail,
  });

  @override
  String toString() => '${delta >= 0 ? '+' : ''}$delta $detail';
}

/// 打分结果
class SignalScore {
  final int total;
  final List<SignalHit> hits;

  const SignalScore({required this.total, required this.hits});

  bool get shouldEscalate => total >= SignalScorer.threshold;

  /// 一行解释（`+3 时间：明天 · +2 待办词：记得`）
  String get explanation =>
      hits.isEmpty ? '未命中任何信号' : hits.map((h) => h.toString()).join(' · ');

  @override
  String toString() => 'SignalScore($total, $explanation)';
}
