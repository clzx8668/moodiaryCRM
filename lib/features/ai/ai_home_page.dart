import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_composite_provider.dart';
import 'package:moodiary/features/ai/ai_note_saver.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_settings_page.dart';
import 'package:moodiary/features/ai/models/ai_chat_session.dart';
import 'package:moodiary/features/ai/widgets/smart_input_bar.dart';
import 'package:moodiary/features/block/block_renderer.dart';
import 'package:moodiary/features/rag/knowledge_base_page.dart';
import 'package:moodiary/features/rag/models/knowledge_base.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/utils/notice_util.dart';

/// AI 综合交互页（主流 AI 界面范式）：
/// 知识库选择 + 联网开关 + 流式回答 + 引用溯源 + 多轮对话。
class AiHomePage extends StatefulWidget {
  final KnowledgeBase? initialKnowledgeBase;

  const AiHomePage({super.key, this.initialKnowledgeBase});

  @override
  State<AiHomePage> createState() => _AiHomePageState();
}

class _AiMessage {
  final String role; // user / assistant
  final String content;
  final List<RagHit> sources;

  const _AiMessage({
    required this.role,
    required this.content,
    this.sources = const [],
  });
}

class _AiHomePageState extends State<AiHomePage> {
  final RagService _rag = RagService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_AiMessage> _messages = [];
  final List<AiChatMessage> _history = [];

  KnowledgeBase? _kb;
  String? _currentModel;
  List<ChatModelOption> _chatModels = [];
  AiChatSession? _session;
  final Map<int, Widget> _msgCache = {};
  bool _online = false;
  bool _streaming = false;
  String _streamBuffer = '';
  String _pending = '';
  Timer? _throttle;
  List<RagHit> _lastSources = [];

  /// 建议问题（空态快捷入口）
  static const List<String> _suggestions = [
    '总结我最近一周的记录',
    '帮我列出本周待办',
    '分析一下客户跟进情况',
    '用会议记录模板整理一段内容',
  ];

  @override
  void initState() {
    super.initState();
    _kb = widget.initialKnowledgeBase;
    _input.addListener(() => setState(() {}));
    _loadChatModelInfo();
    _loadRecentSession();
  }

  @override
  void dispose() {
    _throttle?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ==================== 交互 ====================

  Future<void> _pickKnowledgeBase() async {
    if (!_kbEnabled) {
      toast.info(message: '知识库模块已关闭，可在设置中开启');
      return;
    }
    final kbs = await _rag.listKnowledgeBases();
    if (!mounted) return;
    final selected = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('不使用知识库（纯对话）'),
              selected: _kb == null,
              onTap: () => Navigator.pop(sheetContext, 'none'),
            ),
            const Divider(height: 1),
            for (final kb in kbs)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(kb.name),
                subtitle: Text(
                  kb.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: _kb?.id == kb.id,
                onTap: () => Navigator.pop(sheetContext, kb),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('管理知识库'),
              onTap: () {
                Navigator.pop(sheetContext);
                Get.to(() => const KnowledgeBasePage());
              },
            ),
          ],
        ),
      ),
    );
    if (selected == 'none') {
      setState(() => _kb = null);
    } else if (selected is KnowledgeBase) {
      setState(() => _kb = selected);
    }
  }

  Future<void> _loadChatModelInfo() async {
    final provider = await AiProviderFactory.load();
    if (provider is AiCompositeProvider && mounted) {
      setState(() {
        _currentModel = provider.chatLabel;
        _chatModels = provider.chatModels;
      });
    }
  }

  Future<void> _loadRecentSession() async {
    final sessions = await IsarUtil.getAllChatSessions();
    if (sessions.isNotEmpty && mounted) {
      await _loadSession(sessions.first);
    }
  }

  Future<void> _loadSession(AiChatSession session) async {
    final records = await IsarUtil.getChatMessages(session.id);
    if (!mounted) return;
    setState(() {
      _session = session;
      _messages.clear();
      _history.clear();
      _msgCache.clear();
      for (final r in records) {
        _messages.add(
          _AiMessage(
            role: r.role,
            content: r.content,
            sources: r.sources,
          ),
        );
        _history.add(r.toAiChatMessage());
      }
      _streamBuffer = '';
      _streaming = false;
    });
  }

  Future<void> _ensureSession() async {
    if (_session != null) return;
    final session = AiChatSession();
    await IsarUtil.upsertChatSession(session);
    if (mounted) {
      setState(() => _session = session);
    }
  }

  Future<void> _persistMessage(
    String role,
    String content, {
    List<RagHit> sources = const [],
  }) async {
    final session = _session;
    if (session == null) return;
    await IsarUtil.insertChatMessage(
      AiChatMessageRecord()
        ..sessionId = session.id
        ..role = role
        ..content = content
        ..sources = sources
        ..createdAt = DateTime.now(),
    );
    session.updatedAt = DateTime.now();
    if (role == 'user' && session.title == '新话题') {
      session.title = _sessionTitle(content);
    }
    await IsarUtil.upsertChatSession(session);
  }

  String _sessionTitle(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '新话题';
    return trimmed.length <= 20 ? trimmed : '${trimmed.substring(0, 20)}…';
  }

  Future<void> _newSession() async {
    _throttle?.cancel();
    _throttle = null;
    setState(() {
      _session = null;
      _messages.clear();
      _history.clear();
      _msgCache.clear();
      _streamBuffer = '';
      _pending = '';
      _streaming = false;
    });
    toast.info(message: '已开启新话题');
  }

  Future<void> _showSessions() async {
    final sessions = await IsarUtil.getAllChatSessions();
    if (!mounted) return;
    final selected = await showModalBottomSheet<AiChatSession>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: sessions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('暂无历史话题')),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('历史话题', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  for (final s in sessions)
                    ListTile(
                      leading: Icon(
                        s.id == _session?.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                      title: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${s.updatedAt.month}/${s.updatedAt.day} '
                        '${s.updatedAt.hour.toString().padLeft(2, '0')}:'
                        '${s.updatedAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        onPressed: () async {
                          await IsarUtil.deleteChatSession(s.id);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          await _showSessions();
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      ),
                      onTap: () => Navigator.pop(sheetContext, s),
                    ),
                ],
              ),
      ),
    );
    if (selected != null && mounted) {
      await _loadSession(selected);
    }
  }

  Future<void> _pickChatModel() async {
    if (_chatModels.isEmpty) {
      toast.info(message: '暂无可用模型，请先到「模型管理」添加服务商并勾选模型');
      return;
    }
    final selected = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('对话模型'),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.hub_rounded),
              title: const Text('全部（主备自动切换）'),
              selected: _currentModel == null || _chatModels.isEmpty,
              onTap: () => Navigator.pop(sheetContext, 'all'),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in _chatModels)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.memory_rounded, size: 18),
                      title: Text(option.label),
                      selected: _currentModel == option.label,
                      onTap: () => Navigator.pop(sheetContext, option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == 'all') {
      await _saveChatCapability(providerId: '', modelName: '');
      final provider = await AiProviderFactory.load();
      if (provider is AiCompositeProvider && mounted) {
        setState(() => _currentModel = provider.chatLabel);
      }
    } else if (selected is ChatModelOption) {
      await _saveChatCapability(
        providerId: selected.providerId,
        modelName: selected.modelName,
      );
      if (mounted) {
        setState(() => _currentModel = selected.label);
      }
    }
  }

  Future<void> _saveChatCapability({
    required String providerId,
    required String modelName,
  }) async {
    final caps = await AiCapabilityStore.load();
    caps.chat
      ..enabled = true
      ..providerId = providerId
      ..modelName = modelName;
    await AiCapabilityStore.save(caps);
    toast.success(message: '对话模型已切换');
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _streaming) return;
    setState(() {
      _messages.add(_AiMessage(role: 'user', content: text));
      _input.clear();
      _streaming = true;
      _streamBuffer = '';
      _pending = '';
      _lastSources = [];
    });
    await _ensureSession();
    await _persistMessage('user', text);
    _history.add(AiChatMessage(role: 'user', content: text));
    _scrollToBottom();

    try {
      // RAG 上下文（选择知识库时）
      String? ragContext;
      if (_kb != null) {
        try {
          final ctx = await _rag.buildContext(_kb!.id, text, topK: 5);
          _lastSources = ctx.hits;
          ragContext = ctx.context;
        } catch (e) {
          // Embedding/检索失败时降级为普通对话，不让整次问答中断
          ragContext = null;
          _lastSources = [];
          toast.info(message: '知识库检索失败，已切换为普通对话：${_shortError(e)}');
        }
      }
      final system = [
        '你是用户的个人 AI 助手。回答使用 Markdown，简洁有条理。',
        if (ragContext != null)
          '请优先依据「参考内容」回答；若参考内容不足以回答请明确说明。\n\n$ragContext',
        if (_online)
          '（联网搜索已开启：请尽量提供最新信息；当前版本联网检索接入中，'
              '若无法确认最新情况请如实说明。）',
      ].join('\n\n');

      final provider = await AiProviderFactory.load();
      final messages = [
        AiChatMessage(role: 'system', content: system),
        ..._history,
      ];
      await for (final chunk in provider.streamChat(messages)) {
        if (!mounted) return;
        if (chunk.error != null) {
          await SyncLogService.instance.write(
            level: SyncLogLevel.error,
            operation: 'ai',
            target: 'chat',
            detail: 'AI 对话失败：${chunk.error}',
          );
          toast.error(message: chunk.error!);
          break;
        }
        _pending += chunk.text;
        _throttle ??= Timer.periodic(
          const Duration(milliseconds: 80),
          (_) => _flushStream(),
        );
        if (chunk.done) break;
      }
    } catch (e) {
      toast.error(message: '对话失败：$e');
    }

    if (mounted) {
      _throttle?.cancel();
      _throttle = null;
      _flushStream();
      final assistantText = _streamBuffer.trim().isEmpty
          ? '（无回答）'
          : _streamBuffer.trim();
      final sourcesCopy = List.of(_lastSources);
      setState(() {
        _messages.add(
          _AiMessage(
            role: 'assistant',
            content: assistantText,
            sources: sourcesCopy,
          ),
        );
        _history.add(AiChatMessage(role: 'assistant', content: assistantText));
        _streamBuffer = '';
        _streaming = false;
      });
      await _persistMessage('assistant', assistantText, sources: sourcesCopy);
      _scrollToBottom();
    }
  }

  void _flushStream() {
    if (!mounted || _pending.isEmpty) return;
    setState(() {
      _streamBuffer += _pending;
      _pending = '';
    });
    _scrollToBottom();
  }

  void _stopStreaming() {
    _throttle?.cancel();
    _throttle = null;
    _flushStream();
    if (mounted) {
      final assistantText = _streamBuffer.trim().isEmpty
          ? '（已停止）'
          : _streamBuffer.trim();
      final sourcesCopy = List.of(_lastSources);
      setState(() {
        _messages.add(
          _AiMessage(
            role: 'assistant',
            content: assistantText,
            sources: sourcesCopy,
          ),
        );
        _history.add(AiChatMessage(role: 'assistant', content: assistantText));
        _streamBuffer = '';
        _streaming = false;
      });
      _persistMessage('assistant', assistantText, sources: sourcesCopy);
    }
  }

  Future<void> _regenerate(int messageIndex) async {
    if (_streaming || messageIndex < 1) return;
    final user = _messages[messageIndex - 1];
    if (user.role != 'user') return;
    // 移除最后一条助手消息与其历史
    _messages.removeRange(messageIndex, _messages.length);
    _history.removeLast();
    await _send(user.content);
  }

  void _clearConversation() {
    _throttle?.cancel();
    _throttle = null;
    setState(() {
      _messages.clear();
      _history.clear();
      _msgCache.clear();
      _streamBuffer = '';
      _pending = '';
      _streaming = false;
    });
  }

  Future<void> _saveAsNote(String content) async {
    final diary = await AiNoteSaver.save(content);
    toast.success(message: '已存入笔记');
    if (mounted) {
      Get.toNamed(AppRoutes.diaryPage, arguments: [diary, true]);
    }
  }

  Future<void> _saveToKnowledgeBase(String content) async {
    final kbs = await _rag.listKnowledgeBases();
    if (kbs.isEmpty) {
      toast.info(message: '还没有知识库，请先到「知识库管理」创建');
      return;
    }
    if (!mounted) return;
    final kb = await showModalBottomSheet<KnowledgeBase>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '选择知识库',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final k in kbs)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded, size: 18),
                title: Text(k.name),
                onTap: () => Navigator.pop(sheetContext, k),
              ),
          ],
        ),
      ),
    );
    if (kb == null || !mounted) return;
    final diary = await AiNoteSaver.save(content);
    await _rag.indexBlocks(knowledgeBaseId: kb.id, diaryId: diary.id);
    toast.success(message: '已加入知识库「${kb.name}」');
  }

  bool get _kbEnabled => PrefUtil.getValue<bool>('moduleKnowledgeBase') ?? true;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showSource(RagHit hit) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('引用来源'),
        content: SingleChildScrollView(
          child: SelectableText(hit.text, maxLines: 12),
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

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(
            onPressed: _showSessions,
            icon: const Icon(Icons.history_rounded),
            tooltip: '历史话题',
          ),
          IconButton(
            onPressed: _newSession,
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: '新开话题',
          ),
          IconButton(
            onPressed: () => Get.to(() => const KnowledgeBasePage()),
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: '知识库管理',
          ),
          IconButton(
            onPressed: () => Get.to(() => const AiSettingsPage()),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'AI 设置',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _messages.isEmpty && !_streaming
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_streaming ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _messages.length) {
                            return _buildAssistant(
                              content: _streamBuffer,
                              streaming: true,
                              sources: const [],
                              index: -1,
                              onSaveNote: null,
                              onSaveToKb: null,
                            );
                          }
                          return _buildCachedMessage(index);
                        },
                      ),
              ),
            ),
          ),
          _buildContextBar(context),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      // 窄屏/矮屏下内容超高时可滚动，避免 bottom overflow
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '今天想聊什么？',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '可以结合知识库提问，回答会自动附带引用来源',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => _send(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUser(String content) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: SelectableText(
          content,
          style: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }

  Widget _buildCachedMessage(int index) {
    final cached = _msgCache[index];
    if (cached != null) return cached;
    final msg = _messages[index];
    final widget = msg.role == 'user'
        ? _buildUser(msg.content)
        : _buildAssistant(
            content: msg.content,
            streaming: false,
            sources: msg.sources,
            index: index,
            onSaveNote: msg.content.trim().isEmpty ||
                    msg.content == '（无回答）'
                ? null
                : () => _saveAsNote(msg.content),
            onSaveToKb: msg.content.trim().isEmpty ||
                    msg.content == '（无回答）'
                ? null
                : () => _saveToKnowledgeBase(msg.content),
          );
    _msgCache[index] = widget;
    return widget;
  }

  Widget _buildAssistant({
    required String content,
    required bool streaming,
    required List<RagHit> sources,
    required int index,
    required VoidCallback? onSaveNote,
    required VoidCallback? onSaveToKb,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: content.trim().isEmpty
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              streaming ? '正在思考…' : '（空）',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      : MarkdownContentView(data: content),
                ),
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 6),
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
                if (!streaming && index >= 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _iconAction(
                        icon: Icons.copy_rounded,
                        tooltip: '复制',
                        onTap: () {
                          _copy(content);
                        },
                      ),
                      _iconAction(
                        icon: Icons.refresh_rounded,
                        tooltip: '重新生成',
                        onTap: () => _regenerate(index),
                      ),
                      if (onSaveNote != null)
                        _iconAction(
                          icon: Icons.note_add_outlined,
                          tooltip: '存入笔记',
                          onTap: onSaveNote,
                        ),
                      if (onSaveToKb != null)
                        _iconAction(
                          icon: Icons.menu_book_outlined,
                          tooltip: '加入知识库',
                          onTap: onSaveToKb,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    toast.success(message: '已复制');
  }

  /// 提取简短错误信息（避免把 dio 堆栈整段抛给用户）
  String _shortError(Object e) {
    final text = e.toString();
    // StateError 的 message 即为友好提示
    if (e is StateError) return e.message;
    final trimmed = text.trim();
    return trimmed.length <= 80 ? trimmed : '${trimmed.substring(0, 80)}…';
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildContextBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        // 横向可滚动：窄屏下模型/知识库/联网 chips 不溢出
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.memory_rounded, size: 16),
                label: Text(
                  _currentModel ?? '模型',
                  style: const TextStyle(fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
                onPressed: _pickChatModel,
              ),
              const SizedBox(width: 8),
              if (_kbEnabled) ...[
                ActionChip(
                  avatar: const Icon(Icons.menu_book_outlined, size: 16),
                  label: Text(
                    _kb == null ? '知识库：关闭' : '知识库：${_kb!.name}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: _pickKnowledgeBase,
                ),
                const SizedBox(width: 8),
              ],
              ActionChip(
                avatar: Icon(
                  _online ? Icons.public_rounded : Icons.public_off_rounded,
                  size: 16,
                  color: _online ? colorScheme.primary : null,
                ),
                label: Text(
                  _online ? '联网：开' : '联网：关',
                  style: const TextStyle(fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _online = !_online),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _messages.isEmpty ? null : _clearConversation,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('清空', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return SmartInputBar(
      controller: _input,
      startActive: false,
      streaming: _streaming,
      collapsedHint: '按住输入语音',
      activeHint: '输入问题，Enter 发送，Shift+Enter 换行…',
      modelLabel: 'AI',
      onSend: (_) => _send(),
      onStop: _stopStreaming,
    );
  }
}
