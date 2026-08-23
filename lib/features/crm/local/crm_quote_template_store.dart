import 'dart:convert';

import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/persistence/pref.dart';

/// 报价模板（PrefUtil JSON 存储）：保存当前报价为模板、从模板快速生成报价。
class CrmQuoteTemplateStore {
  static const String _key = 'crmQuoteTemplates';

  static Future<List<CrmQuoteTemplate>> list() async {
    final raw = PrefUtil.getValue<String>(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => CrmQuoteTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(CrmQuoteTemplate template) async {
    final templates = await list();
    templates.removeWhere((t) => t.name == template.name);
    templates.add(template);
    await PrefUtil.setValue<String>(
      _key,
      jsonEncode([for (final t in templates) t.toJson()]),
    );
  }

  static Future<void> delete(String name) async {
    final templates = await list();
    templates.removeWhere((t) => t.name == name);
    await PrefUtil.setValue<String>(
      _key,
      jsonEncode([for (final t in templates) t.toJson()]),
    );
  }

  /// 从模板快速创建报价单（草稿 + 明细，有效期 = 模板配置天数）。
  static Future<LocalQuote> createQuoteFromTemplate(
    CrmLocalRepository repo,
    CrmQuoteTemplate template,
  ) async {
    final quote = await repo.createQuote(
      LocalQuote(
        id: '',
        status: 'draft',
        validUntil: DateTime.now().add(
          Duration(days: template.validUntilDays),
        ),
      ),
    );
    for (var i = 0; i < template.items.length; i++) {
      final item = template.items[i];
      await repo.addQuoteItem(
        LocalQuoteItem(
          id: '',
          quoteId: quote.id,
          productName: item['productName']?.toString() ?? '',
          quantity: (item['quantity'] as num?)?.toDouble() ?? 1,
          unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0,
          discount: (item['discount'] as num?)?.toDouble() ?? 1,
          sortOrder: i,
        ),
      );
    }
    return quote;
  }
}
