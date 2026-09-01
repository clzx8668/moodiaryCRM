import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/utils/notice_util.dart';

import '../models/schedule.dart';
import '../schedule_repository.dart';

/// 日程/待办详情页（兼新建与编辑，参考指尖时光样式）。
///
/// 传入 [editable] 表示编辑已有日程；否则新建。保存成功以 `true` 返回，
/// 由调用方刷新日历。
class ScheduleDetailPage extends StatefulWidget {
  final Schedule? editable;
  final DateTime? initialStart;

  const ScheduleDetailPage({super.key, this.editable, this.initialStart});

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  late final Schedule _schedule;
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late final ScheduleRepository _repo;

  // 背景色色板
  static const List<int> _palette = [
    0xFFF57C00, // 橙
    0xFFE53935, // 红
    0xFF43A047, // 绿
    0xFF1E88E5, // 蓝
    0xFF8E24AA, // 紫
    0xFF00897B, // 青
    0xFF6D4C41, // 棕
    0xFF90A4AE, // 灰
  ];

  @override
  void initState() {
    super.initState();
    _repo = ScheduleRepository();
    final base = widget.editable?.clone() ?? Schedule();
    if (widget.editable == null && widget.initialStart != null) {
      base.startTime = widget.initialStart!;
    }
    _schedule = base;
    _titleCtrl.text = _schedule.title;
    _notesCtrl.text = _schedule.notes;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _schedule.startTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_schedule.startTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _schedule.startTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      // 结束时间默认 +1 小时
      _schedule.endTime ??= _schedule.startTime.add(const Duration(hours: 1));
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      toast.info(message: '请输入标题');
      return;
    }
    _schedule
      ..title = title
      ..notes = _notesCtrl.text;
    try {
      if (widget.editable == null) {
        await _repo.create(_schedule);
      } else {
        await _repo.update(_schedule);
      }
      if (!mounted) return;
      Get.back(result: true);
    } catch (e) {
      toast.error(message: '保存失败：$e');
    }
  }

  Future<void> _delete() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除日程'),
        content: const Text('确定删除这个日程吗？'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _repo.softDelete(_schedule.id);
    if (mounted) Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back(),
        ),
        title: Text(widget.editable == null ? '新建日程' : '编辑日程'),
        actions: [
          if (widget.editable != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
              tooltip: '删除',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _titleCard(theme),
          const SizedBox(height: 12),
          _scheduleCard(theme),
          const SizedBox(height: 12),
          _repeatCard(theme),
          const SizedBox(height: 12),
          _remindCard(theme),
          const SizedBox(height: 12),
          _subtaskCard(theme),
          const SizedBox(height: 12),
          _notesCard(theme),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF57C00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleCard(ThemeData theme) {
    return Card.filled(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _circleCheck(theme),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    autofocus: widget.editable == null,
                    style: theme.textTheme.titleMedium,
                    decoration: const InputDecoration(
                      hintText: '待办 / 日程标题',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipDropdown(
                    '无标签',
                    const Icon(Icons.label_outline_rounded, size: 14),
                    onTap: () => _pickTag(theme),
                  ),
                  const SizedBox(width: 8),
                  _chipDropdown(
                    '优先级 ▾',
                    Icon(
                      Icons.flag_outlined,
                      size: 14,
                      color: _priorityColor(_schedule.priority),
                    ),
                    onTap: () => _pickPriority(theme),
                  ),
                  const SizedBox(width: 8),
                  _chipDropdown(
                    '背景色 ▾',
                    const Icon(Icons.palette_outlined, size: 14),
                    onTap: () => _pickColor(theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleCheck(ThemeData theme) {
    final accent = _schedule.bgColor == null
        ? const Color(0xFFF57C00)
        : Color(_schedule.bgColor!);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => setState(() => _schedule.done = !_schedule.done),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _schedule.done ? accent : Colors.transparent,
          border: Border.all(color: theme.colorScheme.outline, width: 2),
        ),
        child: _schedule.done
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _chipDropdown(
    String label,
    Widget icon, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }

  Widget _scheduleCard(ThemeData theme) {
    final allDay = _schedule.allDay;
    return Card.filled(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_rounded),
            title: const Text('待办日程'),
            subtitle: Text(
              _fmtStart(_schedule.startTime, allDay: allDay),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: allDay ? null : _pickStart,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('全天'),
            value: allDay,
            onChanged: (v) => setState(() => _schedule.allDay = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.inbox_outlined),
            title: const Text('无固定日期（浮动收件箱）'),
            subtitle: const Text('只在"今日"待办聚合，不随具体日期出现'),
            value: _schedule.floating,
            onChanged: (v) => setState(() => _schedule.floating = v),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('结束时间'),
            subtitle: Text(
              _schedule.endTime == null
                  ? '未设置'
                  : _fmtTime(_schedule.endTime!),
            ),
            enabled: !allDay,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: allDay ? null : _pickEnd,
          ),
        ],
      ),
    );
  }

  Future<void> _pickEnd() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_schedule.endTime ?? _schedule.startTime),
    );
    if (time == null || !mounted) return;
    final base = _schedule.endTime ?? _schedule.startTime;
    setState(() {
      _schedule.endTime = DateTime(
        base.year,
        base.month,
        base.day,
        time.hour,
        time.minute,
      );
    });
  }

  Widget _repeatCard(ThemeData theme) {
    return Card.filled(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: const Icon(Icons.repeat_rounded),
        title: const Text('重复'),
        subtitle: Text(_schedule.repeatType.label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _pickRepeat(theme),
      ),
    );
  }

  Widget _remindCard(ThemeData theme) {
    return Card.filled(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: const Icon(Icons.alarm_rounded),
        title: const Text('提醒'),
        subtitle: Text(
          _schedule.remindOffsetMin == null
              ? '不提醒'
              : _remindLabel(_schedule.remindOffsetMin!),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _pickRemind(theme),
      ),
    );
  }

  Widget _subtaskCard(ThemeData theme) {
    return Card.filled(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('子任务'),
                ],
              ),
            ),
            for (var i = 0; i < _schedule.subtasks.length; i++)
              _subtaskRow(theme, i),
            InkWell(
              onTap: _addSubtask,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('添加子任务'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subtaskRow(ThemeData theme, int index) {
    final sub = _schedule.subtasks[index];
    return Dismissible(
      key: ValueKey('subtask-$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => setState(() => _schedule.subtasks.removeAt(index)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: sub.done,
              onChanged: (v) => setState(() => sub.done = v ?? false),
            ),
            Expanded(
              child: Text(
                sub.text,
                style: sub.done
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: () => setState(() => _schedule.subtasks.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notesCard(ThemeData theme) {
    return Card.filled(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: _notesCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '输入备忘',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Future<void> _addSubtask() async {
    final ctrl = TextEditingController();
    final text = await Get.dialog<String>(
      AlertDialog(
        title: const Text('添加子任务'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '子任务内容'),
          onSubmitted: (v) => Get.back(result: v),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          FilledButton(
            onPressed: () => Get.back(result: ctrl.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty && mounted) {
      setState(() => _schedule.subtasks.add(ScheduleSubtask(text: text)));
    }
  }

  Future<void> _pickTag(ThemeData theme) async {
    final preset = ['工作', '生活', '学习', '健康', '其他'];
    final tag = await _pickDropdown<String>(
      title: '标签',
      options: preset,
      label: (t) => t,
    );
    if (tag != null) setState(() => _schedule.tag = tag);
  }

  Future<void> _pickPriority(ThemeData theme) async {
    final value = await _pickDropdown<SchedulePriority>(
      title: '优先级',
      options: SchedulePriority.values,
      label: (p) => p.label,
      selected: _schedule.priority,
    );
    if (value != null) setState(() => _schedule.priority = value);
  }

  Future<void> _pickColor(ThemeData theme) async {
    final choice = await Get.dialog<int>(
      Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _colorDot(null, theme),
              for (final c in _palette) _colorDot(c, theme),
            ],
          ),
        ),
      ),
    );
    if (choice != null) setState(() => _schedule.bgColor = choice == -1 ? null : choice);
  }

  Widget _colorDot(int? color, ThemeData theme) {
    final c = color == null ? Colors.transparent : Color(color);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => Get.back(result: color ?? -1),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: color == null
                ? theme.colorScheme.outline
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: color == null
            ? Icon(Icons.block_rounded, color: theme.colorScheme.outline, size: 18)
            : null,
      ),
    );
  }

  Future<void> _pickRepeat(ThemeData theme) async {
    final value = await _pickDropdown<RepeatType>(
      title: '重复',
      options: RepeatType.values,
      label: (r) => r.label,
      selected: _schedule.repeatType,
    );
    if (value != null) setState(() => _schedule.repeatType = value);
  }

  Future<void> _pickRemind(ThemeData theme) async {
    const options = <int?>[null, 0, 5, 15, 30, 60, 1440];
    final value = await _pickDropdown<int?>(
      title: '提醒',
      options: options,
      label: (o) => o == null ? '不提醒' : _remindLabel(o),
      selected: _schedule.remindOffsetMin,
    );
    if (value != null) setState(() => _schedule.remindOffsetMin = value);
  }

  Future<T?> _pickDropdown<T>({
    required String title,
    required List<T> options,
    required String Function(T) label,
    T? selected,
  }) {
    return Get.dialog<T>(
      Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final option in options)
                ListTile(
                  title: Text(label(option)),
                  trailing: option == selected
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Get.back(result: option),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(SchedulePriority p) => switch (p) {
    SchedulePriority.none => Theme.of(context).colorScheme.outline,
    SchedulePriority.low => const Color(0xFF43A047),
    SchedulePriority.medium => const Color(0xFFFB8C00),
    SchedulePriority.high => const Color(0xFFE53935),
  };
}

String _fmtStart(DateTime t, {required bool allDay}) {
  final date =
      '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  return allDay ? '$date 全天' : '$date ${_fmtTime(t)}';
}

String _fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _remindLabel(int minutes) {
  if (minutes == 0) return '准时';
  if (minutes % 1440 == 0) return '${minutes ~/ 1440} 天前';
  if (minutes % 60 == 0) return '${minutes ~/ 60} 小时前';
  return '$minutes 分钟前';
}
