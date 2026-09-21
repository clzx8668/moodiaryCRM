import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moodiary/features/ai/triage/triage_types.dart';
import 'package:moodiary/persistence/secure_storage.dart';

/// 分流策略档位。
enum TriageLevel {
  /// 保守：只有规则**明确命中**才送 AI，其余一律本地（最省额度、最保护隐私）
  conservative,

  /// 平衡（默认）：规则命中直接送；未命中时由本地分类器兜底判断
  balanced,

  /// 激进：几乎都送 AI（本地只挡敏感内容与空内容）
  aggressive,
}

extension TriageLevelLabel on TriageLevel {
  String get label => switch (this) {
    TriageLevel.conservative => '保守（最省额度）',
    TriageLevel.balanced => '平衡（推荐）',
    TriageLevel.aggressive => '激进（尽量送 AI）',
  };

  String get description => switch (this) {
    TriageLevel.conservative => '只有明确命中信号才联网处理，其余全部本地保存',
    TriageLevel.balanced => '规则优先；规则拿不准时用本地分类器兜底判断',
    TriageLevel.aggressive => '本地只拦敏感信息与空内容，其余尽量交给 AI',
  };
}

/// 每月的云端处理额度（超出后自动转为本地，避免意外花销）。
class TriageQuota {
  /// 每月最多送多少次 AI（0 = 不限制）
  final int monthlyLimit;

  /// 本月已用次数
  final int usedThisMonth;

  /// 记录所属月份（`2026-09`）
  final String month;

  const TriageQuota({
    this.monthlyLimit = 0,
    this.usedThisMonth = 0,
    this.month = '',
  });

  bool get unlimited => monthlyLimit <= 0;

  int get remaining =>
      unlimited ? -1 : (monthlyLimit - usedThisMonth).clamp(0, monthlyLimit);

  bool get exhausted => !unlimited && usedThisMonth >= monthlyLimit;

  double get usage =>
      unlimited ? 0 : (usedThisMonth / monthlyLimit).clamp(0.0, 1.0);

  TriageQuota copyWith({int? monthlyLimit, int? usedThisMonth, String? month}) =>
      TriageQuota(
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
        usedThisMonth: usedThisMonth ?? this.usedThisMonth,
        month: month ?? this.month,
      );

  Map<String, dynamic> toJson() => {
    'monthlyLimit': monthlyLimit,
    'usedThisMonth': usedThisMonth,
    'month': month,
  };

  factory TriageQuota.fromJson(Map<String, dynamic> json) => TriageQuota(
    monthlyLimit: (json['monthlyLimit'] as num?)?.toInt() ?? 0,
    usedThisMonth: (json['usedThisMonth'] as num?)?.toInt() ?? 0,
    month: json['month']?.toString() ?? '',
  );
}

/// 分流配置（持久化到安全存储，跟着用户走）。
class TriageConfig {
  /// 策略档位
  final TriageLevel level;

  /// 是否允许把**含敏感信息**的内容送到云端（默认 false = 隐私优先）
  final bool allowSensitiveToCloud;

  /// 关闭某些操作（被关掉的操作一律本地，不入队）
  final Set<TriageOperation> disabledOperations;

  /// 额度
  final TriageQuota quota;

  /// 是否在笔记上展示"为什么送/不送"的分流说明
  final bool showExplanations;

  const TriageConfig({
    this.level = TriageLevel.balanced,
    this.allowSensitiveToCloud = false,
    this.disabledOperations = const {},
    this.quota = const TriageQuota(),
    this.showExplanations = true,
  });

  bool isEnabled(TriageOperation op) => !disabledOperations.contains(op);

  TriageConfig copyWith({
    TriageLevel? level,
    bool? allowSensitiveToCloud,
    Set<TriageOperation>? disabledOperations,
    TriageQuota? quota,
    bool? showExplanations,
  }) => TriageConfig(
    level: level ?? this.level,
    allowSensitiveToCloud:
        allowSensitiveToCloud ?? this.allowSensitiveToCloud,
    disabledOperations: disabledOperations ?? this.disabledOperations,
    quota: quota ?? this.quota,
    showExplanations: showExplanations ?? this.showExplanations,
  );

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'allowSensitiveToCloud': allowSensitiveToCloud,
    'disabledOperations': disabledOperations.map((e) => e.name).toList(),
    'quota': quota.toJson(),
    'showExplanations': showExplanations,
  };

  factory TriageConfig.fromJson(Map<String, dynamic> json) => TriageConfig(
    level: TriageLevel.values.firstWhere(
      (e) => e.name == json['level'],
      orElse: () => TriageLevel.balanced,
    ),
    allowSensitiveToCloud: json['allowSensitiveToCloud'] == true,
    disabledOperations: _parseDisabled(json['disabledOperations']),
    quota: json['quota'] is Map<String, dynamic>
        ? TriageQuota.fromJson(json['quota'] as Map<String, dynamic>)
        : const TriageQuota(),
    showExplanations: json['showExplanations'] != false,
  );

  /// 解析被关闭的操作名（无法识别的名字直接忽略）
  static Set<TriageOperation> _parseDisabled(Object? raw) {
    if (raw is! List) return const {};
    final out = <TriageOperation>{};
    for (final n in raw) {
      for (final op in TriageOperation.values) {
        if (op.name == n) out.add(op);
      }
    }
    return out;
  }
}

/// 分流配置的读写（与 AI 能力配置同一套安全存储）。
class TriageConfigStore {
  TriageConfigStore._();

  static const String _key = 'ai_triage_config';

  static TriageConfig? _cache;

  /// 当前月份标记（`2026-09`）
  static String currentMonth(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  static Future<TriageConfig> load({DateTime? now}) async {
    final cached = _cache;
    if (cached != null) return _rollover(cached, now ?? DateTime.now());
    String? raw;
    try {
      raw = await SecureStorageUtil.getValue(_key);
    } catch (e) {
      // 安全存储不可用（单元测试环境 / 系统 KeyStore 异常）：
      // 分流是**旁路优化**，不能因为它读不到配置就让保存流程失败。
      // 这里退回默认策略（平衡档 + 隐私优先），并打日志便于排查。
      debugPrint('[Triage] 读取分流配置失败，使用默认策略：$e');
      return const TriageConfig();
    }
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          final cfg = _rollover(
            TriageConfig.fromJson(json),
            now ?? DateTime.now(),
          );
          _cache = cfg;
          return cfg;
        }
      } catch (_) {
        // 损坏 → 用默认值
      }
    }
    const fallback = TriageConfig();
    _cache = fallback;
    return fallback;
  }

  static Future<void> save(TriageConfig config) async {
    _cache = config;
    try {
      await SecureStorageUtil.setValue(_key, jsonEncode(config.toJson()));
    } catch (e) {
      // 存不下就只在本次会话生效，不让设置页崩掉
      debugPrint('[Triage] 保存分流配置失败（本次会话内仍生效）：$e');
    }
  }

  /// 额度计数 +1（跨月自动归零）
  static Future<TriageConfig> consumeQuota({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final cfg = await load(now: t);
    final next = cfg.copyWith(
      quota: cfg.quota.copyWith(
        usedThisMonth: cfg.quota.usedThisMonth + 1,
        month: currentMonth(t),
      ),
    );
    await save(next);
    return next;
  }

  /// 跨月自动把用量归零
  static TriageConfig _rollover(TriageConfig cfg, DateTime now) {
    final month = currentMonth(now);
    if (cfg.quota.month == month) return cfg;
    return cfg.copyWith(quota: cfg.quota.copyWith(usedThisMonth: 0, month: month));
  }

  /// 仅供测试
  static void resetCacheForTest() => _cache = null;
}
