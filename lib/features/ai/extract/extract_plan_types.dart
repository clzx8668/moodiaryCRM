import 'dart:convert';

/// AI 抽取出的一条待办。
class ExtractAction {
  final String title;
  final String? dueAt;
  final String priority;
  final String? note;

  const ExtractAction({
    required this.title,
    this.dueAt,
    this.priority = '',
    this.note,
  });

  static ExtractAction fromJson(Map<String, dynamic> json) => ExtractAction(
    title: json['title']?.toString() ?? '',
    dueAt: json['dueAt']?.toString(),
    priority: json['priority']?.toString() ?? '',
    note: json['note']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'dueAt': dueAt,
    'priority': priority,
    'note': note,
  };
}

/// AI 抽取出的一条日程。
class ExtractEvent {
  final String title;
  final String? start;
  final String? end;
  final bool allDay;
  final String? remind;

  const ExtractEvent({
    required this.title,
    this.start,
    this.end,
    this.allDay = false,
    this.remind,
  });

  static ExtractEvent fromJson(Map<String, dynamic> json) => ExtractEvent(
    title: json['title']?.toString() ?? '',
    start: json['start']?.toString(),
    end: json['end']?.toString(),
    allDay: json['allDay'] == true,
    remind: json['remind']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'start': start,
    'end': end,
    'allDay': allDay,
    'remind': remind,
  };
}

/// AI 抽取出的 CRM 信息（不写库，作为提案）。
class ExtractCrm {
  final String type;
  final String name;
  final Map<String, dynamic> fields;

  const ExtractCrm({
    required this.type,
    required this.name,
    this.fields = const {},
  });

  static ExtractCrm fromJson(Map<String, dynamic> json) {
    final fields = json['fields'];
    return ExtractCrm(
      type: (json['type']?.toString() ?? '').trim(),
      name: (json['name']?.toString() ?? '').trim(),
      fields: fields is Map
          ? fields.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'fields': fields,
  };
}

/// 一次 extract_plan 抽取的完整结果。
class ExtractPlanResult {
  final List<ExtractAction> actions;
  final List<ExtractEvent> events;
  final List<ExtractCrm> crm;
  final String summary;

  const ExtractPlanResult({
    this.actions = const [],
    this.events = const [],
    this.crm = const [],
    this.summary = '',
  });

  bool get isEmpty => actions.isEmpty && events.isEmpty && crm.isEmpty;

  Map<String, dynamic> toJson() => {
    'actions': [for (final a in actions) a.toJson()],
    'events': [for (final e in events) e.toJson()],
    'crm': [for (final c in crm) c.toJson()],
    'summary': summary,
  };

  /// 解析 AI 输出的 JSON；失败/空返回 null。
  static ExtractPlanResult? tryParse(String raw) {
    var s = raw.trim();
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    try {
      final decoded = jsonDecode(s);
      if (decoded is! Map<String, dynamic>) return null;
      final actions = _list(decoded['actions'], ExtractAction.fromJson);
      final events = _list(decoded['events'], ExtractEvent.fromJson);
      final crm = _list(decoded['crm'], ExtractCrm.fromJson);
      final result = ExtractPlanResult(
        actions: actions,
        events: events,
        crm: crm,
        summary: decoded['summary']?.toString() ?? '',
      );
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
    ];
  }
}
