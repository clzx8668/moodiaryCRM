import 'dart:async';

import 'package:moodiary/features/ai/colloquial/de_colloquial_service.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/extract/extract_plan_service.dart';
import 'package:moodiary/features/ai/template_process_service.dart';
import 'package:moodiary/features/ai/tagging_service.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/features/ai/tasks/ai_task_retry_policy.dart';
import 'package:moodiary/features/ai/tasks/pending_content_service.dart';
import 'package:moodiary/features/ai/triage/triage_task_gate.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/network_util.dart';

/// AI 任务队列 Worker（M2，单例）。
///
/// 每 5 秒轮询 `pending` 任务：离线时标记 `waiting_network`，网络恢复批量恢复；
/// 执行失败指数退避重试（轮询间隔体现），超过上限标记 `failed`。
/// App 启动时调用 [start]，退出时调用 [stop]（资源清理）。
class AiTaskQueueWorker {
  AiTaskQueueWorker._();

  static final AiTaskQueueWorker instance = AiTaskQueueWorker._();

  final AiTaskRepository _repo = AiTaskRepository();
  Timer? _timer;
  bool _running = false;
  bool _busy = false;

  void start() {
    if (_running) return;
    _running = true;
    // 上次进程被杀时可能留下 processing 任务（Worker 只捞 pending），启动先自愈
    unawaited(_recoverStuckTasks());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  /// 把上次残留的「执行中」任务放回队列（真机实测：强杀会留下永久卡住的任务）。
  Future<void> _recoverStuckTasks() async {
    try {
      final recovered = await _repo.recoverProcessing();
      if (recovered > 0) {
        logger.i('AI 任务队列：恢复 $recovered 条残留的执行中任务');
      }
    } catch (e) {
      logger.e('AI 任务队列恢复残留任务失败', error: e);
    }
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// 提交任务并立即触发一次轮询。
  Future<void> submitTask({
    required String type,
    required String refId,
    String refType = 'note',
    String payload = '',
  }) async {
    await _repo.submit(
      type: type,
      refId: refId,
      refType: refType,
      payload: payload,
    );
    unawaited(_tick());
  }

  Future<void> _tick() async {
    if (!_running || _busy) return;
    _busy = true;
    try {
      final online = await NetworkUtil.isNetworkConnected();
      // AI 配置就绪：把「等配置」的任务放回队列（用户配好 Key 后自动继续）
      final waitingConfig = await _repo.listByStatus(AiTaskStatus.waitingConfig);
      if (waitingConfig.isNotEmpty) {
        try {
          final provider = await AiProviderFactory.load();
          if (provider.isConfigured) {
            for (final row in waitingConfig) {
              await _repo.updateStatus(row, AiTaskStatus.pending);
            }
          }
        } catch (_) {
          // 配置读取失败时保持挂起
        }
      }
      // 网络恢复：批量将 waiting_network → pending
      if (online) {
        final waiting = await _repo.listByStatus(AiTaskStatus.waitingNetwork);
        for (final row in waiting) {
          await _repo.updateStatus(row, AiTaskStatus.pending);
        }
      }
      final tasks = await _repo.listByStatus(AiTaskStatus.pending);
      final now = DateTime.now();
      for (final task in tasks) {
        if (!_running) return;
        if (!online) {
          await _repo.updateStatus(task, AiTaskStatus.waitingNetwork);
          continue;
        }
        // 退避：上次失败后等够间隔再试，避免持续打网络
        if (!AiTaskRetryPolicy.shouldAttempt(
          retryCount: task.retryCount,
          lastUpdated: task.updatedAt,
          now: now,
        )) {
          continue;
        }
        await _process(task);
      }
    } catch (e) {
      logger.e('AI 任务轮询异常', error: e);
    } finally {
      _busy = false;
    }
  }

  /// 分流闸门：判断这个任务是否允许真正调用 AI。
  ///
  /// 规则：
  /// - 未知任务类型 → 放行（保持既有行为）；
  /// - "内容还没落地"的补全任务（OCR/抓取/转写）→ 放行（拦下等于丢内容）；
  /// - 用户手动触发（重试/选模板）→ 放行"值不值得"的判断，但仍受隐私与额度约束；
  /// - 其余 → 走本地分流（规则 + 分类器 + 隐私 + 额度）。
  Future<bool> _passesTriage(AiTaskRow task) async {
    if (TriageTaskGate.operationOf(task.type) == null) return true;
    if (TriageTaskGate.mustAlwaysRun(task.type)) return true;
    try {
      final text = await _textForTask(task);
      return TriageTaskGate.allow(
        taskType: task.type,
        text: text,
        explicitUserIntent: task.retryCount > 0,
      );
    } catch (e) {
      // 分流本身出错时**放行**：宁可多花一点额度，也不要因为分流 bug 丢功能
      logger.e('分流判断异常，按放行处理：${task.type}', error: e);
      return true;
    }
  }

  /// 取这条任务对应的文本视图（供分流判断）。
  ///
  /// 优先用日记投影文本（统一、已包含各来源），取不到再拼块内容。
  Future<String> _textForTask(AiTaskRow task) async {
    final diary = await IsarUtil.getDiaryById(task.refId);
    final fromDiary = diary?.contentText.trim() ?? '';
    if (!fromDiary.startsWith('⏳') && fromDiary.isNotEmpty) return fromDiary;
    final blocks = await IsarUtil.getBlocksByDiary(task.refId);
    final buf = StringBuffer();
    for (final b in blocks) {
      if (b.isDeleted) continue;
      if (b.meta.isAi) continue; // AI 产出的卡片不再回流
      if (b.content.trim().isEmpty) continue;
      buf.writeln(b.content);
    }
    return buf.toString().trim();
  }

  Future<void> _process(AiTaskRow task) async {
    await _repo.updateStatus(task, AiTaskStatus.processing);
    try {
      // ── 边缘预筛选：真正要上云之前，先过一遍本地分流（批次 109）──
      // 被拦下的任务标记为 skipped_local（不是失败），内容保持在本地。
      if (!await _passesTriage(task)) {
        await _repo.updateStatus(task, AiTaskStatus.skippedLocal);
        logger.i('分流拦截：${task.type} 未上云（内容已本地保存）');
        return;
      }
      switch (task.type) {
        case AiTaskType.autoTag:
        case AiTaskType.autoClassify:
        case AiTaskType.autoSummary:
          await TaggingService.processAutoTag(diaryId: task.refId);
          break;
        case AiTaskType.deColloquial:
          // 去口语化：对日记主文本块改写并写回 metaJson（原文保留）
          await DeColoquialService.processDiary(task.refId);
          break;
        case AiTaskType.extractPlan:
          // extract_plan：抽取待办/CRM/日程；待办与日程落库，CRM 生成提案待审核
          await ExtractPlanService.processDiary(task.refId);
          break;
        case AiTaskType.aiTemplate:
          // 快速收集模板：按 payload 指定的模板处理并落 AI 生成区
          await TemplateProcessService.processDiary(task.refId, task.payload);
          break;
        case AiTaskType.visionOcr:
          // 图片速记后续处理：视觉整理 → 写回占位卡（payload = 图片文件名）
          await PendingContentService.processVision(
            diaryId: task.refId,
            imageName: task.payload,
          );
          break;
        case AiTaskType.linkFetch:
          // 链接速记后续处理：抓取正文 → 写回占位卡（payload = url）
          await PendingContentService.processLink(
            diaryId: task.refId,
            url: task.payload,
          );
          break;
        case AiTaskType.voiceTranscribe:
          // 语音速记后续处理：云端转写 → 写回占位卡（payload = 音频文件名）
          await PendingContentService.processTranscription(
            diaryId: task.refId,
            audioFileName: task.payload,
          );
          break;
        case AiTaskType.audioTranscribe:
          // 音频附件转写：结果落 AI 卡（不改正文）
          await PendingContentService.processAudioAttachment(
            diaryId: task.refId,
            audioFileName: task.payload,
          );
          break;
        default:
          // 预留类型（embedding/index）暂不执行，直接完成
          break;
      }
      await _repo.updateStatus(task, AiTaskStatus.done);
    } catch (e) {
      final msg = e.toString();
      final outcome = AiTaskRetryPolicy.classify(
        e,
        retryCount: task.retryCount,
        maxRetries: task.maxRetries,
      );
      logger.e(
        'AI 任务失败：${task.type}/${task.refId} → ${outcome.name}',
        error: e,
      );
      switch (outcome) {
        case AiTaskOutcome.waitNetwork:
          // 网络问题：挂起等恢复（下次上线自动继续），不消耗重试次数
          await _repo.updateStatus(
            task,
            AiTaskStatus.waitingNetwork,
            error: msg,
          );
        case AiTaskOutcome.waitConfig:
          // 未配置 AI：挂起等用户在设置里配好，不消耗重试次数
          await _repo.updateStatus(
            task,
            AiTaskStatus.waitingConfig,
            error: msg,
          );
        case AiTaskOutcome.giveUp:
          await _repo.updateStatus(task, AiTaskStatus.failed, error: msg);
        case AiTaskOutcome.retry:
          // 保留 pending，下一轮按退避间隔重试
          await _repo.incrementRetry(task, msg);
      }
    }
  }
}
