import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';

/// 队列任务在管理页上的分组（纯数据，便于单测）。
enum AiTaskGroup {
  /// 失败（重试次数用尽，需要人处理）
  failed,

  /// 被本地分流拦下（内容已本地保存，未上云）——不是错误
  localOnly,

  /// 等待配置 AI（缺 API Key / 模型）
  waitingConfig,

  /// 等待网络
  waitingNetwork,

  /// 重试中（pending 且已失败过 ≥1 次）
  retrying,

  /// 排队中
  queued,

  /// 执行中
  processing,

  /// 已完成
  done,
}

/// 队列管理页的纯函数集合：分组、文案、概览。
class AiTaskQueueModel {
  AiTaskQueueModel._();

  /// 分组顺序：需要人处理的排前面。
  static const List<AiTaskGroup> groupOrder = [
    AiTaskGroup.failed,
    AiTaskGroup.waitingConfig,
    AiTaskGroup.waitingNetwork,
    AiTaskGroup.retrying,
    AiTaskGroup.queued,
    AiTaskGroup.processing,
    AiTaskGroup.localOnly,
    AiTaskGroup.done,
  ];

  static AiTaskGroup groupOf({
    required String status,
    required int retryCount,
  }) {
    switch (status) {
      case AiTaskStatus.failed:
        return AiTaskGroup.failed;
      case AiTaskStatus.waitingConfig:
        return AiTaskGroup.waitingConfig;
      case AiTaskStatus.waitingNetwork:
        return AiTaskGroup.waitingNetwork;
      case AiTaskStatus.processing:
        return AiTaskGroup.processing;
      case AiTaskStatus.done:
        return AiTaskGroup.done;
      case AiTaskStatus.skippedLocal:
        return AiTaskGroup.localOnly;
      case AiTaskStatus.pending:
        return retryCount > 0 ? AiTaskGroup.retrying : AiTaskGroup.queued;
      default:
        return AiTaskGroup.queued;
    }
  }

  static String groupLabel(AiTaskGroup group) {
    switch (group) {
      case AiTaskGroup.failed:
        return '失败（需处理）';
      case AiTaskGroup.waitingConfig:
        return '等待配置 AI';
      case AiTaskGroup.waitingNetwork:
        return '等待网络';
      case AiTaskGroup.retrying:
        return '重试中';
      case AiTaskGroup.queued:
        return '排队中';
      case AiTaskGroup.processing:
        return '执行中';
      case AiTaskGroup.done:
        return '已完成';
      case AiTaskGroup.localOnly:
        return '已在本地处理';
    }
  }

  /// 分组下的一句话说明（教用户「我该做什么」）。
  static String groupAdvice(AiTaskGroup group) {
    switch (group) {
      case AiTaskGroup.failed:
        return '重试次数已用尽；确认原因后可手动重试或删除';
      case AiTaskGroup.waitingConfig:
        return '在「AI 设置」里配好服务商与模型即会自动继续';
      case AiTaskGroup.waitingNetwork:
        return '联网后自动继续，不会丢失内容';
      case AiTaskGroup.retrying:
        return '失败后按退避间隔自动重试（5 秒起，最长 5 分钟）';
      case AiTaskGroup.queued:
        return '等待后台轮询执行（每 5 秒一轮）';
      case AiTaskGroup.processing:
        return '正在执行，请稍候';
      case AiTaskGroup.done:
        return '已处理完成，可清理';
      case AiTaskGroup.localOnly:
        return '分流判定无需上云（内容已本地保存），不消耗额度';
    }
  }

  /// 是否需要用户介入。
  static bool needsAttention(AiTaskGroup group) =>
      group == AiTaskGroup.failed || group == AiTaskGroup.waitingConfig;

  /// 是否允许「重新排队」（失败 / 挂起 均可手动重试）。
  static bool canRequeue(AiTaskGroup group) =>
      group == AiTaskGroup.failed ||
      group == AiTaskGroup.waitingConfig ||
      group == AiTaskGroup.waitingNetwork;

  /// 任务类型中文名。
  static String typeLabel(String type) {
    switch (type) {
      case AiTaskType.autoTag:
      case AiTaskType.autoClassify:
        return '自动标签';
      case AiTaskType.autoSummary:
        return '自动摘要';
      case AiTaskType.deColloquial:
        return '去口语化';
      case AiTaskType.extractPlan:
        return '提取待办/日程';
      case AiTaskType.aiTemplate:
        return 'AI 模板处理';
      case AiTaskType.visionOcr:
        return '图片速记整理';
      case AiTaskType.linkFetch:
        return '链接正文抓取';
      case AiTaskType.voiceTranscribe:
        return '语音转写';
      case AiTaskType.audioTranscribe:
        return '音频附件转写';
      case AiTaskType.embedding:
        return '向量化';
      case AiTaskType.index:
        return '建索引';
      default:
        return type;
    }
  }

  /// 关联对象类型中文名。
  static String refTypeLabel(String refType) {
    switch (refType) {
      case 'note':
        return '笔记';
      case 'crm_account':
      case 'crm':
        return 'CRM';
      case 'obsidian_file':
        return 'Obsidian';
      default:
        return refType.isEmpty ? '记录' : refType;
    }
  }

  /// payload 的一行摘要（URL / 文件名等）。
  static String payloadSummary(String type, String payload, {int max = 46}) {
    final text = payload.trim();
    if (text.isEmpty) return '';
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…';
  }

  /// 总览文案：无待处理时返回空串。
  static String headline({
    required int waitingConfig,
    required int waitingNetwork,
    required int failed,
  }) {
    final parts = <String>[];
    if (failed > 0) parts.add('$failed 条失败');
    if (waitingConfig > 0) parts.add('$waitingConfig 条待配置');
    if (waitingNetwork > 0) parts.add('$waitingNetwork 条待联网');
    return parts.join(' · ');
  }
}
