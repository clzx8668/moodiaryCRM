import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/rag/models/knowledge_base.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

/// RAG 对话工作台（P3.4）：知识库选择 + 流式回答 + 引用溯源卡片。
class RagChatPage extends StatefulWidget {
  final KnowledgeBase? knowledgeBase;

  const RagChatPage({super.key, this.knowledgeBase});

  @override
  State<RagChatPage> createState() => _RagChatPageState();
}

class _ChatMessage {
  final String role; // user / assistant
  final String content;
  final List<RagHit> sources;

  const _ChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
  });
}

class _RagChatPageState extends State<RagChatPage> {
  final RagService _service = RagService();
  final TextEditingController _input = TextEditingController();

  KnowledgeBase? _kb;
  final List<_ChatMessage> _messages = [];
  final List<AiChatMessage> _history = [];
  bool _streaming = false;
  String _streamBuffer = '';
  List<RagHit> _lastSources = [];

  @override
  void initState() {
    super.initState();
    _kb = widget.knowledgeBase;
    _input.addListener(() => setState(() {}));
    if (_kb == null) _pickKnowledgeBase();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _pickKnowledgeBase() async {
    final kbs = await _service.listKnowledgeBases();
    if (!mounted || kbs.isEmpty) return;
    final selected = await showModalBottomSheet<KnowledgeBase>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kb in kbs)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(kb.name),
                onTap: () => Navigator.pop(context, kb),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _kb = selected);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _streaming) return;
    final kb = _kb;
    if (kb == null) {
      await _pickKnowledgeBase();
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _input.clear();
      _streaming = true;
      _streamBuffer = '';
    });
    _history.add(AiChatMessage(role: 'user', content: text));

    try {
      final context = await _service.buildContext(kb.id, text);
      _lastSources = context.hits;
      final ragMessages = [
        const AiChatMessage(
          role: 'system',
          content: '你是本地知识库助手。请优先依据「参考内容」回答；'
              '若参考内容不足以回答，请明确说明。回答使用 Markdown。',
        ),
        AiChatMessage(role: 'user', content: context.context),
        ..._history,
      ];
      final provider = await AiProviderFactory.load();
      await for (final chunk in provider.streamChat(ragMessages)) {
        if (!mounted) return;
        if (chunk.error != null) {
          toast.error(message: chunk.error!);
          break;
        }
        setState(() => _streamBuffer += chunk.text);
        if (chunk.done) break;
      }
    } catch (e) {
      toast.error(message: '检索/对话失败：$e');
    }

    if (mounted) {
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            content: _streamBuffer.trim().isEmpty
                ? '（无回答）'
                : _streamBuffer.trim(),
            sources: List.of(_lastSources),
          ),
        );
        _history.add(
          AiChatMessage(
            role: 'assistant',
            content: _streamBuffer.trim(),
          ),
        );
        _streamBuffer = '';
        _streaming = false;
      });
    }
  }

  Future<void> _showSource(RagHit hit) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('引用来源'),
        content: SingleChildScrollView(
          child: SelectableText(
            hit.text,
            maxLines: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final diary = await IsarUtil.getDiaryById(hit.diaryId);
              if (diary != null && mounted) {
                Get.toNamed(AppRoutes.diaryPage, arguments: [diary, true]);
              } else {
                toast.info(message: '源日记不存在或已删除');
              }
            },
            child: const Text('在日记中查看'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: _kb == null
            ? const Text('AI 对话工作台')
            : Text('对话 · ${_kb!.name}'),
        actions: [
          IconButton(
            onPressed: _pickKnowledgeBase,
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: '切换知识库',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      _kb == null
                          ? '请选择一个知识库开始提问'
                          : '基于「${_kb!.name}」提问，回答会附带引用来源',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_streaming ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _messages.length) {
                        return _bubble(
                          role: 'assistant',
                          content: _streamBuffer.isEmpty
                              ? '正在思考…'
                              : _streamBuffer,
                          streaming: true,
                        );
                      }
                      final msg = _messages[index];
                      return _bubble(
                        role: msg.role,
                        content: msg.content,
                        sources: msg.sources,
                      );
                    },
                  ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _bubble({
    required String role,
    required String content,
    List<RagHit> sources = const [],
    bool streaming = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: const TextStyle(height: 1.5),
            ),
            if (streaming)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('生成中…', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < sources.length; i++)
                    ActionChip(
                      label: Text(
                        '来源 ${i + 1}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showSource(sources[i]),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = _input.text.trim().isNotEmpty;
    return Material(
      color: colorScheme.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: '基于知识库提问…',
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _streaming ? null : (hasText ? _send : null),
                icon: _streaming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                tooltip: '发送',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
