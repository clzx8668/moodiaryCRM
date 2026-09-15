import 'dart:io';

import 'package:dio/dio.dart';

/// 任务失败后的处置方式（纯函数决策，便于单测）。
enum AiTaskOutcome {
  /// 普通失败：消耗一次重试；超过上限则永久失败
  retry,

  /// 网络问题：挂起等网络恢复，**不消耗重试次数**
  waitNetwork,

  /// AI 未配置（缺 API Key / 模型）：挂起等用户配置，**不消耗重试次数**
  waitConfig,

  /// 已用尽重试次数
  giveUp,
}

/// AI 任务的失败分类与退避策略。
///
/// 设计目标：离线/未配置都属于「环境问题」而非「任务本身有问题」——
/// 这类任务应原地等待（网络恢复 / 用户配置好 Key 后自动继续），
/// 既不该被标成失败，也不该白白消耗重试次数。
class AiTaskRetryPolicy {
  AiTaskRetryPolicy._();

  /// 第 n 次重试前的等待时长：5s、10s、20s… 上限 5 分钟。
  static Duration backoff(int retryCount) {
    final seconds = 5 * (1 << retryCount.clamp(0, 6));
    return Duration(seconds: seconds > 300 ? 300 : seconds);
  }

  /// 现在是否可以再试一次（错开重试，避免打网络）。
  static bool shouldAttempt({
    required int retryCount,
    required DateTime lastUpdated,
    required DateTime now,
  }) {
    if (retryCount <= 0) return true;
    return now.difference(lastUpdated) >= backoff(retryCount - 1);
  }

  static AiTaskOutcome classify(
    Object error, {
    required int retryCount,
    required int maxRetries,
  }) {
    if (isConfigError(error)) return AiTaskOutcome.waitConfig;
    if (isNetworkError(error)) return AiTaskOutcome.waitNetwork;
    if (retryCount + 1 >= maxRetries) return AiTaskOutcome.giveUp;
    return AiTaskOutcome.retry;
  }

  /// 网络类错误：连接失败/超时/域名解析/握手失败等。
  static bool isNetworkError(Object error) {
    if (error is SocketException ||
        error is HandshakeException ||
        error is HttpException) {
      return true;
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return true;
        case DioExceptionType.badResponse:
        case DioExceptionType.cancel:
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          break;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('network is unreachable') ||
        text.contains('connection closed') ||
        text.contains('timed out');
  }

  /// 未配置类错误：缺 API Key / 未配置模型。
  static bool isConfigError(Object error) {
    final text = error.toString();
    return text.contains('未配置') ||
        text.contains('API Key') ||
        text.contains('api key') ||
        text.contains('apiKey 为空');
  }
}
