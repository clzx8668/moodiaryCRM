import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/search/global_search_service.dart';
import 'package:moodiary/pages/edit/edit_arguments.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';

/// 全局命令面板（Ctrl+K / ⌘K）：跨日记 / 子笔记 / CRM 搜索并跳转，附带快捷命令。
///
/// 覆盖层固定在顶部居中（桌面风格命令面板），Esc 或点击遮罩关闭。
Future<void> showCommandPalette(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '命令面板',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const CommandPalettePage(),
  );
}

class CommandPalettePage extends StatefulWidget {
  const CommandPalettePage({super.key});

  @override
  State<CommandPalettePage> createState() => _CommandPalettePageState();
}

class _CommandPalettePageState extends State<CommandPalettePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  List<GlobalSearchResult> _results = const [];
  List<GlobalSearchResult> _recent = const [];
  bool _searching = false;
  int _selectedIndex = 0;

  static const List<String> _groupOrder = ['diary', 'block', 'crm'];
  static const Map<String, String> _groupLabels = {
    'diary': '日记',
    'block': '子笔记',
    'crm': 'CRM',
    'recent': '最近',
    'other': '其他',
  };

  static const List<_Command> _commands = [
    _Command('new_diary', '新建日记', Icons.note_add_outlined, ['新建', 'new']),
  ];

  /// 渲染条目：命令 / 组标题 / 结果项
  List<_PaletteEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final all = await IsarUtil.getAllDiariesSorted();
    if (!mounted) return;
    setState(() {
      _recent = all
          .take(5)
          .map(
            (d) => GlobalSearchResult(
              type: 'diary',
              id: d.id,
              diaryId: d.id,
              title: d.title.isEmpty ? '未命名日记' : d.title,
              snippet: d.contentText.length > 60
                  ? d.contentText.substring(0, 60)
                  : d.contentText,
              time: d.time,
            ),
          )
          .toList();
      _rebuildEntries();
    });
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _search);
  }

  void _rebuildEntries() {
    _entries = [];
    final q = _controller.text.trim();

    if (q.isEmpty) {
      _appendCommands(matchAll: true);
      if (_recent.isNotEmpty) {
        _entries.add(const _PaletteEntry.header('recent'));
        for (final r in _recent) {
          _entries.add(_PaletteEntry.result(r));
        }
      }
    } else {
      _appendCommands(matchAll: false);
      for (final type in _groupOrder) {
        final group = _results.where((r) => r.type == type).toList();
        if (group.isEmpty) continue;
        _entries.add(_PaletteEntry.header(type));
        for (final r in group) {
          _entries.add(_PaletteEntry.result(r));
        }
      }
      final ungrouped =
          _results.where((r) => !_groupOrder.contains(r.type)).toList();
      if (ungrouped.isNotEmpty) {
        _entries.add(const _PaletteEntry.header('other'));
        for (final r in ungrouped) {
          _entries.add(_PaletteEntry.result(r));
        }
      }
    }

    if (_selectedIndex >= _selectableCount) {
      _selectedIndex = 0;
    }
  }

  /// 追加命令入口：空输入时全部展示；有输入时按关键词匹配。
  void _appendCommands({required bool matchAll}) {
    final lower = _controller.text.trim().toLowerCase();
    for (final c in _commands) {
      final matched = matchAll || c.keywords.any((k) => lower.contains(k));
      if (matched) {
        _entries.add(_PaletteEntry.command(c));
      }
    }
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _results = const [];
          _searching = false;
          _rebuildEntries();
        });
      }
      return;
    }
    if (mounted) setState(() => _searching = true);
    final results = await GlobalSearchService.search(q);
    if (!mounted || _controller.text.trim() != q) return;
    setState(() {
      _results = results;
      _searching = false;
      _rebuildEntries();
    });
  }

  /// 键盘导航：↑↓ 移动选择，Enter 打开选中项。
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (_selectableCount == 0) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _selectableCount;
        _scrollToSelected();
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + _selectableCount) %
            _selectableCount;
        _scrollToSelected();
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      final entry = _selectableAt(_selectedIndex);
      if (entry != null) {
        if (entry.isCommand) {
          _runCommand(entry.command!);
        } else {
          _open(entry.result!);
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  int get _selectableCount => _entries.where((e) => !e.isHeader).length;

  _PaletteEntry? _selectableAt(int index) {
    var i = 0;
    for (final e in _entries) {
      if (e.isHeader) continue;
      if (i == index) return e;
      i++;
    }
    return null;
  }

  void _scrollToSelected() {
    var selectableIdx = 0;
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (e.isHeader) continue;
      if (selectableIdx == _selectedIndex) {
        final target = i * 48.0;
        if (_scroll.hasClients) {
          _scroll.animateTo(
            target > 160 ? target - 80 : 0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
        return;
      }
      selectableIdx++;
    }
  }

  Future<void> _open(GlobalSearchResult r) async {
    Navigator.of(context).pop();
    if (r.type == 'diary' || r.type == 'block') {
      final diary = await IsarUtil.getDiaryById(r.diaryId);
      if (diary != null && Get.context != null) {
        Get.toNamed(AppRoutes.diaryPage, arguments: [diary.clone(), true]);
      }
    } else if (r.type == 'crm') {
      // 回首页并切换到 CRM 页签
      if (Get.currentRoute != AppRoutes.homePage) {
        Get.offAllNamed(AppRoutes.homePage);
      }
      if (Get.isRegistered<HomeLogic>()) {
        Get.find<HomeLogic>().navigatorIndex.value = 3; // CRM
      }
    }
  }

  Future<void> _runCommand(_Command c) async {
    Navigator.of(context).pop();
    switch (c.id) {
      case 'new_diary':
        await Get.toNamed(
          AppRoutes.editPage,
          arguments: const EditArguments(type: DiaryType.markdown),
        );
    }
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'diary' => Icons.article_outlined,
      'block' => Icons.notes_rounded,
      'crm' => Icons.business_outlined,
      _ => Icons.search_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightStyle = TextStyle(
      color: colorScheme.primary,
      fontWeight: FontWeight.w700,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 72, left: 16, right: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640, maxHeight: 480),
                child: Material(
                  elevation: 16,
                  borderRadius: BorderRadius.circular(14),
                  color: colorScheme.surfaceContainerHigh,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: '搜索日记 / 子笔记 / CRM…（Esc 关闭）',
                            prefixIcon: Icon(Icons.search_rounded),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: _searching
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _entries.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    '没有匹配结果',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scroll,
                                itemCount: _entries.length,
                                itemBuilder: (context, index) {
                                  final entry = _entries[index];
                                  if (entry.isHeader) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        10,
                                        16,
                                        4,
                                      ),
                                      child: Text(
                                        _groupLabels[entry.type] ?? '其他',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    );
                                  }
                                  if (entry.isCommand) {
                                    final cmd = entry.command!;
                                    final selected =
                                        _selectableIndexOf(entry) ==
                                            _selectedIndex;
                                    return ListTile(
                                      dense: true,
                                      selected: selected,
                                      selectedTileColor:
                                          colorScheme.secondaryContainer
                                              .withValues(alpha: 0.5),
                                      leading: Icon(
                                        cmd.icon,
                                        color: colorScheme.primary,
                                      ),
                                      title: Text(cmd.label),
                                      trailing: Text(
                                        '命令',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      onTap: () => _runCommand(cmd),
                                    );
                                  }
                                  final r = entry.result!;
                                  final selected =
                                      _selectableIndexOf(entry) ==
                                          _selectedIndex;
                                  return ListTile(
                                    dense: true,
                                    selected: selected,
                                    selectedTileColor:
                                        colorScheme.secondaryContainer
                                            .withValues(alpha: 0.5),
                                    leading: Icon(
                                      _typeIcon(r.type),
                                      color: colorScheme.primary,
                                    ),
                                    title: Text.rich(
                                      TextSpan(
                                        children: _highlightSpans(
                                          r.title,
                                          _controller.text.trim(),
                                          highlightStyle,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text.rich(
                                      TextSpan(
                                        children: _highlightSpans(
                                          r.snippet,
                                          _controller.text.trim(),
                                          highlightStyle,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Text(
                                      DateFormat('M月d日 HH:mm').format(r.time),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    onTap: () => _open(r),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 当前渲染条目对应可选条目中的序号（-1 表示组标题）。
  int _selectableIndexOf(_PaletteEntry entry) {
    var i = 0;
    for (final e in _entries) {
      if (e.isHeader) continue;
      if (identical(e, entry)) return i;
      i++;
    }
    return -1;
  }

  /// 高亮 [text] 中出现的 [query]（不区分大小写）。
  List<InlineSpan> _highlightSpans(
    String text,
    String query,
    TextStyle highlightStyle,
  ) {
    if (query.isEmpty) return [TextSpan(text: text)];
    final spans = <InlineSpan>[];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    var start = 0;
    var idx = lower.indexOf(q);
    while (idx >= 0 && idx < text.length) {
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: highlightStyle,
        ),
      );
      start = idx + query.length;
      idx = lower.indexOf(q, start);
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }
}

/// 命令面板中的快捷命令。
class _Command {
  const _Command(this.id, this.label, this.icon, this.keywords);

  final String id;
  final String label;
  final IconData icon;

  /// 小写关键词，命中任一则在搜索时展示该命令。
  final List<String> keywords;
}

/// 命令面板渲染条目：命令 / 组标题 / 搜索结果。
class _PaletteEntry {
  final String type;
  final GlobalSearchResult? result;
  final _Command? command;

  const _PaletteEntry.header(this.type)
      : result = null,
        command = null;

  _PaletteEntry.result(GlobalSearchResult r)
      : type = r.type,
        result = r,
        command = null;

  const _PaletteEntry.command(_Command c)
      : type = 'command',
        result = null,
        command = c;

  bool get isHeader => result == null && command == null;
  bool get isCommand => command != null;
}
