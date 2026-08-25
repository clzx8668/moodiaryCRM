import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:flutter/foundation.dart';

/// CRM 页面功能开关与偏好统一读写。
/// 键全部落在 PrefUtil 白名单（crmTabVisible_ 前缀 / crmDefaultCurrency）。
class CrmPrefs {
  static const String _tabVisiblePrefix = 'crmTabVisible_';
  static const String defaultCurrencyKey = 'crmDefaultCurrency';
  static const String freezeFirstColumnKey = 'crmTableFreezeFirst';
  static const String firstColumnWidthKey = 'crmFirstColumnWidth';
  static const String columnWidthLockedKey = 'crmColumnWidthLocked';

  /// 偏好变更通知：设置页修改表格相关偏好后递增，表格页监听以即时生效。
  static final ValueNotifier<int> prefsVersion = ValueNotifier(0);

  static void notifyChanged() => prefsVersion.value++;

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

  /// 表格首列（复选框+首列内容融合）是否冻结。
  /// [type] 非空时优先按对象单独设置；否则读全局默认（默认冻结）。
  static bool freezeFirstColumn([String? type]) {
    if (type != null) {
      final perTable = PrefUtil.getValue<bool>(
        '${freezeFirstColumnKey}_$type',
      );
      if (perTable != null) return perTable;
    }
    return PrefUtil.getValue<bool>(freezeFirstColumnKey) ?? true;
  }

  static Future<void> setFreezeFirstColumn(bool value, {String? type}) async {
    await PrefUtil.setValue<bool>(
      type == null ? freezeFirstColumnKey : '${freezeFirstColumnKey}_$type',
      value,
    );
    notifyChanged();
  }

  /// 首列统一宽度（0/未设置 = 按屏宽自适应 300/200/180）。
  static double? firstColumnWidth() {
    final raw = PrefUtil.getValue<int>(firstColumnWidthKey) ?? 0;
    return raw <= 0 ? null : raw.toDouble();
  }

  static Future<void> setFirstColumnWidth(int? width) async {
    await PrefUtil.setValue<int>(firstColumnWidthKey, width ?? 0);
    notifyChanged();
  }

  /// 列宽是否锁定（锁定后禁止拖拽调整列宽；默认锁定）。
  static bool columnWidthLocked() =>
      PrefUtil.getValue<bool>(columnWidthLockedKey) ?? true;

  static Future<void> setColumnWidthLocked(bool value) async {
    await PrefUtil.setValue<bool>(columnWidthLockedKey, value);
    notifyChanged();
  }

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
