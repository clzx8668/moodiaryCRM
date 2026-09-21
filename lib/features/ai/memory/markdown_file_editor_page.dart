import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/features/ai/memory/memory_files.dart';
import 'package:moodiary/features/ai/memory/memory_store.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart' as p;

/// 用 App 自带编辑器打开并编辑记忆文件（批次 119）。
///
/// 为什么是"文件编辑器"而不是"表单"：
/// 画像/记忆/技能手册本质是**给人读写的 Markdown**，
/// 表单会把表达力框死（只能填三个字段）。这里直接编辑原文，
/// 用户想加小节、写长句、贴示例都不受限制。
class MarkdownFileEditorPage extends StatefulWidget {
  const MarkdownFileEditorPage({
    super.key,
    required this.filePath,
    this.title,
    this.hint,
  });

  /// 要编辑的文件绝对路径
  final String filePath;

  /// 标题（默认取文件名）
  final String? title;

  /// 顶部提示（说明这个文件是干什么的）
  final String? hint;

  @override
  State<MarkdownFileEditorPage> createState() => _MarkdownFileEditorPageState();
}

class _MarkdownFileEditorPageState extends State<MarkdownFileEditorPage> {
  late final TextEditingController _controller;
  late String _original;
  bool _dirty = false;

  /// 该文件是否属于"记忆自留地"（决定保存时是否打快照）
  bool get _isMemoryFile =>
      p.isWithin(MemoryFiles.rootDir(), widget.filePath) ||
      p.equals(MemoryFiles.rootDir(), p.dirname(widget.filePath));

  @override
  void initState() {
    super.initState();
    _original = _read();
    _controller = TextEditingController(text: _original)
      ..addListener(() {
        final dirty = _controller.text != _original;
        if (dirty != _dirty) setState(() => _dirty = dirty);
      });
  }

  String _read() {
    try {
      final f = File(widget.filePath);
      return f.existsSync() ? f.readAsStringSync() : '';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    try {
      // 自留地里的文件：走 MemoryStore（**自动快照**，可回滚）
      if (_isMemoryFile) {
        if (p.basename(widget.filePath) == MemoryFiles.memoryName) {
          await MemoryStore.saveMemory(_controller.text);
        } else if (p.basename(widget.filePath) == MemoryFiles.profileName) {
          // 画像文件：走原始文本保存（保留用户手写的结构）
          await MemoryStore.saveRawProfileText(_controller.text);
        } else {
          await MemoryStore.saveRawFile(widget.filePath, _controller.text);
        }
      } else {
        await File(widget.filePath).writeAsString(
          _controller.text,
          flush: true,
        );
      }
      _original = _controller.text;
      _dirty = false;
      if (!mounted) return true;
      toast.success(message: '已保存');
      setState(() {});
      return true;
    } catch (e) {
      if (!mounted) return false;
      toast.error(message: '保存失败：$e');
      return false;
    }
  }

  Future<void> _confirmLeave() async {
    if (!_dirty) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('还有未保存的修改'),
        content: const Text('要保存后再离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('放弃修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final saved = await _save();
      if (!saved) return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title ?? p.basename(widget.filePath),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton(
              onPressed: _dirty ? _save : null,
              child: const Text('保存'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.hint != null && widget.hint!.trim().isNotEmpty)
              Container(
                color: colorScheme.surfaceContainerHigh,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Text(
                  widget.hint!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(height: 1.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '在这里写 Markdown…',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
