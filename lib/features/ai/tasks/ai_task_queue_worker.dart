import 'dart:async';

import 'package:moodiary/features/ai/tagging_service.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/persistence/app_database.dart';
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
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_tick()));
    unawaited(_tick());
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
      // 网络恢复：批量将 waiting_network → pending
      if (online) {
        final waiting = await _repo.listByStatus(AiTaskStatus.waitingNetwork);
        for (final row in waiting) {
          await _repo.updateStatus(row, AiTaskStatus.pending);
        }
      }
      final tasks = await _repo.listByStatus(AiTaskStatus.pending);
      for (final task in tasks) {
        if (!_running) return;
        if (!online) {
          await _repo.updateStatus(task, AiTaskStatus.waitingNetwork);
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

  Future<void> _process(AiTaskRow task) async {
    await _repo.updateStatus(task, AiTaskStatus.processing);
    try {
      switch (task.type) {
        case AiTaskType.autoTag:
        case AiTaskType.autoClassify:
          await TaggingService.processAutoTag(diaryId: task.refId);
          break;
        default:
          // 预留类型（auto_summary/embedding/index）暂不执行，直接完成
          break;
      }
      await _repo.updateStatus(task, AiTaskStatus.done);
    } catch (e) {
      final msg = e.toString();
      logger.e('AI 任务失败：${task.type}/${task.refId}', error: e);
      if (task.retryCount + 1 >= task.maxRetries) {
        await _repo.updateStatus(task, AiTaskStatus.failed, error: msg);
      } else {
        // 保留 pending，下一轮重试（轮询间隔即指数退避的最小步长）
        await _repo.incrementRetry(task, msg);
      }
    }
  }
}
