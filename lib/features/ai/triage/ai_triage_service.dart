import 'package:flutter/foundation.dart';
import 'package:moodiary/features/ai/triage/ai_triage_router.dart';
import 'package:moodiary/features/ai/triage/triage_config.dart';
import 'package:moodiary/features/ai/triage/triage_types.dart';

/// 分流服务：给业务层用的**唯一入口**（内部组合路由 + 配置存储 + 额度）。
///
/// 典型用法（保存一条笔记之后）：
/// ```dart
/// final result = await AiTriageService.instance.route(
///   text: diary.content,
///   operations: [
///     if (autoTagEnabled) TriageOperation.autoTag,
///     if (autoClassifyEnabled) TriageOperation.autoClassify,
///     if (looksExtractable) TriageOperation.extractPlan,
///   ],
/// );
/// for (final op in result.sendOperations) { /* 入队对应任务 */ }
/// ```
class AiTriageService {
  AiTriageService._();

  static final AiTriageService instance = AiTriageService._();

  AiTriageRouter router = const AiTriageRouter();

  /// 缓存最近一次分流结果（详情页"为什么"展示用；key = 笔记 id）
  final Map<String, TriageResult> _recent = {};

  TriageResult? recentFor(String refId) => _recent[refId];

  @visibleForTesting
  void clearRecent() => _recent.clear();

  /// 做分流决策（读取已保存的配置）。
  Future<TriageResult> route({
    required String text,
    required List<TriageOperation> operations,
    TriageContentType contentType = TriageContentType.text,
    Set<TriageOperation> explicitUserIntent = const {},
    String? extraSensitiveText,
    String? refId,
  }) async {
    if (operations.isEmpty) {
      return TriageResult(
        contentType: contentType,
        decisions: const {},
        confidence: 0,
      );
    }
    final config = await TriageConfigStore.load();
    final result = router.route(
      text: text,
      operations: operations,
      config: config,
      contentType: contentType,
      explicitUserIntent: explicitUserIntent,
      extraSensitiveText: extraSensitiveText,
    );
    if (refId != null && config.showExplanations) {
      _recent[refId] = result;
      // 只保留最近 200 条，避免内存无上限
      if (_recent.length > 200) {
        _recent.remove(_recent.keys.first);
      }
    }
    // 现场可诊断：保存内容后一条日志就能看出"送了什么、拦了什么"
    if (kDebugMode) {
      final sent = result.sendOperations.map((e) => e.name).join('、');
      final kept = result.localOperations.map((e) => e.name).join('、');
      debugPrint(
        '[Triage] ${contentType.name} → 送AI[${sent.isEmpty ? '-' : sent}] '
        '本地[${kept.isEmpty ? '-' : kept}]'
        ' 打分=${result.score}'
        '${result.hasSensitive ? ' 敏感:${result.sensitiveKinds.join('/')}' : ''}'
        '${refId == null ? '' : ' ref=$refId'}',
      );
    }
    return result;
  }

  /// 单操作快速判断（队列执行前用）。
  ///
  /// 返回 true 表示"这次可以真正调用 AI"。
  Future<bool> allowOperation({
    required TriageOperation operation,
    required String text,
    TriageContentType contentType = TriageContentType.text,
    bool explicitUserIntent = false,
  }) async {
    final config = await TriageConfigStore.load();
    if (config.quota.exhausted) return false;
    final result = router.route(
      text: text,
      operations: [operation],
      config: config,
      contentType: contentType,
      explicitUserIntent: explicitUserIntent ? {operation} : const {},
    );
    return result.decisions[operation]?.shouldSendToAI ?? false;
  }

  /// 当前配置
  Future<TriageConfig> config() => TriageConfigStore.load();

  /// 保存配置
  Future<void> saveConfig(TriageConfig config) =>
      TriageConfigStore.save(config);

  /// 消费一次额度（真正调用 AI 前后都可调；这里在入队成功后调用）
  Future<void> consumeQuota() => TriageConfigStore.consumeQuota();
}
