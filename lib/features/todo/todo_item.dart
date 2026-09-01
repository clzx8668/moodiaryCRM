/// 跨源统一待办条目（P2.2：AI 提取 Todo Block + Twenty Tasks 聚合）。
///
/// 本地来源（[TodoSource.localBlock]）与 CRM 来源（[TodoSource.crmTask]）
/// 统一投影为同一结构，日历页待办视图与后续时间轴可复用。
enum TodoSource { localBlock, crmTask, crmEvent, schedule }

class TodoItem {
  /// 稳定业务键：本地为 `blockId:lineIndex`，CRM 为 twentyId（空则本地缓存 id）
  final String id;

  final TodoSource source;

  /// 任务文本
  final String text;

  /// 完成状态
  final bool done;

  /// 到期日（可空；本地 Block 从 meta.dueDate 读取，CRM 从 dueAt/dueDate 读取）
  final DateTime? dueDate;

  /// 兜底排序时间：本地为 Block 更新时间，CRM 为缓存更新时间
  final DateTime time;

  /// 本地待办关联日记 ID（CRM 来源为空）
  final String diaryId;

  /// 本地待办 Block ID（CRM 来源为空）
  final String blockId;

  /// 任务行在 Block 内容中的行号（CRM 来源为 -1），勾选时定位改写
  final int lineIndex;

  /// Twenty 任务对象 ID（本地来源为空）
  final String twentyId;

  /// 本地 Schedule ID（schedule 来源；其他来源为空）
  final String scheduleId;

  /// 浮动待办（无固定日期，只在"今日"收件箱聚合）
  final bool isFloating;

  /// 优先级（0 无 / 1 低 / 2 中 / 3 高）
  final int priority;

  /// 来源标题（日记标题 / Twenty 对象名），用于详情跳转与展示
  final String title;

  const TodoItem({
    required this.id,
    required this.source,
    required this.text,
    required this.done,
    this.dueDate,
    required this.time,
    this.diaryId = '',
    this.blockId = '',
    this.lineIndex = -1,
    this.twentyId = '',
    this.scheduleId = '',
    this.isFloating = false,
    this.priority = 0,
    this.title = '',
  });

  bool get isLocal => source == TodoSource.localBlock;

  bool get isCrm => source == TodoSource.crmTask;

  bool get isSchedule => source == TodoSource.schedule;

  /// 是否过期：有到期日、未完成、且到期日早于今天（浮动待办不判过期）。
  bool get isOverdue {
    if (done) return false;
    final due = dueDate;
    if (due == null) return false;
    final today = DateTime.now();
    final d = DateTime(due.year, due.month, due.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.isBefore(t);
  }

  /// 是否加急：优先级高。
  bool get isUrgent => priority >= 3;

  /// 展示用日期：有到期日取到期日，否则取兜底时间
  DateTime get effectiveDate => dueDate ?? time;
}
