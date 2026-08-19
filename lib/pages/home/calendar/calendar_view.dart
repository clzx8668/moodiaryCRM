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

    final calendar = Obx(() {
      return buildDatePicker();
    });

    final diaryBody = ClipRRect(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      child: Obx(() {
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
      }),
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

}

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
