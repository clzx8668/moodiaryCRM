import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_page.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;
  late AiTaskRepository repo;

  setUp(() async {
    db = openTestDb();
    repo = AiTaskRepository();
  });

  tearDown(() {
    Get.reset();
    closeTestDb(db);
  });

  testWidgets('空队列渲染空态不异常', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: AiTaskQueuePage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('队列是空的'), findsOneWidget);
    expect(find.text('待处理任务'), findsOneWidget);
  });

  testWidgets('按分组展示任务，失败/待配置排在前并带重试按钮', (tester) async {
    final failed = await repo.submit(type: AiTaskType.visionOcr, refId: 'd1');
    await repo.updateStatus(failed, AiTaskStatus.failed, error: '识别失败');
    final hung = await repo.submit(
      type: AiTaskType.linkFetch,
      refId: 'd2',
      payload: 'https://example.com/a',
    );
    await repo.updateStatus(hung, AiTaskStatus.waitingConfig, error: '未配置');
    await repo.submit(type: AiTaskType.autoTag, refId: 'd3');
    final done = await repo.submit(type: AiTaskType.autoSummary, refId: 'd4');
    await repo.updateStatus(done, AiTaskStatus.done);

    await tester.pumpWidget(const GetMaterialApp(home: AiTaskQueuePage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 概览 + 分组标题（失败 1、待配置 1、排队 1）
    expect(find.text('待处理 3 条'), findsOneWidget);
    expect(find.textContaining('1 条失败'), findsOneWidget);
    // 分组头 + 任务行副标题各出现一次
    expect(find.textContaining('失败（需处理）'), findsNWidgets(2));
    expect(find.textContaining('等待配置 AI'), findsWidgets);
    expect(find.textContaining('排队中'), findsWidgets);
    // 失败任务展示错误原因与中文类型名
    expect(find.text('识别失败'), findsOneWidget);
    expect(find.textContaining('图片速记整理'), findsOneWidget);
    // 失败 / 待配置分组带「立即重试」，故至少有 2 个刷新按钮
    expect(find.byTooltip('立即重试'), findsNWidgets(2));
  });

  testWidgets('只有已完成任务时显示「全部完成」并单列一组', (tester) async {
    final done = await repo.submit(type: AiTaskType.autoSummary, refId: 'd1');
    await repo.updateStatus(done, AiTaskStatus.done);

    await tester.pumpWidget(const GetMaterialApp(home: AiTaskQueuePage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('全部完成'), findsOneWidget);
    expect(find.text('没有需要处理的异常'), findsOneWidget);
    // 分组头 + 任务行副标题各一次
    expect(find.textContaining('已完成 · '), findsNWidgets(2));
    expect(find.byTooltip('立即重试'), findsNothing);
  });

  testWidgets('点「立即重试」把失败任务放回 pending', (tester) async {
    final failed = await repo.submit(
      type: AiTaskType.voiceTranscribe,
      refId: 'd1',
    );
    await repo.updateStatus(failed, AiTaskStatus.failed, error: '转写失败');

    await tester.pumpWidget(const GetMaterialApp(home: AiTaskQueuePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('立即重试').first);
    await tester.pumpAndSettle();

    final row = (await repo.listAll()).single;
    expect(row.status, AiTaskStatus.pending);
    expect(row.retryCount, 0);
    expect(row.errorMessage, isEmpty);
  });
}
