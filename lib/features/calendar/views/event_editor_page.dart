import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/models/schedule_attachment.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/utils/notice_util.dart';

import '../calendar_agenda.dart';
import '../calendar_repository.dart';
import '../ios_calendar_theme.dart';
import '../models/calendar_list.dart';

/// iOS 18 风「新建/编辑事件」页。
///
/// 分组列表：标题 / 地点 / 全天 / 开始 / 结束 / 时区 / 重复 / 提醒 / 日历 / 附件 / 备注。
/// 返回 `true` = 有改动（调用方刷新）。
class EventEditorPage extends StatefulWidget {
  final Schedule? event;
  final DateTime? initialDay;
  final List<CalendarList> calendars;

  const EventEditorPage({
    super.key,
    this.event,
    this.initialDay,
    this.calendars = const [],
  });

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  final _repo = ScheduleRepository();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late Schedule _draft;
  late List<CalendarList> _calendars;
  bool _dirty = false;
  bool _saving = false;

  bool get _isNew => widget.event == null;

  @override
  void initState() {
    super.initState();
    final base = widget.event?.clone() ?? Schedule();
    if (_isNew) {
      final day = widget.initialDay ?? DateTime.now();
      final now = DateTime.now();
      final sameDay = isSameDay(day, now);
      base.startTime = DateTime(
        day.year,
        day.month,
        day.day,
        sameDay ? (now.hour + 1) % 24 : 9,
      );
      base.endTime = base.startTime.add(const Duration(hours: 1));
    }
    _draft = base;
    _calendars = List.of(widget.calendars);
    _titleCtrl.text = base.title;
    _locationCtrl.text = base.location ?? '';
    _notesCtrl.text = base.notes;
    if (_calendars.isEmpty) _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    final list = await CalendarRepository().listAll();
    if (!mounted) return;
    setState(() => _calendars = list);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  CalendarList? get _selectedCalendar {
    final id = _draft.calendarId;
    if (id == null) return _calendars.isEmpty ? null : _calendars.first;
    for (final c in _calendars) {
      if (c.id == id) return c;
    }
    return _calendars.isEmpty ? null : _calendars.first;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      toast.info(message: '请输入标题');
      return;
    }
    setState(() => _saving = true);
    _draft
      ..title = title
      ..location = _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim()
      ..notes = _notesCtrl.text
      ..calendarId = _draft.calendarId ?? _selectedCalendar?.id;
    try {
      if (_isNew) {
        await _repo.create(_draft);
      } else {
        await _repo.update(_draft);
      }
      if (mounted) Get.back(result: true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast.error(message: '保存失败：$e');
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除事件'),
        content: const Text('确定删除这个事件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.softDelete(_draft.id);
    if (mounted) Get.back(result: true);
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _draft.startTime : (_draft.endTime ?? _draft.startTime);
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? current.hour,
      time?.minute ?? current.minute,
    );
    _touch(() {
      if (isStart) {
        final duration = (_draft.endTime ?? _draft.startTime).difference(_draft.startTime);
        _draft.startTime = picked;
        _draft.endTime = picked.add(
          duration.isNegative || duration == Duration.zero
              ? const Duration(hours: 1)
              : duration,
        );
      } else {
        _draft.endTime = picked.isAfter(_draft.startTime)
            ? picked
            : _draft.startTime.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      _touch(() {
        for (final f in result.files) {
          _draft.attachments.add(
            ScheduleAttachment(
              name: f.name,
              size: f.size,
              path: f.path,
              mime: _guessMime(f.name),
            ),
          );
        }
      });
    } catch (e) {
      toast.error(message: '选择文件失败：$e');
    }
  }

  static String? _guessMime(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' || 'docx' => 'application/msword',
      'xls' || 'xlsx' => 'application/vnd.ms-excel',
      'ppt' || 'pptx' || 'key' => 'application/vnd.ms-powerpoint',
      'png' || 'jpg' || 'jpeg' || 'webp' => 'image/*',
      'zip' || 'rar' || '7z' => 'application/zip',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('放弃修改？'),
            content: const Text('这个事件还没保存，返回会丢掉刚才的改动。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('继续编辑'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('放弃'),
              ),
            ],
          ),
        );
        if (discard == true && mounted) Get.back(result: false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '新建事件' : '编辑事件'),
          actions: [
            if (!_isNew)
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? '保存中…'
                    : _dirty
                    ? '保存 •'
                    : '保存',
              ),
            ),
          ],
        ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          _GroupBox(
            children: [
              TextField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.done,
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(
                  hintText: '添加标题',
                  border: InputBorder.none,
                ),
                onChanged: (_) => _dirty = true,
              ),
              const Divider(height: 1),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(
                        hintText: '添加地点',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => _dirty = true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GroupBox(
            children: [
              SwitchListTile(
                value: _draft.allDay,
                contentPadding: EdgeInsets.zero,
                title: const Text('全天'),
                onChanged: (v) => _touch(() {
                  _draft.allDay = v;
                  if (v) {
                    _draft.startTime = DateTime(
                      _draft.startTime.year,
                      _draft.startTime.month,
                      _draft.startTime.day,
                    );
                    _draft.endTime = null;
                  }
                }),
              ),
              if (!_draft.allDay) ...[
                _ValueRow(
                  label: '开始',
                  value:
                      '${_draft.startTime.year}年${_draft.startTime.month}月${_draft.startTime.day}日  '
                      '${fmtClock(_draft.startTime)}',
                  onTap: () => _pickDateTime(isStart: true),
                ),
                const Divider(height: 1),
                _ValueRow(
                  label: '结束',
                  value: _draft.endTime == null
                      ? '未设置'
                      : '${_draft.endTime!.year}年${_draft.endTime!.month}月'
                            '${_draft.endTime!.day}日  ${fmtClock(_draft.endTime!)}',
                  onTap: () => _pickDateTime(isStart: false),
                ),
              ],
              const Divider(height: 1),
              _ValueRow(
                label: '时区',
                value: _draft.timeZoneId ?? '跟随设备',
                onTap: _pickTimeZone,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GroupBox(
            children: [
              _ValueRow(
                label: '重复',
                value: _draft.repeatType.label,
                onTap: _pickRepeat,
              ),
              const Divider(height: 1),
              _ValueRow(
                label: '提醒',
                value: _remindLabel,
                onTap: _pickRemind,
              ),
              const Divider(height: 1),
              _ValueRow(
                label: '日历',
                value: _selectedCalendar?.name ?? '默认',
                leading: _selectedCalendar == null
                    ? null
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(_selectedCalendar!.color),
                        ),
                      ),
                onTap: _pickCalendar,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GroupBox(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file_rounded),
                title: const Text('添加附件'),
                subtitle: const Text('会议文件、票据、PDF 挂在事件里'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickFiles,
              ),
              for (final a in _draft.attachments) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconFor(a), color: _colorFor(a, scheme)),
                  title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(a.sizeLabel),
                  trailing: IconButton(
                    tooltip: '移除',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => _touch(() => _draft.attachments.remove(a)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _GroupBox(
            children: [
              TextField(
                controller: _notesCtrl,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: '备注',
                  border: InputBorder.none,
                ),
                onChanged: (_) => _dirty = true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '附件当前只记录文件名与大小；上传/预览与共享日历需要连上 Hermes（见 docs/日历-iOS18改造方案.md §4）。',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      ),
    );
  }

  String get _remindLabel {
    final v = _draft.remindOffsetMin;
    return switch (v) {
      null => '不提醒',
      -1 => '出发时间',
      0 => '准时',
      5 => '5 分钟前',
      15 => '15 分钟前',
      30 => '30 分钟前',
      60 => '1 小时前',
      1440 => '1 天前',
      _ => '$v 分钟前',
    };
  }

  Future<void> _pickRepeat() async {
    final picked = await _pickFromOptions<RepeatType>(
      title: '重复',
      options: {for (final t in RepeatType.values) t.label: t},
      current: _draft.repeatType.label,
    );
    if (picked != null) _touch(() => _draft.repeatType = picked);
  }

  Future<void> _pickRemind() async {
    // -99 作为「不提醒」的哨兵：弹窗返回 null 才代表用户取消
    const off = -99;
    const options = <String, int>{
      '不提醒': off,
      '准时': 0,
      '5 分钟前': 5,
      '15 分钟前': 15,
      '30 分钟前': 30,
      '1 小时前': 60,
      '1 天前': 1440,
      '出发时间（需地点）': -1,
    };
    final picked = await _pickFromOptions<int>(
      title: '提醒',
      options: options,
      current: _remindLabel,
    );
    if (picked == null) return;
    _touch(() => _draft.remindOffsetMin = picked == off ? null : picked);
  }

  Future<void> _pickTimeZone() async {
    // '' 作为「跟随设备」的哨兵：返回 null 才代表取消
    const zones = <String, String>{
      '跟随设备': '',
      'Asia/Shanghai': 'Asia/Shanghai',
      'America/New_York': 'America/New_York',
      'Europe/London': 'Europe/London',
      'Asia/Tokyo': 'Asia/Tokyo',
    };
    final picked = await _pickFromOptions<String>(
      title: '时区',
      options: zones,
      current: _draft.timeZoneId ?? '跟随设备',
    );
    if (picked == null) return;
    _touch(() => _draft.timeZoneId = picked.isEmpty ? null : picked);
  }

  Future<void> _pickCalendar() async {
    if (_calendars.isEmpty) return;
    final picked = await _pickFromOptions<CalendarList>(
      title: '日历',
      options: {for (final c in _calendars) c.name: c},
      current: _selectedCalendar?.name ?? '',
    );
    if (picked != null) _touch(() => _draft.calendarId = picked.id);
  }

  /// 通用单选弹窗（返回 null = 取消）。
  Future<T?> _pickFromOptions<T>({
    required String title,
    required Map<String, T> options,
    required String current,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final entry in options.entries)
              ListTile(
                title: Text(entry.key),
                trailing: entry.key == current
                    ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(entry.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ScheduleAttachment a) {
    final mime = a.mime ?? '';
    final name = a.name.toLowerCase();
    if (mime.contains('pdf') || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    if (mime.startsWith('image') || name.endsWith('.png') || name.endsWith('.jpg')) {
      return Icons.image_rounded;
    }
    if (mime.contains('powerpoint') || name.endsWith('.key')) {
      return Icons.slideshow_rounded;
    }
    if (mime.contains('excel') || name.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }
    if (mime.contains('zip')) return Icons.folder_zip_rounded;
    if (mime.contains('word') || name.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _colorFor(ScheduleAttachment a, ColorScheme scheme) {
    final mime = a.mime ?? '';
    if (mime.contains('pdf')) return const Color(0xFFFF3B30);
    if (mime.startsWith('image')) return const Color(0xFF30D158);
    if (mime.contains('powerpoint')) return const Color(0xFFFF9F0A);
    if (mime.contains('excel')) return const Color(0xFF34C759);
    return scheme.primary;
  }
}

/// 分组卡片（iOS 风：圆角容器 + 内部行用 Divider 分隔）。
class _GroupBox extends StatelessWidget {
  final List<Widget> children;

  const _GroupBox({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(IosCalendarTheme.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// 「左标签 / 右值」行。
class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;

  const _ValueRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
