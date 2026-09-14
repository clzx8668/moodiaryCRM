import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';

/// 快速收集模板 → 后台 AI 动作（纯函数，便于单测）。
///
/// - 「待办」走结构化抽取（`extract_plan`：落日程/AI 提取块）；
/// - 其余模板走 AI 模板处理（`ai_template`，payload 为模板 id，结果落 AI 生成区）；
/// - 返回 null 表示该模板暂不触发后台处理。
({String type, String payload})? quickCaptureActionFor(String template) {
  switch (template.trim()) {
    case '待办':
      return (type: AiTaskType.extractPlan, payload: '');
    case '打卡':
      return (type: AiTaskType.aiTemplate, payload: AiTemplates.checkin);
    case '扩写':
      return (type: AiTaskType.aiTemplate, payload: AiTemplates.expand);
    case '润色':
      return (type: AiTaskType.aiTemplate, payload: AiTemplates.polish);
    case '会议记录':
      return (type: AiTaskType.aiTemplate, payload: AiTemplates.meeting);
    case '翻译':
      return (type: AiTaskType.aiTemplate, payload: AiTemplates.translate);
    default:
      return null;
  }
}
