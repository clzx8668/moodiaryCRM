import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/features/search/global_search_service.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';

/// 全局命令面板（Ctrl+K / ⌘K）：跨日记 / 子笔记 / CRM 搜索并跳转。
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
  };

  /// 当前展示的扁平结果（空输入 = 最近记录）
  List<GlobalSearchResult> get _flat =>
      _controller.text.trim().isEmpty ? _recent : _results;

  /// 渲染条目：组标题 / 结果项
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
    final flat = _flat;
    _entries = [];
    for (final type in _groupOrder) {
      final group = flat.where((r) => r.type == type).toList();
      if (group.isEmpty) continue;
      _entries.add(_PaletteEntry.header(type));
      for (final r in group) {
        _entries.add(_PaletteEntry.result(r));
      }
    }
    if (_entries.isEmpty && flat.isNotEmpty) {
      // 兜底：未知类型归入「其他」
      _entries.add(_PaletteEntry.header('other'));
      for (final r in flat) {
        _entries.add(_PaletteEntry.result(r));
      }
    }
    if (_selectedIndex >= flat.length) {
      _selectedIndex = 0;
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
    final flat = _flat;
    if (flat.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % flat.length;
        _scrollToSelected();
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + flat.length) % flat.length;
        _scrollToSelected();
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      _open(flat[_selectedIndex]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    // 找到选中结果的渲染位置（跳过组标题），近似滚动
    var resultIdx = 0;
    var itemIdx = 0;
    for (final e in _entries) {
      if (!e.isHeader) {
        if (resultIdx == _selectedIndex) {
          final target = itemIdx * 56.0;
          if (_scroll.hasClients) {
            _scroll.animateTo(
              target > 200 ? target - 100 : 0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
            );
          }
          return;
        }
        resultIdx++;
      }
      itemIdx++;
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
                            : _flat.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _controller.text.trim().isEmpty
                                        ? '没有最近记录，输入关键词搜索'
                                        : '没有匹配结果',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scroll,
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
                                  final r = entry.result!;
                                  final resultIdx = _resultIndexOf(entry);
                                  final selected = resultIdx == _selectedIndex;
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
                                    title: Text(
                                      r.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      r.snippet,
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
                                itemCount: _entries.length,
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

  /// 当前渲染条目对应扁平结果中的序号（-1 表示组标题）。
  int _resultIndexOf(_PaletteEntry entry) {
    var resultIdx = 0;
    for (final e in _entries) {
      if (e.isHeader) continue;
      if (identical(e, entry)) return resultIdx;
      resultIdx++;
    }
    return -1;
  }
}

/// 命令面板渲染条目：组标题或搜索结果。
class _PaletteEntry {
  final String type;
  final GlobalSearchResult? result;

  const _PaletteEntry._({required this.type, this.result});

  factory _PaletteEntry.header(String type) => _PaletteEntry._(type: type);

  factory _PaletteEntry.result(GlobalSearchResult r) =>
      _PaletteEntry._(type: r.type, result: r);

  bool get isHeader => result == null;
}
