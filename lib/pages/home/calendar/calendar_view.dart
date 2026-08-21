import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/diary_card/calendar_diary_card_view.dart';
import 'package:moodiary/components/time_line/time_line_view.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'calendar_logic.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  Widget _buildActiveInfo({
    required Color lessColor,
    required Color moreColor,
    required TextStyle? textStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        spacing: 2.0,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('少', style: textStyle),
          ...List.generate(5, (index) {
            return Container(
              width: 12.0,
              height: 12.0,
              decoration: BoxDecoration(
                color: Color.lerp(lessColor, moreColor, (index + 1) / 5),
                borderRadius: BorderRadius.circular(4.0),
              ),
            );
          }),
          Text('多', style: textStyle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(CalendarLogic());
    final state = Bind.find<CalendarLogic>().state;

    final size = MediaQuery.sizeOf(context);

    //生成日历选择器
    Widget buildDatePicker() {
      final dateWithDiaryList = <DateTime>[];
      final allDate = <DateTime>[];
      // 获取有日记的日期，只需要年月日
      for (final diary in state.currentMonthDiaryList) {
        // 如果不存在当前日期，则添加
        final time = diary.time;
        allDate.add(DateTime(time.year, time.month, time.day));
        if (!dateWithDiaryList.contains(
          DateTime(time.year, time.month, time.day),
        )) {
          dateWithDiaryList.add(DateTime(time.year, time.month, time.day));
        }
      }
      return Stack(
        children: [
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Obx(() {
              return CalendarDatePicker2(
                displayedMonthDate: state.currentMonth.value,
                config: CalendarDatePicker2Config(
                  calendarViewMode: CalendarDatePicker2Mode.day,
                  calendarType: CalendarDatePicker2Type.single,
                  hideMonthPickerDividers: true,
                  hideYearPickerDividers: true,
                  useAbbrLabelForMonthModePicker: true,
                  allowSameValueSelection: true,
                  dayBuilder: ({
                    required DateTime date,
                    TextStyle? textStyle,
                    BoxDecoration? decoration,
                    bool? isSelected,
                    bool? isDisabled,
                    bool? isToday,
                  }) {
                    final contains = dateWithDiaryList.contains(date);
                    final activity = state.dailyActivity[date] ?? 0.0;
                    final bgColor =
                        contains
                            ? Color.lerp(
                              context.theme.colorScheme.surfaceContainer,
                              context.theme.colorScheme.primary,
                              activity,
                            )
                            : null;
                    return Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgColor,
                        ),
                        child: Center(
                          child: Text(
                            date.day.toString(),
                            style: textStyle?.copyWith(
                              color:
                                  contains
                                      ? ThemeData.estimateBrightnessForColor(
                                                bgColor!,
                                              ) ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black
                                      : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  selectableDayPredicate: (DateTime date) {
                    return dateWithDiaryList.contains(date);
                  },
                ),
                onValueChanged: (value) {
                  logic.animateToSelectedDateWithLock(value.first);
                },
                onDisplayedMonthChanged: (value) async {
                  final lastDate = logic.findLatestDateInMonth(
                    dateWithDiaryList,
                    value.year,
                    value.month,
                  );
                  if (lastDate != null) {
                    await logic.animateToSelectedDateWithLock(lastDate);
                  }
                },
                value: const [],
              );
            }),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: _buildActiveInfo(
              lessColor: context.theme.colorScheme.surfaceContainer,
              moreColor: context.theme.colorScheme.primary,
              textStyle: context.textTheme.labelSmall?.copyWith(
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget buildCardList() {
      return Obx(() {
        final items = state.timelineItems;
        return ScrollablePositionedList.builder(
          itemBuilder: (context, index) {
            final item = items[index];
            final Widget child;
            final Color actionColor;
            if (item.isDiary) {
              actionColor =
                  Color.lerp(
                    AppColor.emoColorList.first,
                    AppColor.emoColorList.last,
                    item.diary!.mood,
                  )!;
              child = CalendarDiaryCardComponent(diary: item.diary!);
            } else {
              actionColor = _crmColor(item.crm!.entityType);
              child = _CrmTimelineCard(crm: item.crm!);
            }
            return TimeLineComponent(
              actionColor: actionColor,
              child: Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? 0 : 4.0,
                  bottom:
                      index == items.length - 1 ? 0 : 4.0,
                ),
                child: child,
              ),
            );
          },
          itemScrollController: logic.itemScrollController,
          itemPositionsListener: logic.itemPositionsListener,
          scrollOffsetController: logic.scrollOffsetController,
          scrollOffsetListener: logic.scrollOffsetListener,
          itemCount: items.length,
        );
      });
    }

    // 跨源待办列表（P2.2）
    Widget buildTodoList() {
      return Obx(() {
        if (state.isFetchingTodos.value) {
          return const Center(child: MoodiaryLoading());
        }
        final items = state.todoItems;
        if (items.isEmpty) {
          return Center(
            key: const ValueKey('todo-empty'),
            child: FaIcon(
              FontAwesomeIcons.listCheck,
              color: context.theme.colorScheme.onSurface,
              size: 56,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          itemBuilder: (context, index) => _TodoCard(
            item: items[index],
            onToggle: () async {
              if (!items[index].isLocal) return;
              await logic.toggleTodo(items[index]);
            },
            onTap: () => _openTodo(context, items[index]),
          ),
        );
      });
    }

    Widget buildModeHeader() {
      return Obx(() {
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('时间轴'),
                    icon: Icon(Icons.timeline_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('待办'),
                    icon: Icon(Icons.task_alt_rounded, size: 16),
                  ),
                ],
                selected: {state.showTodos.value},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelectionChanged: (selection) {
                  state.showTodos.value = selection.first;
                },
              ),
              const Spacer(),
              if (state.showTodos.value)
                IconButton.filledTonal(
                  onPressed: () => _showQuickAddTodo(context, logic),
                  icon: const Icon(Icons.playlist_add_rounded, size: 20),
                  tooltip: '快捷待办',
                ),
            ],
          ),
        );
      });
    }

    Widget buildContent() {
      return Obx(() {
        if (state.showTodos.value) return buildTodoList();
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child:
              state.isFetching.value
                  ? const MoodiaryLoading()
                  : (state.timelineItems.isNotEmpty
                      ? buildCardList()
                      : Center(
                        key: const ValueKey('empty'),
                        child: FaIcon(
                          FontAwesomeIcons.boxOpen,
                          color: context.theme.colorScheme.onSurface,
                          size: 56,
                        ),
                      )),
        );
      });
    }

    final calendar = Obx(() {
      return buildDatePicker();
    });

    final diaryBody = ClipRRect(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      child: Column(
        children: [buildModeHeader(), Expanded(child: buildContent())],
      ),
    );

    return GetBuilder<CalendarLogic>(
      assignId: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: SafeArea(
            child:
                size.width > 600
                    ? Row(
                      spacing: 8.0,
                      children: [
                        Expanded(child: diaryBody),
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(width: 320, child: calendar),
                        ),
                      ],
                    )
                    : Column(
                      spacing: 8.0,
                      children: [calendar, Expanded(child: diaryBody)],
                    ),
          ),
        );
      },
    );
  }

  // 打开待办：本地跳日记详情，CRM 显示快照
  Future<void> _openTodo(BuildContext context, TodoItem item) async {
    if (item.isLocal) {
      final diary = await IsarUtil.getDiaryById(item.diaryId);
      if (!context.mounted) return;
      if (diary == null) {
        toast.info(message: '关联日记不存在');
        return;
      }
      Get.toNamed(AppRoutes.diaryPage, arguments: [diary, true]);
      return;
    }
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Text(
          '来源：Twenty 任务\n'
          'Twenty ID：${item.twentyId}\n'
          '状态：${item.done ? '已完成' : '未完成'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 快捷新建待办（3 步：入口 → 输入/选到期日 → 保存）
  Future<void> _showQuickAddTodo(
    BuildContext context,
    CalendarLogic logic,
  ) async {
    final text = TextEditingController();
    DateTime? dueDate;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('快捷待办', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '待办内容 *',
                  hintText: '例如：下周三寄出样品',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _saveQuickTodo(
                  sheetContext,
                  logic,
                  text,
                  dueDate,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setSheetState(() => dueDate = picked);
                    }
                  },
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    dueDate == null
                        ? '选择到期日（可选）'
                        : _fmtDate(dueDate!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _saveQuickTodo(
                  sheetContext,
                  logic,
                  text,
                  dueDate,
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuickTodo(
    BuildContext sheetContext,
    CalendarLogic logic,
    TextEditingController text,
    DateTime? dueDate,
  ) async {
    final content = text.text.trim();
    if (content.isEmpty) {
      toast.info(message: '请输入待办内容');
      return;
    }
    try {
      await logic.quickAddTodo(content, dueDate);
      toast.success(message: '待办已创建');
      if (sheetContext.mounted) Navigator.pop(sheetContext);
    } catch (e) {
      toast.error(message: '创建失败：$e');
    }
  }

}

class _TodoCard extends StatelessWidget {
  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TodoCard({
    required this.item,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: ListTile(
        dense: true,
        leading: item.isLocal
            ? Checkbox(
                value: item.done,
                onChanged: (_) => onToggle(),
              )
            : Icon(
                item.done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: item.done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
        title: Text(
          item.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: item.done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Text(
          '${item.dueDate != null ? '${_fmtDate(item.dueDate!)} · ' : ''}'
          '${item.isLocal ? '日记待办' : item.title}',
          style: theme.textTheme.labelSmall,
        ),
        trailing: Icon(
          item.isLocal ? Icons.article_outlined : Icons.cloud_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _CrmTimelineCard extends StatelessWidget {
  final CrmEntityCache crm;

  const _CrmTimelineCard({required this.crm});

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          _crmIcon(crm.entityType),
          color: _crmColor(crm.entityType),
        ),
        title: Text(
          crm.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_typeLabel(crm.entityType)} · ${crm.twentyId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${crm.updatedAt.year}-'
          '${crm.updatedAt.month.toString().padLeft(2, '0')}-'
          '${crm.updatedAt.day.toString().padLeft(2, '0')}',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

Color _crmColor(String type) {
  switch (type) {
    case 'company':
      return Colors.blue.shade300;
    case 'person':
      return Colors.green.shade300;
    case 'opportunity':
      return Colors.orange.shade300;
    case 'task':
      return Colors.purple.shade300;
    case 'contractsHeTongGuanLi':
      return Colors.teal.shade300;
    case 'paymentsHuiKuanJiLu':
      return Colors.red.shade300;
    case 'invoiceFaPiao':
      return Colors.indigo.shade300;
    case 'commissionsTiChengJieSuan':
      return Colors.pink.shade300;
    default:
      return Colors.grey.shade400;
  }
}

IconData _crmIcon(String type) {
  switch (type) {
    case 'company':
      return Icons.business_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'opportunity':
      return Icons.trending_up_rounded;
    case 'task':
      return Icons.task_alt_rounded;
    case 'contractsHeTongGuanLi':
      return Icons.description_rounded;
    case 'paymentsHuiKuanJiLu':
      return Icons.payments_rounded;
    case 'invoiceFaPiao':
      return Icons.receipt_rounded;
    case 'commissionsTiChengJieSuan':
      return Icons.savings_rounded;
    default:
      return Icons.folder_rounded;
  }
}

String _typeLabel(String type) {
  const labels = {
    'company': '客户',
    'person': '联系人',
    'opportunity': '商机',
    'task': '任务',
    'contractsHeTongGuanLi': '合同',
    'paymentsHuiKuanJiLu': '回款',
    'invoiceFaPiao': '发票',
    'commissionsTiChengJieSuan': '提成',
  };
  return labels[type] ?? type;
}
