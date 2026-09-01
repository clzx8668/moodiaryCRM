import 'package:flutter/material.dart';
import 'package:moodiary/utils/notice_util.dart';

import '../models/schedule.dart';
import '../schedule_repository.dart';

/// 快捷建日程底部面板（3 步内：标题 → 日期/时间 → 提醒 → 保存）。
///
/// 保存成功返回 [Schedule]；取消返回 null。
Future<Schedule?> showQuickAddScheduleSheet(
  BuildContext context, {
  DateTime? initial,
}) async {
  return showModalBottomSheet<Schedule>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QuickAddSheet(initial: initial),
  );
}

class _QuickAddSheet extends StatefulWidget {
  final DateTime? initial;

  const _QuickAddSheet({this.initial});

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _titleCtrl = TextEditingController();
  final _repo = ScheduleRepository();

  late DateTime _date;
  late TimeOfDay _time;
  bool _allDay = false;
  bool _floating = false;
  int? _remindOffsetMin;

  @override
  void initState() {
    super.initState();
    final now = widget.initial ?? DateTime.now();
    // 默认取下一个整点
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    _date = next;
    _time = TimeOfDay(hour: next.hour, minute: next.minute);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  DateTime get _start => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _allDay ? 0 : _time.hour,
    _allDay ? 0 : _time.minute,
  );

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      toast.info(message: '请输入标题');
      return;
    }
    try {
      final created = await _repo.create(
        Schedule()
          ..title = title
          ..startTime = _start
          ..allDay = _allDay
          ..floating = _floating
          ..remindOffsetMin = _remindOffsetMin,
      );
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      toast.error(message: '创建失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('快捷日程', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '标题 *',
              hintText: '例如：和客户对方案',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('无固定日期（浮动收件箱）'),
            value: _floating,
            onChanged: (v) => setState(() => _floating = v),
            dense: true,
          ),
          if (!_floating) ...[
          Row(
            spacing: 8,
            children: [
              _quickDayChip('今天', () => setState(() => _date = DateTime.now())),
              _quickDayChip(
                '明天',
                () => setState(
                  () => _date = DateTime.now().add(const Duration(days: 1)),
                ),
              ),
              _quickDayChip(
                _fmtDate(_date),
                () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(() => _date = picked);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('全天'),
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v),
                  dense: true,
                ),
              ),
              if (!_allDay)
                OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (t != null && mounted) setState(() => _time = t);
                  },
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(_fmtTime(_time)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ],
          DropdownButtonFormField<int?>(
            initialValue: _remindOffsetMin,
            decoration: const InputDecoration(
              labelText: '提醒',
              prefixIcon: Icon(Icons.alarm_rounded),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('不提醒')),
              DropdownMenuItem(value: 0, child: Text('准时')),
              DropdownMenuItem(value: 5, child: Text('5 分钟前')),
              DropdownMenuItem(value: 15, child: Text('15 分钟前')),
              DropdownMenuItem(value: 30, child: Text('30 分钟前')),
              DropdownMenuItem(value: 60, child: Text('1 小时前')),
            ],
            onChanged: (v) => setState(() => _remindOffsetMin = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF57C00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickDayChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.month}月${d.day}日';

String _fmtTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
