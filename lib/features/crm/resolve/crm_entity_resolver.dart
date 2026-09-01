import 'package:moodiary/features/crm/local/crm_local_repository.dart';

/// 匹配层级。
enum CrmMatchLevel { exact, fuzzy, none }

/// 单条匹配候选（返回 entityId + entityType + 置信度，不拼名字）。
class CrmResolveMatch {
  final String entityId;
  final String entityType;
  final String name;
  final double confidence;
  final CrmMatchLevel level;

  const CrmResolveMatch({
    required this.entityId,
    required this.entityType,
    required this.name,
    required this.confidence,
    required this.level,
  });
}

/// 解析结果：按置信度排序的候选 + 是否有精确命中。
class CrmResolveResult {
  final List<CrmResolveMatch> matches;

  const CrmResolveResult(this.matches);

  bool get hasExact => matches.any((m) => m.level == CrmMatchLevel.exact);

  CrmResolveMatch? get best =>
      matches.isEmpty ? null : matches.first;
}

/// CRM 实体三层解析（本地只读，防止 AI 对接出错）。
///
/// 1) 唯一键/精确：name/phone/email 精确相等；
/// 2) 包含：名称包含关键词；
/// 3) 模糊：归一化后编辑距离相似度（阈值 [fuzzyThreshold]）。
/// 始终返回 entityId + entityType（不是名字），供下游 id 关联。
class CrmEntityResolver {
  static const double fuzzyThreshold = 0.6;

  final CrmLocalRepository _repo;

  CrmEntityResolver([CrmLocalRepository? repo])
      : _repo = repo ?? CrmLocalRepository();

  Future<CrmResolveResult> resolve({
    required String objectType,
    required String name,
    String? phone,
    String? email,
  }) async {
    final keyword = name.trim();
    final matches = <CrmResolveMatch>[];
    if (objectType == 'account') {
      for (final a in await _repo.listAccounts()) {
        _match(
          matches,
          'account',
          a.id,
          a.name,
          keyword,
          phone: phone,
          email: email,
          phoneVal: a.phone,
          emailVal: a.email,
        );
      }
    } else if (objectType == 'contact') {
      for (final c in await _repo.listContacts()) {
        _match(
          matches,
          'contact',
          c.id,
          c.name,
          keyword,
          phone: phone,
          email: email,
          phoneVal: c.phone,
          emailVal: c.email,
        );
      }
    } else if (objectType == 'opportunity') {
      for (final o in await _repo.listOpportunities()) {
        _match(matches, 'opportunity', o.id, o.name, keyword);
      }
    } else if (objectType == 'contract') {
      for (final c in await _repo.listContracts()) {
        _match(matches, 'contract', c.id, c.name, keyword);
      }
    }

    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return CrmResolveResult(matches.take(3).toList());
  }

  void _match(
    List<CrmResolveMatch> out,
    String type,
    String id,
    String candidateName,
    String keyword, {
    String? phone,
    String? email,
    String? phoneVal,
    String? emailVal,
  }) {
    if (keyword.isNotEmpty && candidateName == keyword) {
      out.add(_m(type, id, candidateName, 1.0, CrmMatchLevel.exact));
      return;
    }
    if ((phone != null && phone.trim().isNotEmpty && phoneVal == phone) ||
        (email != null && email.trim().isNotEmpty && emailVal == email)) {
      out.add(_m(type, id, candidateName, 1.0, CrmMatchLevel.exact));
      return;
    }
    final score = similarity(normalize(candidateName), normalize(keyword));
    if (candidateName.contains(keyword) || keyword.contains(candidateName)) {
      out.add(_m(type, id, candidateName, 0.85, CrmMatchLevel.fuzzy));
    } else if (score >= fuzzyThreshold) {
      out.add(_m(type, id, candidateName, score, CrmMatchLevel.fuzzy));
    }
  }

  CrmResolveMatch _m(
    String type,
    String id,
    String name,
    double conf,
    CrmMatchLevel level,
  ) => CrmResolveMatch(
    entityId: id,
    entityType: type,
    name: name,
    confidence: conf,
    level: level,
  );

  /// 归一化：转小写、去空白/标点。
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s·、，。!！,\.\-_/]+'), '');

  /// 归一化后编辑距离相似度（0~1）。
  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 0;
    final dist = _levenshtein(a, b);
    final max = a.length > b.length ? a.length : b.length;
    if (max == 0) return 0;
    return (1 - dist / max).clamp(0.0, 1.0);
  }

  static int _levenshtein(String a, String b) {
    final dp = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var prev = dp[0];
      dp[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final tmp = dp[j];
        dp[j] = a[i - 1] == b[j - 1]
            ? prev
            : 1 + (prev < dp[j - 1] ? (prev < dp[j] ? prev : dp[j]) : (dp[j - 1] < dp[j] ? dp[j - 1] : dp[j]));
        prev = tmp;
      }
    }
    return dp[b.length];
  }
}
