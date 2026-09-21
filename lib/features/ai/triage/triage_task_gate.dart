import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/features/ai/triage/ai_triage_service.dart';
import 'package:moodiary/features/ai/triage/triage_types.dart';

/// 队列任务与分流之间的**唯一映射点**。
///
/// Worker 在处理任务前调用 [allow]，被拦下的任务标记为
/// `skipped_local`（不是失败、不是完成），UI 上显示为"已在本地处理"。
class TriageTaskGate {
  TriageTaskGate._();

  /// 任务类型 → 分流操作
  static TriageOperation? operationOf(String taskType) => switch (taskType) {
    AiTaskType.autoTag => TriageOperation.autoTag,
    AiTaskType.autoClassify => TriageOperation.autoClassify,
    AiTaskType.autoSummary => TriageOperation.autoSummary,
    AiTaskType.deColloquial => TriageOperation.deColloquial,
    AiTaskType.extractPlan => TriageOperation.extractPlan,
    AiTaskType.embedding || AiTaskType.index => TriageOperation.embedding,
    AiTaskType.aiTemplate => TriageOperation.aiTemplate,
    AiTaskType.visionOcr ||
    AiTaskType.linkFetch ||
    AiTaskType.voiceTranscribe ||
    AiTaskType.audioTranscribe => TriageOperation.enrich,
    _ => null,
  };

  /// 这类任务"内容本身还没落地"，拦下来等于丢内容 → 一律放行。
  ///
  /// 例如：图片速记的视觉整理、链接抓正文、语音转写。
  /// 它们只受**敏感闸门**与**额度**约束，不受"值不值得"约束。
  static bool mustAlwaysRun(String taskType) => switch (taskType) {
    AiTaskType.visionOcr ||
    AiTaskType.linkFetch ||
    AiTaskType.voiceTranscribe ||
    AiTaskType.audioTranscribe => true,
    _ => false,
  };

  /// 判断这次是否真的可以调用 AI。
  ///
  /// [text] 是这条内容的文本视图（正文/块内容/OCR 结果）。
  /// [explicitUserIntent] 为 true 表示用户手动触发（重试/选模板），
  /// 会跳过"值不值得"的判断，但仍受隐私闸门与额度约束。
  static Future<bool> allow({
    required String taskType,
    required String text,
    bool explicitUserIntent = false,
  }) async {
    final op = operationOf(taskType);
    if (op == null) return true; // 未知类型不拦（保持原有行为）
    return AiTriageService.instance.allowOperation(
      operation: op,
      text: text,
      explicitUserIntent: explicitUserIntent,
    );
  }
}
