import 'package:drift/drift.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// AI 任务状态
class AiTaskStatus {
  static const pending = 'pending';
  static const processing = 'processing';
  static const waitingNetwork = 'waiting_network';
  static const done = 'done';
  static const failed = 'failed';
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

  Future<void> delete(String id) async {
    await (_db.delete(_db.aiTasks)..where((t) => t.id.equals(id))).go();
  }
}
