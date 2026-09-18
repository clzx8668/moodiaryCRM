import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_model.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';

void main() {
  group('分组判定', () {
    test('状态映射到分组', () {
      expect(
        AiTaskQueueModel.groupOf(status: AiTaskStatus.failed, retryCount: 3),
        AiTaskGroup.failed,
      );
      expect(
        AiTaskQueueModel.groupOf(
          status: AiTaskStatus.waitingConfig,
          retryCount: 0,
        ),
        AiTaskGroup.waitingConfig,
      );
      expect(
        AiTaskQueueModel.groupOf(
          status: AiTaskStatus.waitingNetwork,
          retryCount: 0,
        ),
        AiTaskGroup.waitingNetwork,
      );
      expect(
        AiTaskQueueModel.groupOf(
          status: AiTaskStatus.processing,
          retryCount: 0,
        ),
        AiTaskGroup.processing,
      );
      expect(
        AiTaskQueueModel.groupOf(status: AiTaskStatus.done, retryCount: 0),
        AiTaskGroup.done,
      );
    });

    test('pending 按重试次数区分「排队中 / 重试中」', () {
      expect(
        AiTaskQueueModel.groupOf(status: AiTaskStatus.pending, retryCount: 0),
        AiTaskGroup.queued,
      );
      expect(
        AiTaskQueueModel.groupOf(status: AiTaskStatus.pending, retryCount: 2),
        AiTaskGroup.retrying,
      );
    });

    test('未知状态兜底为排队中', () {
      expect(
        AiTaskQueueModel.groupOf(status: 'weird', retryCount: 0),
        AiTaskGroup.queued,
      );
    });

    test('需要人处理的分组排在最前，且可手动重试', () {
      expect(AiTaskQueueModel.groupOrder.first, AiTaskGroup.failed);
      expect(AiTaskQueueModel.needsAttention(AiTaskGroup.failed), isTrue);
      expect(
        AiTaskQueueModel.needsAttention(AiTaskGroup.waitingConfig),
        isTrue,
      );
      expect(AiTaskQueueModel.needsAttention(AiTaskGroup.queued), isFalse);

      expect(AiTaskQueueModel.canRequeue(AiTaskGroup.failed), isTrue);
      expect(AiTaskQueueModel.canRequeue(AiTaskGroup.waitingConfig), isTrue);
      expect(AiTaskQueueModel.canRequeue(AiTaskGroup.waitingNetwork), isTrue);
      expect(AiTaskQueueModel.canRequeue(AiTaskGroup.processing), isFalse);
      expect(AiTaskQueueModel.canRequeue(AiTaskGroup.done), isFalse);
    });

    test('每个分组都有文案（避免 UI 出现空标签）', () {
      for (final group in AiTaskGroup.values) {
        expect(AiTaskQueueModel.groupLabel(group), isNotEmpty);
        expect(AiTaskQueueModel.groupAdvice(group), isNotEmpty);
      }
    });
  });

  group('类型与来源文案', () {
    test('已实现的类型都有中文名', () {
      const types = [
        AiTaskType.autoTag,
        AiTaskType.autoClassify,
        AiTaskType.autoSummary,
        AiTaskType.deColloquial,
        AiTaskType.extractPlan,
        AiTaskType.aiTemplate,
        AiTaskType.visionOcr,
        AiTaskType.linkFetch,
        AiTaskType.voiceTranscribe,
        AiTaskType.embedding,
        AiTaskType.index,
      ];
      for (final type in types) {
        expect(AiTaskQueueModel.typeLabel(type), isNot(type));
      }
      expect(AiTaskQueueModel.typeLabel('unknown_type'), 'unknown_type');
    });

    test('关联对象类型文案', () {
      expect(AiTaskQueueModel.refTypeLabel('note'), '笔记');
      expect(AiTaskQueueModel.refTypeLabel('crm_account'), 'CRM');
      expect(AiTaskQueueModel.refTypeLabel('obsidian_file'), 'Obsidian');
      expect(AiTaskQueueModel.refTypeLabel(''), '记录');
    });

    test('payload 摘要截断', () {
      expect(AiTaskQueueModel.payloadSummary('link_fetch', ''), isEmpty);
      expect(
        AiTaskQueueModel.payloadSummary('link_fetch', '  https://a.com  '),
        'https://a.com',
      );
      final long = 'x' * 100;
      final summary = AiTaskQueueModel.payloadSummary('link_fetch', long);
      expect(summary.endsWith('…'), isTrue);
      expect(summary.length, 47);
    });
  });

  group('概览文案', () {
    test('无异常时为空（UI 据此显示「没有需要处理的异常」）', () {
      expect(
        AiTaskQueueModel.headline(
          waitingConfig: 0,
          waitingNetwork: 0,
          failed: 0,
        ),
        isEmpty,
      );
    });

    test('按失败 → 待配置 → 待联网拼接', () {
      expect(
        AiTaskQueueModel.headline(
          waitingConfig: 2,
          waitingNetwork: 1,
          failed: 3,
        ),
        '3 条失败 · 2 条待配置 · 1 条待联网',
      );
      expect(
        AiTaskQueueModel.headline(
          waitingConfig: 1,
          waitingNetwork: 0,
          failed: 0,
        ),
        '1 条待配置',
      );
    });
  });
}
