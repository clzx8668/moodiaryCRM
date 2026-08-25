import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  /// 列标题（字段名 → 显示名）；缺省回退到内置推断（不同表同名字段可区分）
  final Map<String, String> columnTitles;

  /// 单元格编辑完成（防抖后回调）；field 为列字段，value 为新值
  final void Function(CrmEntityCache item, String field, Object? value)?
  onCellChanged;

  /// 双击行 / 选中打开详情
  final void Function(CrmEntityCache item)? onOpen;

  /// 拖拽列排序完成（参数为当前可见字段顺序），用于持久化
  final void Function(List<String> fields)? onColumnsReordered;

  /// 各列当前宽度（字段名 → 像素），用于跨会话记忆列宽
  final Map<String, double> columnWidths;

  /// 列宽调整后回调（字段名 → 像素），由外层持久化
  final void Function(Map<String, double> widths)? onColumnWidthsChanged;

  /// 行内删除（操作列删除按钮）
  final void Function(CrmEntityCache item)? onDeleteRow;

  /// 批量勾选状态与变更回调（按 item.id）
  final Set<String> selectedIds;
  final ValueChanged<Set<String>>? onSelectionChanged;

  /// 关系字段名集合（点击单元格弹出原位搜索式关联编辑）
  final Set<String> relationFields;

  /// 第一列（复选框列）是否冻结（默认冻结，表头全选方框跟随）
  final bool freezeFirstColumn;

  const CrmSmartTable({
    super.key,
    required this.items,
    required this.fields,
    this.selectOptions = const {},
    this.selectOptionLabels = const {},
    this.columnTitles = const {},
    this.onCellChanged,
    this.onOpen,
    this.onColumnsReordered,
    this.columnWidths = const {},
    this.onColumnWidthsChanged,
    this.onDeleteRow,
    this.selectedIds = const {},
    this.onSelectionChanged,
    this.relationFields = const {},
    this.freezeFirstColumn = true,
  });

  @override
  State<CrmSmartTable> createState() => _CrmSmartTableState();
}

class _CrmSmartTableState extends State<CrmSmartTable> {
  late List<PlutoColumn> _columns;
  late List<PlutoRow> _rows;
  Timer? _debounce;
  Timer? _resizeDebounce;
  PlutoGridStateManager? _stateManager;
  Offset? _rightClickDown;

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
    // 外部选中集变化 → 同步行勾选（编程 setRowChecked 不触发 onRowChecked，无循环）
    if (oldWidget.selectedIds != widget.selectedIds) {
      _syncCheckedRows();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _resizeDebounce?.cancel();
    _stateManager?.resizingChangeNotifier.removeListener(_onColumnResized);
    super.dispose();
  }

  void _build() {
    final fields = widget.fields.isEmpty ? const ['name'] : widget.fields;
    _columns = [
      for (var i = 0; i < fields.length; i++)
        _columnFor(
          fields[i],
          isFirst: i == 0,
          firstColumnFrozen: widget.freezeFirstColumn,
        ),
      PlutoColumn(
        title: '',
        field: '__actions__',
        type: PlutoColumnType.text(),
        width: 64,
      readOnly: true,
      enableEditingMode: false,
      enableSorting: false,
      enableContextMenu: false,
      enableDropToResize: false,
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
          for (final field in fields)
            field: PlutoCell(value: _cellValue(item, field)),
          '__actions__': PlutoCell(value: ''),
        }),
    ];
  }

  PlutoColumn _columnFor(
    String field, {
    required bool isFirst,
    required bool firstColumnFrozen,
  }) {
    final mapValued = widget.items.any((i) => i.data[field] is Map);
    final readOnly = field == 'id' || field == 'twentyId' || mapValued;
    final labels = widget.selectOptionLabels[field];
    final isRelation = widget.relationFields.contains(field);
    final kind = _inferKind(field, widget.items);
    // Twenty 风格：数字/金额右对齐、布尔居中、文本左对齐
    final align = switch (kind) {
      CrmColumnKind.number => PlutoColumnTextAlign.end,
      CrmColumnKind.boolean => PlutoColumnTextAlign.center,
      _ => PlutoColumnTextAlign.start,
    };
    // 首列（复选框融合列）保持足够宽度且不参与 scale 自动缩放，
    // 避免窄容器下复选框挤占内容（报价/发票等短首列表现尤其明显）
    final savedWidth = widget.columnWidths[field];
    final columnWidth = isFirst
        ? (savedWidth ?? 200.0) < 180
              ? 180.0
              : (savedWidth ?? 200.0)
        : savedWidth ?? _columnWidth(field);
    return PlutoColumn(
      title: widget.columnTitles[field] ?? _columnTitle(field),
      field: field,
      type: _columnType(field, labels),
      width: columnWidth,
      suppressedAutoSize: isFirst,
      textAlign: align,
      titleTextAlign: align,
      // 复选框与首列融合（pluto 原生 enableRowChecked：表头全选 + 行内勾选）
      enableRowChecked: isFirst,
      renderer: isRelation
          ? (rendererContext) {
              final rowIdx = rendererContext.rowIdx;
              if (rowIdx < 0 || rowIdx >= widget.items.length) {
                return const SizedBox.shrink();
              }
              final item = widget.items[rowIdx];
              final text = CrmFieldRegistry.formatValue(item.data[field]);
              return GestureDetector(
                onTap: () => widget.onOpen?.call(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text.isEmpty ? '—' : text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          : kind == CrmColumnKind.text &&
                widget.selectOptions[field] == null &&
                labels == null
          ? (rendererContext) {
              final rowIdx = rendererContext.rowIdx;
              if (rowIdx < 0 || rowIdx >= widget.items.length) {
                return const SizedBox.shrink();
              }
              final text = _cellValue(widget.items[rowIdx], field)?.toString() ?? '';
              return Tooltip(
                message: text,
                waitDuration: const Duration(milliseconds: 600),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    text.isEmpty ? '—' : text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              );
            }
          : null,
      // 排序箭头隐藏，升降序移入标题行右键/菜单（_CrmColumnMenuDelegate）
      enableSorting: false,
      // 隐藏列标题右侧「三条杠」菜单/调整图标；列操作全部走右键菜单
      enableContextMenu: false,
      enableDropToResize: false,
      enableFilterMenuItem: true,
      enableHideColumnMenuItem: true,
      enableSetColumnsMenuItem: true,
      enableEditingMode: !readOnly,
      readOnly: readOnly,
      // 默认仅冻结首列（复选框融合其中）；关闭开关后由列菜单自定义冻结
      frozen: isFirst && firstColumnFrozen
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
    final grid = PlutoGrid(
      columns: _columns,
      rows: _rows,
      mode: PlutoGridMode.normal,
      columnMenuDelegate: _CrmColumnMenuDelegate(),
      // 当前行轻微高亮（Twenty 当前行样式）
      rowColorCallback: (ctx) {
        if (ctx.rowIdx == _stateManager?.currentRowIdx) {
          return Theme.of(
            this.context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.10);
        }
        return Theme.of(this.context).colorScheme.surface;
      },
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
        _stateManager?.resizingChangeNotifier.removeListener(_onColumnResized);
        _stateManager = event.stateManager;
        _stateManager?.resizingChangeNotifier.addListener(_onColumnResized);
        event.stateManager.setShowColumnFilter(false);
        _syncCheckedRows();
      },
      onRowChecked: (event) {
        final next = Set<String>.of(widget.selectedIds);
        if (event.isAll) {
          if (event.isChecked == true) {
            next.addAll([for (final item in widget.items) item.id]);
          } else {
            next.clear();
          }
        } else if (event.rowIdx != null && event.rowIdx! < widget.items.length) {
          final id = widget.items[event.rowIdx!].id;
          if (event.isChecked == true) {
            next.add(id);
          } else {
            next.remove(id);
          }
        }
        widget.onSelectionChanged?.call(next);
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
          for (final column in event.columns)
            if (column.field != '__actions__') column.field,
        ]);
      },
    );
    return Listener(
      onPointerDown: _handleRightPointerDown,
      onPointerUp: _handleRightPointerUp,
      child: grid,
    );
  }

  /// 列宽调整后（防抖）上报，供外层持久化跨会话记忆。
  void _onColumnResized() {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 400), () {
      final sm = _stateManager;
      if (sm == null || !mounted) return;
      final widths = <String, double>{};
      for (final column in sm.refColumns) {
        if (column.field == '__actions__') continue;
        widths[column.field] = column.width;
      }
      widget.onColumnWidthsChanged?.call(widths);
    });
  }

  /// 将外部 [widget.selectedIds] 同步到网格行勾选状态（首列融合复选框）。
  void _syncCheckedRows() {
    final sm = _stateManager;
    if (sm == null) return;
    final limit = sm.refRows.length < widget.items.length
        ? sm.refRows.length
        : widget.items.length;
    for (var i = 0; i < limit; i++) {
      final checked = widget.selectedIds.contains(widget.items[i].id);
      if (sm.refRows[i].checked != checked) {
        sm.setRowChecked(sm.refRows[i], checked);
      }
    }
  }

  void _handleRightPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kSecondaryMouseButton) != 0) {
      _rightClickDown = event.localPosition;
    }
  }

  void _handleRightPointerUp(PointerUpEvent event) {
    final down = _rightClickDown;
    _rightClickDown = null;
    final sm = _stateManager;
    if (down == null || sm == null || !mounted) return;
    final pos = down;
    // 仅标题行区域响应右键
    if (pos.dy < 0 || pos.dy > sm.columnHeight) return;
    final hit = _columnAtPosition(pos);
    if (hit == null) return;
    final column = hit.column;
    if (column.field == '__actions__') return;
    _openColumnMenu(pos, column);
  }

  ({PlutoColumn column, double rightEdge})? _columnAtPosition(Offset local) {
    final sm = _stateManager;
    if (sm == null) return null;
    final x = local.dx;
    double cursor = 0;
    for (final c in sm.leftFrozenColumns) {
      cursor += c.width;
      if (x < cursor) return (column: c, rightEdge: cursor);
    }
    final offset = sm.scroll.horizontalOffset;
    var bodyX = sm.leftFrozenColumnsWidth - offset;
    for (final c in sm.bodyColumns) {
      bodyX += c.width;
      if (x < bodyX) return (column: c, rightEdge: bodyX);
    }
    return null;
  }

  Future<void> _openColumnMenu(Offset localPos, PlutoColumn column) async {
    final sm = _stateManager;
    if (sm == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final global = box.localToGlobal(localPos);
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        global.dx,
        global.dy,
        overlayBox.size.width - global.dx,
        overlayBox.size.height - global.dy,
      ),
      items: _CrmColumnMenuDelegate().buildMenuItems(
        stateManager: sm,
        column: column,
      ),
    );
    if (selected != null && mounted) {
      _CrmColumnMenuDelegate().onSelected(
        context: context,
        stateManager: sm,
        column: column,
        mounted: mounted,
        selected: selected,
      );
    }
  }
}

/// 列标题菜单委托：升序/降序移入菜单（Twenty 无表头排序箭头，
/// 排序通过列菜单触发），并保留冻结/隐藏/筛选等默认项。
class _CrmColumnMenuDelegate extends PlutoColumnMenuDelegate<String> {
  _CrmColumnMenuDelegate();

  @override
  List<PopupMenuEntry<String>> buildMenuItems({
    required PlutoGridStateManager stateManager,
    required PlutoColumn column,
  }) {
    final textColor =
        stateManager.style.cellTextStyle.color ?? Colors.black87;
    final locale = stateManager.localeText;
    PopupMenuItem<String> item(String value, String text) => PopupMenuItem(
      value: value,
      height: 36,
      child: Text(text, style: TextStyle(color: textColor, fontSize: 13)),
    );
    return [
      item('sortAsc', '升序'),
      item('sortDesc', '降序'),
      const PopupMenuDivider(),
      if (column.frozen.isFrozen)
        item('unfreeze', locale.unfreezeColumn)
      else ...[
        item('freezeStart', locale.freezeColumnToStart),
        item('freezeToEnd', locale.freezeColumnToEnd),
      ],
      item('autoFit', locale.autoFitColumn),
      if (column.enableHideColumnMenuItem) item('hide', locale.hideColumn),
      if (column.enableSetColumnsMenuItem)
        item('setColumns', locale.setColumns),
      if (column.enableFilterMenuItem) ...[
        const PopupMenuDivider(),
        item('setFilter', locale.setFilter),
        item('resetFilter', locale.resetFilter),
      ],
    ];
  }

  @override
  void onSelected({
    required BuildContext context,
    required PlutoGridStateManager stateManager,
    required PlutoColumn column,
    required bool mounted,
    required String? selected,
  }) {
    switch (selected) {
      case 'sortAsc':
        stateManager.sortAscending(column);
        break;
      case 'sortDesc':
        stateManager.sortDescending(column);
        break;
      case 'unfreeze':
        stateManager.toggleFrozenColumn(column, PlutoColumnFrozen.none);
        break;
      case 'freezeStart':
        stateManager.toggleFrozenColumn(column, PlutoColumnFrozen.start);
        break;
      case 'freezeToEnd':
        stateManager.toggleFrozenColumn(column, PlutoColumnFrozen.end);
        break;
      case 'autoFit':
        if (mounted) stateManager.autoFitColumn(context, column);
        break;
      case 'hide':
        stateManager.hideColumn(column, true);
        break;
      case 'setColumns':
        if (mounted) stateManager.showSetColumnsPopup(context);
        break;
      case 'setFilter':
        if (mounted) {
          stateManager.showFilterPopup(context, calledColumn: column);
        }
        break;
      case 'resetFilter':
        stateManager.setFilter(null);
        break;
    }
  }
}
