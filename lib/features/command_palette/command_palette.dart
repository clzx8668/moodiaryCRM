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
  Timer? _debounce;
  List<GlobalSearchResult> _results = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _search);
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _results = const [];
          _searching = false;
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
    });
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
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
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
                            : _results.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _controller.text.trim().isEmpty
                                        ? '输入关键词，跨日记 / 子笔记 / CRM 搜索'
                                        : '没有匹配结果',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemBuilder: (context, index) {
                                  final r = _results[index];
                                  return ListTile(
                                    dense: true,
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
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                itemCount: _results.length,
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
}
