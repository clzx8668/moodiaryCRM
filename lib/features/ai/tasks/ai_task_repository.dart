import 'package:drift/drift.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// AI 任务状态
class AiTaskStatus {
  static const pending = 'pending';
  static const processing = 'processing';
  static const waitingNetwork = 'waiting_network';
  /// 等待用户配置 AI（缺 API Key / 模型）；配置好后自动继续，不消耗重试次数
  static const waitingConfig = 'waiting_config';
  static const done = 'done';
  static const failed = 'failed';

  /// 被本地分流拦下、没有上云（**不是失败**）：内容已在本地保存
  static const skippedLocal = 'skipped_local';
}

/// AI 任务类型
class AiTaskType {
  static const autoTag = 'auto_tag';
  static const autoClassify = 'auto_classify';
  static const autoSummary = 'auto_summary';
  static const embedding = 'embedding';
  static const index = 'index';
  static const deColloquial = 'de_colloquial';
  static const extractPlan = 'extract_plan';
  /// 快速收集模板的 AI 处理（payload = AiTemplates 模板 id）
  static const aiTemplate = 'ai_template';
  /// 图片速记：先落地占位卡，后台视觉整理（payload = 图片文件名）
  static const visionOcr = 'vision_ocr';
  /// 链接速记：先落地占位卡，后台抓取正文（payload = url）
  static const linkFetch = 'link_fetch';
  /// 语音速记：先落地占位卡，后台云端转写（payload = 音频文件名）
  static const voiceTranscribe = 'voice_transcribe';

  /// 音频附件转写：速记里"选了已有音频"当附件时，后台转写成 AI 卡
  /// （payload = audio 目录下的文件名；结果落 AI 生成区，不改正文）
  static const audioTranscribe = 'audio_transcribe';
}

/// AI 任务仓储（Drift `AiTasks` 表读写，M2 队列的数据层）。
class AiTaskRepository {
  AppDatabase get _db => IsarUtil.database;

  /// 提交任务（默认 pending），返回行。
  Future<AiTaskRow> submit({
    required String type,
    required String refId,
    String refType = 'note',
    String payload = '',
  }) async {
    final now = DateTime.now();
    await _db.into(_db.aiTasks).insert(
      AiTasksCompanion.insert(
        id: const Uuid().v7(),
        type: type,
        refId: refId,
        refType: Value(refType),
        payload: Value(payload),
        status: const Value(AiTaskStatus.pending),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await _db.select(_db.aiTasks).get()).last;
  }

  /// 按状态查询（创建时间升序）
  Future<List<AiTaskRow>> listByStatus(String status) async {
    final rows = await _db.select(_db.aiTasks).get();
    return rows
        .where((t) => t.status == status)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 全部任务（更新时间倒序，供队列管理页展示）。
  Future<List<AiTaskRow>> listAll() async {
    final rows = await _db.select(_db.aiTasks).get();
    return rows.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// 未完成任务（排除 done；更新时间倒序）。
  Future<List<AiTaskRow>> listQueue() async {
    final rows = await listAll();
    return rows.where((t) => t.status != AiTaskStatus.done).toList();
  }

  /// 各状态计数（仅统计传入的状态，未出现的补 0）。
  Future<Map<String, int>> countByStatuses(Iterable<String> statuses) async {
    final rows = await _db.select(_db.aiTasks).get();
    final result = {for (final s in statuses) s: 0};
    for (final row in rows) {
      if (result.containsKey(row.status)) {
        result[row.status] = result[row.status]! + 1;
      }
    }
    return result;
  }

  Future<void> updateStatus(
    AiTaskRow row,
    String status, {
    String? error,
  }) async {
    await (_db.update(_db.aiTasks)..where((t) => t.id.equals(row.id))).write(
      AiTasksCompanion(
        status: Value(status),
        errorMessage: Value(error ?? ''),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> incrementRetry(AiTaskRow row, String error) async {
    await (_db.update(_db.aiTasks)..where((t) => t.id.equals(row.id))).write(
      AiTasksCompanion(
        retryCount: Value(row.retryCount + 1),
        errorMessage: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countByStatus(String status) async {
    final rows = await _db.select(_db.aiTasks).get();
    return rows.where((t) => t.status == status).length;
  }

  /// 重新排队：状态回到 pending、清零重试次数与错误信息（等下一轮轮询执行）。
  Future<void> requeue(AiTaskRow row) async {
    await (_db.update(_db.aiTasks)..where((t) => t.id.equals(row.id))).write(
      AiTasksCompanion(
        status: const Value(AiTaskStatus.pending),
        retryCount: const Value(0),
        errorMessage: const Value(''),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 批量重新排队，返回处理条数。
  Future<int> requeueMany(Iterable<AiTaskRow> rows) async {
    var count = 0;
    for (final row in rows) {
      await requeue(row);
      count++;
    }
    return count;
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.aiTasks)..where((t) => t.id.equals(id))).go();
  }

  /// 按状态批量删除，返回删除条数。
  Future<int> deleteByStatuses(Iterable<String> statuses) async {
    final list = statuses.toList();
    if (list.isEmpty) return 0;
    return (_db.delete(_db.aiTasks)..where((t) => t.status.isIn(list))).go();
  }

  /// 宕机/强杀恢复：把残留的 `processing` 任务放回 `pending`，返回恢复条数。
  ///
  /// 任务在执行中被强杀（进程被杀、崩溃）时会永久停留在 processing——
  /// Worker 只捞 pending，于是这条任务再也不会被执行（真机实测卡了 16 天）。
  /// 应用启动时调用一次即可自愈。
  Future<int> recoverProcessing() async {
    final rows = await listByStatus(AiTaskStatus.processing);
    for (final row in rows) {
      await updateStatus(row, AiTaskStatus.pending);
    }
    return rows.length;
  }
}
