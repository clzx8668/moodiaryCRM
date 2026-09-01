import 'package:uuid/uuid.dart';

/// 重复规则（参考主流日历应用的重复选项）。
enum RepeatType {
  none('none', '不重复'),
  daily('daily', '每天'),
  weekly('weekly', '每周'),
  monthly('monthly', '每月'),
  yearly('yearly', '每年');

  final String value;
  final String label;

  const RepeatType(this.value, this.label);

  static RepeatType fromValue(String? value) => RepeatType.values.firstWhere(
    (e) => e.value == value,
    orElse: () => RepeatType.none,
  );
}

/// 优先级：0 无 / 1 低 / 2 中 / 3 高。
enum SchedulePriority {
  none(0, '无'),
  low(1, '低'),
  medium(2, '中'),
  high(3, '高');

  final int value;
  final String label;

  const SchedulePriority(this.value, this.label);

  static SchedulePriority fromValue(int? value) =>
      SchedulePriority.values.firstWhere(
        (e) => e.value == value,
        orElse: () => SchedulePriority.none,
      );
}

/// 子任务。
class ScheduleSubtask {
  String text;
  bool done;

  ScheduleSubtask({required this.text, this.done = false});

  factory ScheduleSubtask.fromJson(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return ScheduleSubtask(
      text: map['text']?.toString() ?? '',
      done: map['done'] == true,
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
}

/// 待办/日程实体（日历模块批次 B）。
class Schedule {
  String id = const Uuid().v7();

  String title = '';

  /// 备忘/备注
  String notes = '';

  DateTime startTime = DateTime.now();

  /// 结束时间（可空；null=单点）
  DateTime? endTime;

  bool allDay = false;

  /// 浮动待办（无固定日期）：只在"今日"收件箱聚合展示
  bool floating = false;

  RepeatType repeatType = RepeatType.none;

  /// 提前提醒分钟数（null=不提醒）
  int? remindOffsetMin;

  SchedulePriority priority = SchedulePriority.none;

  String? tag;

  /// 背景色（ARGB int）
  int? bgColor;

  bool done = false;

  List<ScheduleSubtask> subtasks = [];

  List<String> imageNames = [];

  String? linkedDiaryId;
  String? linkedBlockId;

  bool deleted = false;

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  Schedule();

  Schedule clone() => Schedule()
    ..id = id
    ..title = title
    ..notes = notes
    ..startTime = DateTime.fromMillisecondsSinceEpoch(
      startTime.millisecondsSinceEpoch,
    )
    ..endTime =
        endTime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                endTime!.millisecondsSinceEpoch,
              )
    ..allDay = allDay
    ..floating = floating
    ..repeatType = repeatType
    ..remindOffsetMin = remindOffsetMin
    ..priority = priority
    ..tag = tag
    ..bgColor = bgColor
    ..done = done
    ..subtasks = [
      for (final s in subtasks) ScheduleSubtask(text: s.text, done: s.done),
    ]
    ..imageNames = List.of(imageNames)
    ..linkedDiaryId = linkedDiaryId
    ..linkedBlockId = linkedBlockId
    ..deleted = deleted
    ..createdAt = DateTime.fromMillisecondsSinceEpoch(
      createdAt.millisecondsSinceEpoch,
    )
    ..updatedAt = DateTime.fromMillisecondsSinceEpoch(
      updatedAt.millisecondsSinceEpoch,
    );

  /// 展示用日期（去掉时分）
  DateTime get day =>
      DateTime(startTime.year, startTime.month, startTime.day);

  /// 结束日期（用于全天/跨天判断）
  DateTime get endDay => DateTime(
    (endTime ?? startTime).year,
    (endTime ?? startTime).month,
    (endTime ?? startTime).day,
  );

  /// 是否跨天
  bool get isMultiDay => endDay.isAfter(day);

  /// 提醒时间。
  DateTime? get remindAt => remindOffsetMin == null
      ? null
      : startTime.subtract(Duration(minutes: remindOffsetMin!));

  ScheduleSubtask? get nextPendingSubtask {
    for (final s in subtasks) {
      if (!s.done) return s;
    }
    return null;
  }

  bool get isCompleted => done && subtasks.every((s) => s.done);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'allDay': allDay,
    'floating': floating,
    'repeatType': repeatType.value,
    'remindOffsetMin': remindOffsetMin,
    'priority': priority.value,
    'tag': tag,
    'bgColor': bgColor,
    'done': done,
    'subtasks': [for (final s in subtasks) s.toJson()],
    'imageNames': imageNames,
    'linkedDiaryId': linkedDiaryId,
    'linkedBlockId': linkedBlockId,
    'deleted': deleted,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule()
    ..id = json['id'] as String? ?? const Uuid().v7()
    ..title = json['title'] as String? ?? ''
    ..notes = json['notes'] as String? ?? ''
    ..startTime = DateTime.parse(json['startTime'] as String)
    ..endTime = json['endTime'] == null
        ? null
        : DateTime.parse(json['endTime'] as String)
    ..allDay = json['allDay'] as bool? ?? false
    ..floating = json['floating'] as bool? ?? false
    ..repeatType = RepeatType.fromValue(json['repeatType'] as String?)
    ..remindOffsetMin = (json['remindOffsetMin'] as num?)?.toInt()
    ..priority = SchedulePriority.fromValue(
      (json['priority'] as num?)?.toInt(),
    )
    ..tag = json['tag'] as String?
    ..bgColor = (json['bgColor'] as num?)?.toInt()
    ..done = json['done'] as bool? ?? false
    ..subtasks = [
      for (final s in (json['subtasks'] as List? ?? []))
        ScheduleSubtask.fromJson(s),
    ]
    ..imageNames = [
      for (final s in (json['imageNames'] as List? ?? [])) s.toString(),
    ]
    ..linkedDiaryId = json['linkedDiaryId'] as String?
    ..linkedBlockId = json['linkedBlockId'] as String?
    ..deleted = json['deleted'] as bool? ?? false
    ..createdAt = DateTime.parse(json['createdAt'] as String)
    ..updatedAt = DateTime.parse(json['updatedAt'] as String);
}
