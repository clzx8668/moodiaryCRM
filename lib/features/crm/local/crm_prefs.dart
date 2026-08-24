import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/persistence/pref.dart';

/// CRM 页面功能开关与偏好统一读写。
/// 键全部落在 PrefUtil 白名单（crmTabVisible_ 前缀 / crmDefaultCurrency）。
class CrmPrefs {
  static const String _tabVisiblePrefix = 'crmTabVisible_';
  static const String defaultCurrencyKey = 'crmDefaultCurrency';

  /// 对象页签是否在 CRM 页面显示（默认全部显示）。
  static bool tabVisible(String type) =>
      PrefUtil.getValue<bool>('$_tabVisiblePrefix$type') ?? true;

  static Future<void> setTabVisible(String type, bool value) =>
      PrefUtil.setValue<bool>('$_tabVisiblePrefix$type', value);

  /// 系统默认币种（新建/未设置时使用）。
  static String defaultCurrency() =>
      PrefUtil.getValue<String>(defaultCurrencyKey) ?? kDefaultCurrency;

  static Future<void> setDefaultCurrency(String code) =>
      PrefUtil.setValue<String>(defaultCurrencyKey, code);

  /// 已启用的基础对象 Tab（按 [kCrmTabs] 顺序，过滤被隐藏的）。
  static List<CrmTabDef> enabledTabs() =>
      [for (final tab in kCrmTabs) if (tabVisible(tab.type)) tab];

  /// 恢复某对象的列设置为默认（清空自定义列/隐藏/定制标记）。
  static Future<void> resetColumns(String type) async {
    await PrefUtil.setValue<List<String>>('crmTableColumns_$type', const []);
    await PrefUtil.setValue<List<String>>('crmTableHidden_$type', const []);
    await PrefUtil.setValue<bool>('crmTableColumnsCustomized_$type', false);
  }

  /// 恢复全部内置对象的列设置为默认。
  static Future<void> resetAllColumns() async {
    for (final tab in kCrmTabs) {
      await resetColumns(tab.type);
    }
  }
}
