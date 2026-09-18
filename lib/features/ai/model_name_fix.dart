/// 模型名容错（纯函数，便于单测）。
///
/// 背景（批次 91 真机发现）：服务商只接受规范 slug（如 `deepseek-v4-flash`），
/// 而配置里可能存的是展示名（如 `DeepSeek-V4-Flash`、`QW-DeepSeek-V4-Flash`）。
/// 这种大小写/前缀差异会让请求 400，进而让**所有** AI 任务全灭，且错误信息
/// 看起来像"接口错误"而不是"配置错了"。
///
/// 处理方式：当服务端明确列出「supported API model names are …」时，做一次
/// 忽略大小写/连字符、允许前缀的匹配，命中就用规范名重试一次。
class ModelNameFix {
  ModelNameFix._();

  /// 服务端提示里列出可选模型的标志短语（小写比较）。
  static const String _marker = 'model names are';

  /// 从服务端错误文案里解析可选模型列表；解析不到返回空列表。
  static List<String> parseSupported(String? message) {
    if (message == null || message.isEmpty) return const [];
    final lower = message.toLowerCase();
    final marker = lower.indexOf(_marker);
    if (marker < 0) return const [];
    var rest = message.substring(marker + _marker.length);
    // 截断到下一句/转折处，只留下列表部分
    final cuts = <int>[
      rest.indexOf(', but'),
      rest.indexOf('. '),
      rest.indexOf('\n'),
      rest.indexOf('。'),
    ].where((i) => i >= 0).toList();
    if (cuts.isNotEmpty) {
      cuts.sort();
      rest = rest.substring(0, cuts.first);
    }
    return rest
        .split(',')
        .map((e) => e.trim().replaceAll(RegExp(r'''[."'。]+$'''), ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 在候选模型里找与 [requested] 等价的规范名；找不到返回 null。
  ///
  /// 匹配顺序：忽略大小写/连字符后完全相同 → 规范名是配置名的后缀
  /// （覆盖 `QW-DeepSeek-V4-Flash` 这类加了展示前缀的情况）。
  static String? match({
    required String requested,
    required List<String> supported,
  }) {
    final want = _normalize(requested);
    if (want.isEmpty) return null;
    for (final candidate in supported) {
      if (_normalize(candidate) == want) return candidate;
    }
    for (final candidate in supported) {
      final c = _normalize(candidate);
      if (c.isNotEmpty && want.endsWith('-$c')) return candidate;
    }
    return null;
  }

  /// 一步到位：从服务端错误文案得到应改用的模型名；不需要纠正时返回 null。
  static String? fromError({required String requested, String? message}) {
    final supported = parseSupported(message);
    if (supported.isEmpty) return null;
    final matched = match(requested: requested, supported: supported);
    if (matched == null) return null;
    // 已经规范就无需重试
    return matched.trim() == requested.trim() ? null : matched;
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('_', '-')
      .replaceAll(RegExp(r'\s+'), '');
}
