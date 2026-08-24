import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Twenty 风格搜索式关联字段：
/// 点击展开搜索（输入即搜 300ms 防抖 / 空输入显示最近 5 条 / 无结果「+ 新建」/ 键盘导航），
/// 选中或新建即完成关联，不离开当前页面。
class CrmRelationSearchField extends StatefulWidget {
  final String label;
  final String typeLabel;
  final String currentText;
  final List<Object> candidates;
  final String Function(Object) recordLabel;
  final String Function(Object) recordId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onClear;

  /// 内联新建：返回新记录 id（由调用方决定是否立即关联）
  final Future<String?> Function(String name)? onCreate;

  const CrmRelationSearchField({
    super.key,
    required this.label,
    required this.typeLabel,
    required this.currentText,
    required this.candidates,
    required this.recordLabel,
    required this.recordId,
    required this.onSelect,
    this.onClear,
    this.onCreate,
  });

  @override
  State<CrmRelationSearchField> createState() => _CrmRelationSearchFieldState();
}

class _CrmRelationSearchFieldState extends State<CrmRelationSearchField> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  List<Object> _results = [];
  Timer? _debounce;
  bool _open = false;
  bool _searching = false;
  bool _creating = false;
  int _highlight = -1;
  String _display = '';

  @override
  void didUpdateWidget(covariant CrmRelationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentText != widget.currentText && !_open) {
      _display = widget.currentText;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _searchFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _display = widget.currentText;
    // 搜索框失焦自动收起（延迟避免吞掉结果点击）
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && _open && !_creating) {
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_searchFocus.hasFocus && _open) {
            setState(() => _open = false);
          }
        });
      }
    });
    // 新建表单：失焦自动创建并关联（名称非空时）
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus &&
          _creating &&
          _nameCtrl.text.trim().isNotEmpty) {
        _submitCreate();
      }
    });
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    final keyword = q.trim().toLowerCase();
    if (keyword.isEmpty) {
      setState(() {
        _searching = false;
        _highlight = -1;
        _results = widget.candidates.take(5).toList();
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final results = widget.candidates
          .where(
            (r) =>
                widget.recordLabel(r).toLowerCase().contains(keyword) ||
                r
                    .toString()
                    .toLowerCase()
                    .contains(keyword),
          )
          .take(20)
          .toList();
      setState(() {
        _results = results;
        _searching = false;
        _highlight = -1;
      });
    });
  }

  void _select(Object record) {
    final id = widget.recordId(record);
    widget.onSelect(id);
    setState(() {
      _open = false;
      _display = widget.recordLabel(record);
      _searchCtrl.clear();
    });
    _searchFocus.unfocus();
  }

  void _clear() {
    widget.onClear?.call();
    setState(() {
      _display = '';
      _open = false;
    });
  }

  void _startCreate(String prefill) {
    _nameCtrl.text = prefill;
    setState(() => _creating = true);
  }

  Future<void> _submitCreate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final newId = await widget.onCreate?.call(name);
      if (newId != null) {
        widget.onSelect(newId);
        if (mounted) {
          setState(() {
            _open = false;
            _creating = false;
            _display = name;
            _searchCtrl.clear();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isArrowDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isArrowUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter;
    final isEscape = event.logicalKey == LogicalKeyboardKey.escape;
    if (isArrowDown) {
      if (_results.isNotEmpty) {
        setState(() {
          _highlight = (_highlight + 1).clamp(0, _results.length - 1);
        });
      }
      return KeyEventResult.handled;
    }
    if (isArrowUp) {
      if (_results.isNotEmpty) {
        setState(() => _highlight = (_highlight - 1).clamp(0, _results.length - 1));
      }
      return KeyEventResult.handled;
    }
    if (isEnter) {
      if (_highlight >= 0 && _highlight < _results.length) {
        _select(_results[_highlight]);
        return KeyEventResult.handled;
      }
      if (_results.isEmpty && widget.onCreate != null) {
        _startCreate(_searchCtrl.text);
        return KeyEventResult.handled;
      }
    }
    if (isEscape) {
      setState(() => _open = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_creating) {
      return _buildCreateForm();
    }
    if (!_open) {
      return InkWell(
        onTap: () => setState(() {
          _open = true;
          _results = widget.candidates.take(5).toList();
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _display.isEmpty ? '—' : _display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (_display.isNotEmpty && widget.onClear != null)
                InkWell(
                  onTap: _clear,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                  ),
                ),
              const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onKeyEvent: _onKeyEvent,
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            autofocus: true,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: '搜索${widget.typeLabel}…',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
          ),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '未找到 "${_searchCtrl.text.trim()}"',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  for (var i = 0; i < _results.length; i++)
                    ListTile(
                      dense: true,
                      selected: i == _highlight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(
                        widget.recordLabel(_results[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () => _select(_results[i]),
                    ),
                if (widget.onCreate != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_rounded, size: 18),
                    title: Text(
                      '新建${widget.typeLabel}'
                      '${_searchCtrl.text.trim().isNotEmpty ? ' "${_searchCtrl.text.trim()}"' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onTap: () => _startCreate(_searchCtrl.text.trim()),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              setState(() {
                _creating = false;
                _nameCtrl.clear();
              });
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            autofocus: true,
            onSubmitted: (_) => _submitCreate(),
            decoration: InputDecoration(
              hintText: '输入${widget.typeLabel}名称，失焦或回车自动创建',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
