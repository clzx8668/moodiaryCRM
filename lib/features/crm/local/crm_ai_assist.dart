/// AI 辅助录入：从自由文本中提取实体字段（MVP 为启发式规则，
/// 后续可替换为 LLM 结构化抽取，接口保持稳定）。
library;

class CrmAiExtraction {
  final String? name;
  final double? amount;
  final String? phone;
  final String? email;
  final DateTime? closeDate;
  final String? stage;
  final String note;

  const CrmAiExtraction({
    this.name,
    this.amount,
    this.phone,
    this.email,
    this.closeDate,
    this.stage,
    this.note = '',
  });

  bool get isEmpty =>
      name == null &&
      amount == null &&
      phone == null &&
      email == null &&
      closeDate == null &&
      stage == null;
}

class CrmAiAssist {
  static final RegExp _amount = RegExp(
    r'(\d+(?:\.\d+)?)\s*(万元|万|元)',
  );
  static final RegExp _phone = RegExp(r'1[3-9]\d{9}');
  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  static final RegExp _date = RegExp(
    r'(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})日?',
  );

  /// 提取自由文本中的 CRM 字段。
  static CrmAiExtraction extractFromText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const CrmAiExtraction();

    final lines = trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 名称：首行（去除列表符号/序号），剔除明显非名称行
    String? name;
    for (final line in lines) {
      final candidate = line
          .replaceFirst(RegExp(r'^[-*•\d.、\s]+'), '')
          .trim();
      if (candidate.isEmpty) continue;
      if (_amount.hasMatch(candidate) &&
          !_containsEntityKeywords(candidate)) {
        continue;
      }
      name = candidate;
      break;
    }

    // 金额：万元→元
    double? amount;
    for (final m in _amount.allMatches(trimmed)) {
      final value = double.tryParse(m.group(1)!);
      if (value == null) continue;
      final unit = m.group(2);
      amount = unit == '万元' ? value * 10000 : value;
      break;
    }

    final phone = _phone.firstMatch(trimmed)?.group(0);
    final email = _email.firstMatch(trimmed)?.group(0);

    DateTime? closeDate;
    final dateMatch = _date.firstMatch(trimmed);
    if (dateMatch != null) {
      closeDate = DateTime(
        int.parse(dateMatch.group(1)!),
        int.parse(dateMatch.group(2)!),
        int.parse(dateMatch.group(3)!),
      );
    }

    String? stage;
    if (trimmed.contains('赢单')) {
      stage = 'closedWon';
    } else if (trimmed.contains('输单')) {
      stage = 'closedLost';
    } else if (trimmed.contains('报价') || trimmed.contains('方案')) {
      stage = 'proposal';
    } else if (trimmed.contains('谈判')) {
      stage = 'negotiation';
    } else if (trimmed.contains('需求') || trimmed.contains('确认')) {
      stage = 'qualified';
    } else if (trimmed.contains('联系')) {
      stage = 'contacted';
    } else if (trimmed.contains('线索')) {
      stage = 'newLead';
    }

    return CrmAiExtraction(
      name: name,
      amount: amount,
      phone: phone,
      email: email,
      closeDate: closeDate,
      stage: stage,
      note: trimmed,
    );
  }

  static bool _containsEntityKeywords(String text) =>
      text.contains('客户') ||
      text.contains('公司') ||
      text.contains('机会') ||
      text.contains('项目') ||
      text.contains('合作');
}
