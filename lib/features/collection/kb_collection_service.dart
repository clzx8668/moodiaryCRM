/// 主题知识库集合的成员管理（meta 承载，不建新表）。
///
/// 成员对象限定为 Block（笔记）；文件/链接/CRM 等多类型作为后续增强，
/// 先把「把笔记归入灵活主题集合」跑通（对标得到大脑主题知识库）。
class KbCollectionService {
  KbCollectionService._();

  /// 解析当前集合字符串为 id 列表。
  static List<String> parse(String raw) {
    final result = <String>[];
    final seen = <String>{};
    if (raw.trim().isEmpty) return result;
    for (final e in raw.split(',')) {
      final t = e.trim();
      if (t.isNotEmpty && seen.add(t)) result.add(t);
    }
    return result;
  }

  static String encode(List<String> ids) {
    final seen = <String>{};
    final result = <String>[];
    for (final id in ids) {
      final t = id.trim();
      if (t.isEmpty) continue;
      if (seen.add(t)) result.add(t);
    }
    return result.join(',');
  }

  static bool contains(String raw, String kbId) => parse(raw).contains(kbId);

  static String add(String raw, String kbId) {
    final list = parse(raw);
    final t = kbId.trim();
    if (t.isEmpty || list.contains(t)) return raw;
    list.add(t);
    return encode(list);
  }

  static String remove(String raw, String kbId) {
    final list = parse(raw)..remove(kbId.trim());
    return encode(list);
  }
}
