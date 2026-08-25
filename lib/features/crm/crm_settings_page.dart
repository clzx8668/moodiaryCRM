import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/crm_object_table_tab.dart';
import 'package:moodiary/features/crm/local/crm_backup_codec.dart';
import 'package:moodiary/features/crm/local/crm_demo_data.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/crm/local/crm_prefs.dart';
import 'package:moodiary/utils/notice_util.dart';

/// CRM 设置页：对象页签开关 / 默认币种 / 列设置管理 / 自定义对象 / 演示数据。
class CrmSettingsPage extends StatefulWidget {
  const CrmSettingsPage({super.key});

  @override
  State<CrmSettingsPage> createState() => _CrmSettingsPageState();
}

class _CrmSettingsPageState extends State<CrmSettingsPage> {
  List<LocalCustomObject> _customObjects = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomObjects();
  }

  Future<void> _loadCustomObjects() async {
    final defs = await CrmLocalRepository().listCustomObjects();
    if (mounted) setState(() => _customObjects = defs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CRM 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('对象页签'),
          _card(
            children: [
              for (var i = 0; i < kCrmTabs.length; i++)
                _tabSwitch(kCrmTabs[i], isFirst: i == 0, isLast: i == kCrmTabs.length - 1),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('通用'),
          _card(
            children: [
              _defaultCurrencyTile(),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.push_pin_outlined),
                title: const Text('表格第一列冻结'),
                subtitle: const Text('全局默认：各表首列（复选框+首列内容）冻结；可在各表列设置中单独调整'),
                value: CrmPrefs.freezeFirstColumn(),
                onChanged: (v) async {
                  await CrmPrefs.setFreezeFirstColumn(v);
                  if (mounted) setState(() {});
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.width_normal_outlined),
                title: const Text('首列宽度'),
                subtitle: Text(
                  CrmPrefs.firstColumnWidth() == null
                      ? '自适应（桌面 300 / 平板 200 / 移动端 180）'
                      : '固定 ${CrmPrefs.firstColumnWidth()!.toInt()}px（0 恢复自适应）',
                ),
                onTap: () => _editFirstColumnWidth(context),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline_rounded),
                title: const Text('锁定列宽'),
                subtitle: const Text('开启后禁止拖拽调整列宽；关闭可拖拽调整，调好后再锁定'),
                value: CrmPrefs.columnWidthLocked(),
                onChanged: (v) async {
                  await CrmPrefs.setColumnWidthLocked(v);
                  if (mounted) setState(() {});
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.view_column_outlined),
                title: const Text('恢复全部列设置为默认'),
                subtitle: const Text('清空各表格自定义的列显示/顺序/隐藏'),
                onTap: () => _confirmResetAllColumns(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('自定义对象'),
          _card(
            children: [
              if (_customObjects.isEmpty)
                const ListTile(
                  leading: Icon(Icons.folder_outlined),
                  title: Text('暂无自定义对象'),
                  subtitle: Text('可新建回款/发票等业务表，字段后续在对象内配置'),
                )
              else
                for (var i = 0; i < _customObjects.length; i++)
                  _customObjectTile(
                    _customObjects[i],
                    isFirst: i == 0,
                    isLast: i == _customObjects.length - 1,
                  ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('新建自定义对象'),
                onTap: () => _createCustomObject(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('数据'),
          _card(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('生成演示数据'),
                subtitle: const Text('为每个表追加 5–10 条带关联的测试数据'),
                onTap: _seedDemoData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('导出数据（JSON）'),
                subtitle: const Text('导出全部 CRM 数据为备份文件，便于调试'),
                onTap: _exportData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('导入数据（JSON）'),
                subtitle: const Text('从备份文件导入（按 id 幂等合并）'),
                onTap: _importData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.delete_sweep_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '一键清空 CRM 数据',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('物理删除全部记录（保留自定义对象定义）'),
                onTap: () => _clearAll(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: Colors.grey),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Card.filled(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }

  Widget _tabSwitch(CrmTabDef tab, {required bool isFirst, required bool isLast}) {
    return SwitchListTile(
      value: CrmPrefs.tabVisible(tab.type),
      onChanged: (v) async {
        await CrmPrefs.setTabVisible(tab.type, v);
        if (mounted) setState(() {});
      },
      title: Text(tab.label),
      secondary: Icon(crmTypeIcon(tab.type), color: crmTypeColor(tab.type)),
      dense: true,
      isThreeLine: false,
      controlAffinity: ListTileControlAffinity.trailing,
      shape: _tileShape(isFirst, isLast),
    );
  }

  Widget _defaultCurrencyTile() {
    return ListTile(
      leading: const Icon(Icons.currency_exchange_rounded),
      title: const Text('默认币种'),
      subtitle: Text('新建金额类字段默认使用：${CrmPrefs.defaultCurrency()}'),
      trailing: DropdownButton<String>(
        value: CrmPrefs.defaultCurrency(),
        underline: const SizedBox.shrink(),
        items: [
          for (final code in kCurrencies)
            DropdownMenuItem(value: code, child: Text(code)),
        ],
        onChanged: (v) async {
          if (v == null) return;
          await CrmPrefs.setDefaultCurrency(v);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  /// 首列宽度设置：输入像素值（0 = 按屏宽自适应）。
  Future<void> _editFirstColumnWidth(BuildContext context) async {
    final controller = TextEditingController(
      text: CrmPrefs.firstColumnWidth()?.toInt().toString() ?? '0',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('首列宽度'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '像素（0 = 自适应 300/200/180）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final width = int.tryParse(controller.text.trim());
    if (width == null || width < 0) return;
    await CrmPrefs.setFirstColumnWidth(width == 0 ? null : width);
    if (mounted) setState(() {});
  }

  Widget _customObjectTile(
    LocalCustomObject def, {
    required bool isFirst,
    required bool isLast,
  }) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(def.labelPlural),
      subtitle: Text(
        '${def.labelSingular} · ${def.fields.length} 个字段',
      ),
      trailing: IconButton(
        tooltip: '删除对象及其数据',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteCustomObject(def),
      ),
      shape: _tileShape(isFirst, isLast),
    );
  }

  ShapeBorder _tileShape(bool isFirst, bool isLast) {
    if (isFirst && isLast) {
      return RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    }
    if (isFirst) {
      return const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      );
    }
    if (isLast) {
      return const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      );
    }
    return const RoundedRectangleBorder();
  }

  Future<void> _confirmResetAllColumns(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复默认列设置'),
        content: const Text('将清空所有表格自定义的列显示/顺序/隐藏，恢复系统默认。确认继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CrmPrefs.resetAllColumns();
    toast.success(message: '已恢复全部默认列');
  }

  Future<void> _createCustomObject(BuildContext context) async {
    final singular = TextEditingController();
    final plural = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建自定义对象'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: plural,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '对象名称（复数，如：回款）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: singular,
                decoration: const InputDecoration(
                  labelText: '单数名称（如：一笔回款）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final pluralName = plural.text.trim();
    final singularName = singular.text.trim();
    if (pluralName.isEmpty) {
      toast.info(message: '请填写对象名称');
      return;
    }
    try {
      await CrmLocalRepository().createCustomObject(
        LocalCustomObject(
          id: '',
          labelSingular: singularName.isEmpty ? pluralName : singularName,
          labelPlural: pluralName,
          icon: 'folder',
          fields: [
            const CrmFieldDef(
              name: 'name',
              label: '名称',
              type: 'text',
              order: 0,
            ),
          ],
        ),
      );
      toast.success(message: '已创建「$pluralName」');
      await _loadCustomObjects();
    } catch (e) {
      toast.error(message: '创建失败：$e');
    }
  }

  Future<void> _deleteCustomObject(LocalCustomObject def) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除自定义对象'),
        content: Text('将删除对象「${def.labelPlural}」及其全部数据，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CrmLocalRepository().deleteCustomObject(def.id);
      toast.success(message: '已删除');
      await _loadCustomObjects();
    } catch (e) {
      toast.error(message: '删除失败：$e');
    }
  }

  Future<void> _seedDemoData() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final counts = await CrmDemoData.seed(CrmLocalRepository());
      final total = counts.values.fold<int>(0, (s, n) => s + n);
      toast.success(message: '已生成 $total 条演示数据');
    } catch (e) {
      toast.error(message: '生成失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportData() async {
    try {
      final data = await CrmBackupCodec.exportAll(CrmLocalRepository());
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出 CRM 数据',
        fileName: 'crm_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (path == null) return;
      await File(path).writeAsString(jsonEncode(data));
      toast.success(message: '已导出：$path');
    } catch (e) {
      toast.error(message: '导出失败：$e');
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入 CRM 数据',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final text = await File(path).readAsString();
      final data = jsonDecode(text) as Map<String, dynamic>;
      await CrmBackupCodec.importAll(CrmLocalRepository(), data);
      toast.success(message: '导入完成');
    } catch (e) {
      toast.error(message: '导入失败：$e');
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('一键清空 CRM 数据'),
        content: const Text(
          '将物理删除全部 CRM 记录（客户/联系人/机会/合同/回款/发票/质保/售后/跟进/提醒/自定义记录等），'
          '自定义对象定义保留。此操作不可撤销，确认继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CrmLocalRepository().clearAllCrm();
      toast.success(message: '已清空全部 CRM 数据');
    } catch (e) {
      toast.error(message: '清空失败：$e');
    }
  }
}
