import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/tasks/ai_task_retry_policy.dart';

void main() {
  group('失败分类', () {
    test('未配置 AI → waitConfig（不消耗重试）', () {
      expect(
        AiTaskRetryPolicy.classify(
          StateError('AI 未配置：请先在设置中填写 API Key'),
          retryCount: 0,
          maxRetries: 3,
        ),
        AiTaskOutcome.waitConfig,
      );
    });

    test('网络错误 → waitNetwork（Dio 连接失败/超时、SocketException）', () {
      expect(
        AiTaskRetryPolicy.classify(
          DioException(
            requestOptions: RequestOptions(path: '/chat/completions'),
            type: DioExceptionType.connectionError,
          ),
          retryCount: 1,
          maxRetries: 3,
        ),
        AiTaskOutcome.waitNetwork,
      );
      expect(
        AiTaskRetryPolicy.classify(
          const SocketException('Failed host lookup: api.deepseek.com'),
          retryCount: 0,
          maxRetries: 3,
        ),
        AiTaskOutcome.waitNetwork,
      );
    });

    test('普通错误按重试次数：还有次数 → retry，用尽 → giveUp', () {
      expect(
        AiTaskRetryPolicy.classify(
          StateError('返回格式不符'),
          retryCount: 0,
          maxRetries: 3,
        ),
        AiTaskOutcome.retry,
      );
      expect(
        AiTaskRetryPolicy.classify(
          StateError('返回格式不符'),
          retryCount: 2,
          maxRetries: 3,
        ),
        AiTaskOutcome.giveUp,
      );
    });

    test('HTTP 4xx（badResponse）算普通失败而不是网络问题', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/chat/completions'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/chat/completions'),
          statusCode: 400,
        ),
      );
      expect(
        AiTaskRetryPolicy.classify(error, retryCount: 0, maxRetries: 3),
        AiTaskOutcome.retry,
      );
    });
  });

  group('退避', () {
    test('随重试次数指数增长并封顶 5 分钟', () {
      expect(AiTaskRetryPolicy.backoff(0), const Duration(seconds: 5));
      expect(AiTaskRetryPolicy.backoff(1), const Duration(seconds: 10));
      expect(AiTaskRetryPolicy.backoff(2), const Duration(seconds: 20));
      expect(AiTaskRetryPolicy.backoff(20), const Duration(seconds: 300));
    });

    test('未重试过 → 立即可试；重试过 → 等够退避间隔', () {
      final now = DateTime(2026, 9, 16, 12, 0);
      expect(
        AiTaskRetryPolicy.shouldAttempt(
          retryCount: 0,
          lastUpdated: now,
          now: now,
        ),
        isTrue,
      );
      expect(
        AiTaskRetryPolicy.shouldAttempt(
          retryCount: 1,
          lastUpdated: now.subtract(const Duration(seconds: 3)),
          now: now,
        ),
        isFalse,
      );
      expect(
        AiTaskRetryPolicy.shouldAttempt(
          retryCount: 1,
          lastUpdated: now.subtract(const Duration(seconds: 6)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
