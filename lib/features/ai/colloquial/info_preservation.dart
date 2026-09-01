/// 去口语化后的「信息保全」校验（本地，0 token）。
///
/// 从原文抽取高风险关键信息（数字 / 日期时间 / 手机号 / 座机 / 金额），
/// 校验改写后是否仍保留；缺失即认为改写语义漂移，丢弃本次结果。
/// 纯函数，可测。
class InfoPreservationResult {
  final bool ok;
  final List<String> lost;

  const InfoPreservationResult({required this.ok, required this.lost});
}

class InfoPreservation {
  static final RegExp _ws = RegExp(r'\s+');
  static final RegExp _phone = RegExp(r'1[3-9]\d{9}');
  static final RegExp _landline = RegExp(r'0\d{2,3}-?\d{7,8}');
  static final RegExp _dateFull =
      RegExp(r'\d{4}[年/-]\d{1,2}[月/-]\d{1,2}日?');
  static final RegExp _dateMonthDay = RegExp(r'\d{1,2}月\d{1,2}日');
  static final RegExp _time = RegExp(r'[上下]午?\d{1,2}[:：]\d{2}');
  static final RegExp _currency = RegExp(r'[¥￥]\s?\d+(\.\d+)?|\d+(\.\d+)?\s?元');

  static InfoPreservationResult verify(String original, String rewritten) {
    final lost = <String>[];
    if (original.trim().isEmpty) {
      return const InfoPreservationResult(ok: true, lost: []);
    }
    // 改写可能插入空格（如"3000 元"），统一去空白后再比对。
    final rw = rewritten.replaceAll(_ws, '');

    _protect(original, rw, _phone, lost);
    _protect(original, rw, _landline, lost);
    _protect(original, rw, _dateFull, lost);
    _protect(original, rw, _dateMonthDay, lost);
    _protect(original, rw, _time, lost);
    _protectNumeric(original, rw, lost);
    _protect(original, rw, _currency, lost);

    return InfoPreservationResult(ok: lost.isEmpty, lost: lost);
  }

  /// 精确匹配型关键信息：原文出现的每一项都必须在改写后出现。
  static void _protect(
    String original,
    String rewritten,
    RegExp regex,
    List<String> lost,
  ) {
    for (final m in regex.allMatches(original)) {
      final token = m.group(0)!.replaceAll(_ws, '');
      if (token.isEmpty) continue;
      if (token.length == 1 && token.codeUnitAt(0) >= 48 && token.codeUnitAt(0) <= 57) {
        // 单个数字不视为关键信息（过于宽泛，误报率高）
        continue;
      }
      if (!rewritten.contains(token)) {
        lost.add(token);
      }
    }
  }

  /// 数字集合保全（去重后判断；避免"1""2"等泛化误报）。
  static void _protectNumeric(String original, String rewritten, List<String> lost) {
    final nums = original
        .split(RegExp(r'[^\d.]+'))
        .where((s) => s.length >= 2)
        .toSet();
    for (final n in nums) {
      if (!rewritten.contains(n)) {
        lost.add(n);
      }
    }
  }
}
