import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;
  late AiTaskRepository repo;

  setUp(() {
    db = openTestDb();
    repo = AiTaskRepository();
  });

  tearDown(() async {
    closeTestDb(db);
  });

  test('submit 落 pending，listAll 可按更新时间取回', () async {
    await repo.submit(type: AiTaskType.autoTag, refId: 'd1');
    await repo.submit(
      type: AiTaskType.linkFetch,
      refId: 'd2',
      payload: 'https://a.com',
    );

    final all = await repo.listAll();
    expect(all.length, 2);
    expect(all.first.status, AiTaskStatus.pending);
    expect(
      all.map((t) => t.type),
      containsAll([AiTaskType.autoTag, AiTaskType.linkFetch]),
    );
  });

  test('listQueue 排除已完成，countByStatuses 只统计传入状态', () async {
    final a = await repo.submit(type: AiTaskType.autoTag, refId: 'd1');
    await repo.submit(type: AiTaskType.autoSummary, refId: 'd2');
    await repo.updateStatus(a, AiTaskStatus.done);

    final queue = await repo.listQueue();
    expect(queue.length, 1);
    expect(queue.single.type, AiTaskType.autoSummary);

    final counts = await repo.countByStatuses([
      AiTaskStatus.pending,
      AiTaskStatus.done,
      AiTaskStatus.failed,
    ]);
    expect(counts[AiTaskStatus.pending], 1);
    expect(counts[AiTaskStatus.done], 1);
    expect(counts[AiTaskStatus.failed], 0);
    expect(counts.containsKey(AiTaskStatus.waitingConfig), isFalse);
  });

  test('requeue 回到 pending 并清零重试次数与错误', () async {
    final row = await repo.submit(type: AiTaskType.visionOcr, refId: 'd1');
    await repo.incrementRetry(row, '超时');
    await repo.updateStatus(row, AiTaskStatus.failed, error: '超时');

    final failed = (await repo.listByStatus(AiTaskStatus.failed)).single;
    expect(failed.retryCount, 1);

    await repo.requeue(failed);
    final requeued = (await repo.listAll()).single;
    expect(requeued.status, AiTaskStatus.pending);
    expect(requeued.retryCount, 0);
    expect(requeued.errorMessage, isEmpty);
  });

  test('requeueMany 批量重排，deleteByStatuses 批量清理', () async {
    final a = await repo.submit(type: AiTaskType.autoTag, refId: 'd1');
    final b = await repo.submit(type: AiTaskType.autoTag, refId: 'd2');
    await repo.updateStatus(a, AiTaskStatus.waitingConfig, error: '未配置');
    await repo.updateStatus(b, AiTaskStatus.failed, error: '挂了');

    final hung = [
      ...await repo.listByStatus(AiTaskStatus.waitingConfig),
      ...await repo.listByStatus(AiTaskStatus.failed),
    ];
    expect(await repo.requeueMany(hung), 2);
    expect(await repo.countByStatus(AiTaskStatus.pending), 2);

    await repo.updateStatus((await repo.listAll()).first, AiTaskStatus.done);
    expect(await repo.deleteByStatuses([AiTaskStatus.done]), 1);
    expect(await repo.countByStatus(AiTaskStatus.done), 0);
    expect(await repo.deleteByStatuses(const []), 0);
  });

  test('delete 单条生效', () async {
    final row = await repo.submit(type: AiTaskType.autoTag, refId: 'd1');
    await repo.delete(row.id);
    expect(await repo.listAll(), isEmpty);
  });

  test('recoverProcessing 把残留的「执行中」放回 pending（宕机自愈）', () async {
    final a = await repo.submit(type: AiTaskType.autoTag, refId: 'd1');
    final b = await repo.submit(type: AiTaskType.autoSummary, refId: 'd2');
    final c = await repo.submit(type: AiTaskType.linkFetch, refId: 'd3');
    // 模拟：两条在执行中被强杀，一条已正常完成
    await repo.updateStatus(a, AiTaskStatus.processing, error: '上次残留');
    await repo.updateStatus(b, AiTaskStatus.processing);
    await repo.updateStatus(c, AiTaskStatus.done);

    expect(await repo.countByStatus(AiTaskStatus.processing), 2);
    expect(await repo.recoverProcessing(), 2);
    expect(await repo.countByStatus(AiTaskStatus.processing), 0);
    expect(await repo.countByStatus(AiTaskStatus.pending), 2);
    // 已完成的不受影响
    expect(await repo.countByStatus(AiTaskStatus.done), 1);
    // 恢复后不再重复恢复
    expect(await repo.recoverProcessing(), 0);
  });
}
