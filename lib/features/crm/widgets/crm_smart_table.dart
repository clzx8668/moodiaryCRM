import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/crm_field_registry.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:pluto_grid/pluto_grid.dart';

/// 列值类型推断结果
enum CrmColumnKind { text, number, date, boolean }

/// CRM 智能表格（基于 pluto_grid 成熟组件，P2.4 升级版）。
///
/// 特性：单元格直接编辑（防抖保存）、排序、筛选、列宽拖拽、冻结列、
/// 双击行打开详情、自适应窗口宽度（横向滚动 + 自动缩放）。
/// 字段列从实体快照动态发现，保持与 Twenty 对象的动态对应关系。
class CrmSmartTable extends StatefulWidget {
  final List<CrmEntityCache> items;

  /// 展示字段（顺序即列顺序）；字段名与快照 data 键对应
  final List<String> fields;

  /// 选择类字段的选项（字段名 → 选项列表），用于单元格下拉
  final Map<String, List<String>> selectOptions;

  /// 选择类字段的选项显示文本（字段名 → key → 中文 label）；值为 key
  final Map<String, Map<String, String>> selectOptionLabels;

  /// 单元格编辑完成（防抖后回调）；field 为列字段，value 为新值
  final void Function(CrmEntityCache item, String field, Object? value)?
  onCellChanged;

  /// 双击行 / 选中打开详情
  final void Function(CrmEntityCache item)? onOpen;

  /// 拖拽列排序完成（参数为当前可见字段顺序），用于持久化
  final void Function(List<String> fields)? onColumnsReordered;

  /// 行内删除（操作列删除按钮）
  final void Function(CrmEntityCache item)? onDeleteRow;

  /// 批量勾选状态与变更回调（按 item.id）
  final Set<String> selectedIds;
  final ValueChanged<Set<String>>? onSelectionChanged;

  const CrmSmartTable({
    super.key,
    required this.items,
    required this.fields,
    this.selectOptions = const {},
    this.selectOptionLabels = const {},
    this.onCellChanged,
    this.onOpen,
    this.onColumnsReordered,
    this.onDeleteRow,
    this.selectedIds = const {},
    this.onSelectionChanged,
  });

  @override
  State<CrmSmartTable> createState() => _CrmSmartTableState();
}

class _CrmSmartTableState extends State<CrmSmartTable> {
  late List<PlutoColumn> _columns;
  late List<PlutoRow> _rows;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(covariant CrmSmartTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items || oldWidget.fields != widget.fields) {
      _build();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _build() {
    final fields = widget.fields.isEmpty ? const ['name'] : widget.fields;
    _columns = [
      PlutoColumn(
        title: '',
        field: '__select__',
        type: PlutoColumnType.text(),
        width: 44,
        readOnly: true,
        enableEditingMode: false,
        enableSorting: false,
        enableFilterMenuItem: false,
        enableHideColumnMenuItem: false,
        enableSetColumnsMenuItem: false,
        renderer: (rendererContext) {
          final rowIdx = rendererContext.rowIdx;
          if (rowIdx < 0 || rowIdx >= widget.items.length) {
            return const SizedBox.shrink();
          }
          final item = widget.items[rowIdx];
          return Center(
            child: Checkbox(
              value: widget.selectedIds.contains(item.id),
              visualDensity: VisualDensity.compact,
              onChanged: (checked) {
                final next = Set<String>.of(widget.selectedIds);
                if (checked == true) {
                  next.add(item.id);
                } else {
                  next.remove(item.id);
                }
                widget.onSelectionChanged?.call(next);
                // 立即重绘勾选单元格
                rendererContext.stateManager.notifyListeners();
              },
            ),
          );
        },
      ),
      for (final field in fields) _columnFor(field),
      PlutoColumn(
        title: '',
        field: '__actions__',
        type: PlutoColumnType.text(),
        width: 64,
        readOnly: true,
        enableEditingMode: false,
        enableSorting: false,
        enableFilterMenuItem: false,
        enableHideColumnMenuItem: false,
        enableSetColumnsMenuItem: false,
        renderer: (rendererContext) {
          final rowIdx = rendererContext.rowIdx;
          if (rowIdx < 0 || rowIdx >= widget.items.length) {
            return const SizedBox.shrink();
          }
          final item = widget.items[rowIdx];
          return Center(
            child: IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.onDeleteRow?.call(item),
            ),
          );
        },
      ),
    ];
    _rows = [
      for (final item in widget.items)
        PlutoRow(cells: {
          '__select__': PlutoCell(value: ''),
          for (final field in fields)
            field: PlutoCell(value: _cellValue(item, field)),
          '__actions__': PlutoCell(value: ''),
        }),
    ];
  }

  PlutoColumn _columnFor(String field) {
    final mapValued = widget.items.any((i) => i.data[field] is Map);
    final readOnly = field == 'id' || field == 'twentyId' || mapValued;
    final labels = widget.selectOptionLabels[field];
    return PlutoColumn(
      title: _columnTitle(field),
      field: field,
      type: _columnType(field, labels),
      width: _columnWidth(field),
      enableSorting: true,
      enableFilterMenuItem: true,
      enableHideColumnMenuItem: true,
      enableSetColumnsMenuItem: true,
      enableEditingMode: !readOnly,
      readOnly: readOnly,
      frozen:
          field == 'name' || field == 'title'
          ? PlutoColumnFrozen.start
          : PlutoColumnFrozen.none,
    );
  }

  Object? _cellValue(CrmEntityCache item, String field) {
    if (field == 'name') return item.name;
    final labels = widget.selectOptionLabels[field];
    if (labels != null) {
      final raw = item.data[field];
      if (raw is String && labels.containsKey(raw)) return labels[raw];
    }
    return CrmFieldRegistry.formatValue(item.data[field]);
  }

  CrmColumnKind _inferKind(String field, Iterable<CrmEntityCache> items) {
    final low = field.toLowerCase();
    if (low.contains('date') ||
        low.contains('at') ||
        low.contains('time') ||
        low.endsWith('at')) {
      return CrmColumnKind.date;
    }
    for (final item in items) {
      final value = _cellValue(item, field);
      if (value is bool) return CrmColumnKind.boolean;
      if (value is num) return CrmColumnKind.number;
      if (value is String && value.isNotEmpty) {
        if (double.tryParse(value) != null) return CrmColumnKind.number;
        if (DateTime.tryParse(value) != null) return CrmColumnKind.date;
      }
    }
    return CrmColumnKind.text;
  }

  PlutoColumnType _columnType(String field, Map<String, String>? labels) {
    final options = widget.selectOptions[field];
    if (options != null && options.isNotEmpty) {
      return PlutoColumnType.select([
        for (final option in options) labels?[option] ?? option,
      ]);
    }
    switch (_inferKind(field, widget.items)) {
      case CrmColumnKind.number:
        return PlutoColumnType.number(
          format: '#,##0.##',
          negative: true,
          applyFormatOnInit: false,
        );
      case CrmColumnKind.boolean:
        return PlutoColumnType.select(<String>['true', 'false']);
      case CrmColumnKind.date:
      case CrmColumnKind.text:
        return PlutoColumnType.text();
    }
  }

  double _columnWidth(String field) {
    switch (field) {
      case 'name':
      case 'title':
      case 'contractName':
        return 220;
      case 'id':
      case 'twentyId':
        return 120;
      default:
        return 140;
    }
  }

  String _columnTitle(String field) {
    const labels = {
      'name': '名称',
      'title': '标题',
      'contractName': '合同名称',
      'amount': '金额',
      'status': '状态',
      'dueAt': '到期时间',
      'createdAt': '创建时间',
      'updatedAt': '更新时间',
      'phone': '电话',
      'email': '邮箱',
      'address': '地址',
      'company': '客户',
      'person': '联系人',
      'opportunity': '商机',
      'description': '描述',
      'note': '备注',
    };
    if (labels.containsKey(field)) return labels[field]!;
    final parts = field.split(RegExp(r'(?=[A-Z])'));
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return PlutoGrid(
      columns: _columns,
      rows: _rows,
      mode: PlutoGridMode.normal,
      configuration: PlutoGridConfiguration(
        localeText: const PlutoGridLocaleText(
          unfreezeColumn: '取消冻结',
          freezeColumnToStart: '冻结到开头',
          freezeColumnToEnd: '冻结到末尾',
          autoFitColumn: '自动适配',
          hideColumn: '隐藏列',
          setColumns: '设置列',
          setFilter: '设置筛选',
          resetFilter: '重置筛选',
          setColumnsTitle: '列标题',
          filterColumn: '列',
          filterType: '类型',
          filterValue: '值',
          filterAllColumns: '全部列',
          filterContains: '包含',
          filterEquals: '等于',
          filterStartsWith: '开头是',
          filterEndsWith: '结尾是',
          filterGreaterThan: '大于',
          filterGreaterThanOrEqualTo: '大于等于',
          filterLessThan: '小于',
          filterLessThanOrEqualTo: '小于等于',
          sunday: '日',
          monday: '一',
          tuesday: '二',
          wednesday: '三',
          thursday: '四',
          friday: '五',
          saturday: '六',
          hour: '小时',
          minute: '分钟',
          loadingText: '加载中',
        ),
        style: PlutoGridStyleConfig(
          rowHeight: 38,
          columnHeight: 40,
          columnTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          cellTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
          ),
          gridBackgroundColor: Theme.of(context).colorScheme.surface,
          rowColor: Theme.of(context).colorScheme.surface,
          activatedColor: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.35),
          gridBorderColor: Theme.of(context).colorScheme.outlineVariant,
          borderColor: Theme.of(context).colorScheme.outlineVariant,
          iconColor: Theme.of(context).colorScheme.outline,
          enableGridBorderShadow: false,
        ),
        columnSize: const PlutoGridColumnSizeConfig(
          autoSizeMode: PlutoAutoSizeMode.scale,
          resizeMode: PlutoResizeMode.normal,
        ),
      ),
      onLoaded: (event) {
        event.stateManager.setShowColumnFilter(false);
      },
      onChanged: (event) {
        if (event.column.field == 'id' || event.column.field == 'twentyId') {
          return;
        }
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 600), () {
          final rowIdx = event.rowIdx;
          if (rowIdx < 0 || rowIdx >= widget.items.length) return;
          final item = widget.items[rowIdx];
          var value = event.value;
          // select 列下拉显示中文 label，编辑后反查回英文 key 再落库
          final labels = widget.selectOptionLabels[event.column.field];
          if (labels != null && value is String) {
            for (final entry in labels.entries) {
              if (entry.value == value) {
                value = entry.key;
                break;
              }
            }
          }
          widget.onCellChanged?.call(item, event.column.field, value);
        });
      },
      onRowDoubleTap: (event) {
        final rowIdx = event.rowIdx;
        if (rowIdx < 0 || rowIdx >= widget.items.length) return;
        widget.onOpen?.call(widget.items[rowIdx]);
      },
      onColumnsMoved: (event) {
        widget.onColumnsReordered?.call([
          for (final column in event.columns) column.field,
        ]);
      },
    );
  }
}
