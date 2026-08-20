import 'package:flutter/material.dart';
import 'package:moodiary/components/markdown_bar/markdown_bar.dart';
import 'package:moodiary/features/smart_canvas/services/canvas_datasource.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 按卡片编辑的 Markdown 全屏编辑器（双模态：编辑 Block 真相层）。
///
/// 参数：[MarkdownEditPayload]（diaryId + blockId + 标题）。
/// 保存后更新该 Block 内容并刷新日记聚合投影，返回 true。
class BlockMarkdownEditorPage extends StatefulWidget {
  final MarkdownEditPayload payload;

  const BlockMarkdownEditorPage({super.key, required this.payload});

  @override
  State<BlockMarkdownEditorPage> createState() =>
      _BlockMarkdownEditorPageState();
}

class _BlockMarkdownEditorPageState extends State<BlockMarkdownEditorPage> {
  final CanvasDatasource _datasource = CanvasDatasource();
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final block = await _datasource.loadBlock(widget.payload.blockId);
    if (!mounted) return;
    setState(() {
      _controller.text = block?.content ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final block = await _datasource.loadBlock(widget.payload.blockId);
    if (block == null) {
      toast.error(message: '卡片不存在或已删除');
      return;
    }
    setState(() => _saving = true);
    try {
      await _datasource.updateBlockContent(block, _controller.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      toast.error(message: '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.payload.title),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          TextButton(
            onPressed: _loaded && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          MarkdownToolbar(
            useIncludedTextField: false,
            controller: _controller,
            focusNode: _focusNode,
            hideImage: true,
            backgroundColor: colorScheme.surfaceContainerHighest,
            beforeImagePressed: () async => null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(height: 1.6, fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '输入 Markdown 内容…',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 按卡片编辑的载荷
class MarkdownEditPayload {
  final String diaryId;
  final String blockId;
  final String title;

  const MarkdownEditPayload({
    required this.diaryId,
    required this.blockId,
    required this.title,
  });
}
