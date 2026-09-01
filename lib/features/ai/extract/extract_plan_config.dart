import 'dart:convert';

import 'package:moodiary/persistence/pref.dart';

/// 抽取计划配置（可开关类别，b：计划配置化）。
///
/// 默认全部开启；用户可在详情页「更多 → 抽取计划」勾选。开关仅影响"抽取哪些内容"，
/// 不影响后续入库/审核逻辑。
class ExtractPlanConfig {
  bool todo;
  bool schedule;
  bool crm;
  bool summary;

  ExtractPlanConfig({
    this.todo = true,
    this.schedule = true,
    this.crm = true,
    this.summary = true,
  });

  ExtractPlanConfig clone() => ExtractPlanConfig(
    todo: todo,
    schedule: schedule,
    crm: crm,
    summary: summary,
  );

  Map<String, dynamic> toJson() => {
    'todo': todo,
    'schedule': schedule,
    'crm': crm,
    'summary': summary,
  };

  factory ExtractPlanConfig.fromJson(Map<String, dynamic> json) =>
      ExtractPlanConfig(
        todo: json['todo'] as bool? ?? true,
        schedule: json['schedule'] as bool? ?? true,
        crm: json['crm'] as bool? ?? true,
        summary: json['summary'] as bool? ?? true,
      );

  static const String _key = 'extractPlanConfig';

  static ExtractPlanConfig load() {
    final raw = PrefUtil.getValue<String>(_key);
    if (raw == null || raw.isEmpty) return ExtractPlanConfig();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ExtractPlanConfig.fromJson(decoded);
      }
    } catch (_) {
      // 容错回退默认
    }
    return ExtractPlanConfig();
  }

  static Future<void> save(ExtractPlanConfig config) async {
    await PrefUtil.setValue<String>(_key, jsonEncode(config.toJson()));
  }
}
