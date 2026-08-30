import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/mood_icon/mood_icon_view.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/ai/widgets/smart_input_bar.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/search/global_search_service.dart';
import 'package:moodiary/features/smart_canvas/services/card_action_router.dart';
import 'package:moodiary/features/smart_canvas/smart_canvas_logic.dart';
import 'package:moodiary/features/smart_canvas/widgets/chat_bubble.dart';
import 'package:moodiary/features/smart_canvas/widgets/smart_card.dart';
import 'package:moodiary/features/voice/speech_service.dart';
import 'package:moodiary/pages/edit/edit_arguments.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/src/rust/api/ffi_api.dart' as rust_ffi;
import 'package:moodiary/utils/notice_util.dart';

/// 中间详情页（SmartCanvasPage）：智能卡片工作台。
///
/// 布局（参照闪念贝壳详情页）：
/// - 头部：SliverAppBar（日记标题/返回/同步/更多）；
/// - 笔记区：非 AI 来源的卡片（色条 + 时间 + 内容 + #标签 + 复制/菜单）；
/// - 「+ 追加笔记」按钮：笔记区左下角，随新笔记下移，点击聚焦底部输入条；
/// - 短横线分隔：「内容由 AI 生成」；
/// - AI 交互区：AI 来源的卡片（「已生成卡片：<模板>」+ 内容 + 查看更多/复制/删除）；
/// - 底部常驻追加输入条。
class SmartCanvasPage extends StatefulWidget {
  const SmartCanvasPage({super.key});

  @override
  State<SmartCanvasPage> createState() => _SmartCanvasPageState();
}

class _SmartCanvasPageState extends State<SmartCanvasPage> {
  late final String _tag;
  late final SmartCanvasLogic logic;
  final TextEditingController _aiInput = TextEditingController();
  final FocusNode _aiFocus = FocusNode();
  bool _voiceMode = false;
  bool _listening = false;

  /// 📎 附加知识文本列表（文件/笔记/CRM），注入 AI 对话上下文
  final List<String> _attachments = [];

  @override
  void initState() {
    super.initState();
    _tag = (Get.arguments[0] as Diary).id;
    logic = Get.isRegistered<SmartCanvasLogic>(tag: _tag)
        ? Get.find<SmartCanvasLogic>(tag: _tag)
        : Get.put(SmartCanvasLogic(), tag: _tag);
  }

  @override
  void dispose() {
    _aiInput.dispose();
    _aiFocus.dispose();
    // 手动注册的 SmartCanvasLogic 需显式删除，否则每次进详情页泄漏
    if (Get.isRegistered<SmartCanvasLogic>(tag: _tag)) {
      Get.delete<SmartCanvasLogic>(tag: _tag, force: true);
    }
    super.dispose();
  }

  Future<void> _showAiTemplateSheet(Block block) async {
    final template = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'AI 处理模板',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final t in AiTemplates.all)
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, size: 20),
                title: Text(AiTemplates.label(t)),
                onTap: () => Navigator.pop(context, t),
              ),
          ],
        ),
      ),
    );
    if (template != null && mounted) {
      await logic.runAiTemplate(block, template);
    }
  }

  Future<void> _confirmDelete(Block block) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除卡片'),
        content: const Text('删除后可从首页搜索中消失（软删除），确定？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await logic.deleteBlock(block);
    }
  }

  Future<void> _runDemoSyncEvents() async {
    toast.info(message: '正在发送演示同步事件…');
    await rust_ffi.emitDemoSyncEvents();
  }

  /// 语音识别：长按「按住 说话」开始，识别结果追加到输入框。
  Future<void> _startVoiceInput() async {
    if (_listening || SpeechService.instance.isListening) return;
    final ok = await SpeechService.instance.startListening((text) {
      if (mounted) setState(() => _listening = false);
      if (text.trim().isEmpty) return;
      final base = _aiInput.text.trim();
      _aiInput.text = base.isEmpty ? text : '$base\n$text';
      _aiInput.selection = TextSelection.collapsed(
        offset: _aiInput.text.length,
      );
      toast.success(message: '已识别：$text');
    });
    if (ok) {
      setState(() => _listening = true);
    } else {
      toast.error(message: '当前设备不支持语音识别，请检查系统语音设置');
    }
  }

  /// 松手结束识别。
  Future<void> _stopVoiceInput() async {
    if (!_listening && !SpeechService.instance.isListening) return;
    await SpeechService.instance.stopListening();
    if (mounted) setState(() => _listening = false);
  }

  /// 📎 附加知识选择器：本地文件 / 已有笔记 / CRM 记录。
  Future<void> _showAttachmentPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('本地文件（TXT / Markdown）'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('已有笔记'),
              onTap: () => Navigator.pop(context, 'note'),
            ),
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('CRM 客户 / 记录'),
              onTap: () => Navigator.pop(context, 'crm'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'file':
        await _pickFileAttachment();
      case 'note':
        await _pickNoteAttachment();
      case 'crm':
        await _pickCrmAttachment();
    }
  }

  void _addAttachment(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() => _attachments.add(trimmed));
  }

  Future<void> _pickFileAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md'],
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      try {
        final text = await File(path).readAsString();
        final name = file.name;
        _addAttachment('文件《$name》\n${text.length > 2000 ? text.substring(0, 2000) : text}');
      } catch (e) {
        toast.error(message: '读取文件失败：$e');
      }
    }
  }

  Future<void> _pickNoteAttachment() async {
    final controller = TextEditingController();
    var results = <GlobalSearchResult>[];
    await showDialog<GlobalSearchResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('选择笔记作为参考资料'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '搜索笔记…',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) async {
                    final r = await GlobalSearchService.search(v);
                    if (dialogContext.mounted) {
                      setDialogState(() {
                        results = r
                            .where((e) => e.type == 'diary')
                            .take(20)
                            .toList();
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: results.isEmpty
                      ? const Center(child: Text('输入关键词搜索笔记'))
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final r = results[index];
                            return ListTile(
                              dense: true,
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
                              onTap: () {
                                Navigator.pop(dialogContext, r);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    ).then((selected) {
      if (selected is GlobalSearchResult) {
        _addAttachment('笔记《${selected.title}》\n${selected.snippet}');
      }
    });
  }

  Future<void> _pickCrmAttachment() async {
    final controller = TextEditingController();
    var results = <GlobalSearchResult>[];
    await showDialog<GlobalSearchResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('选择 CRM 记录作为参考资料'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '搜索客户 / 合同 / 商机…',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) async {
                    final r = await GlobalSearchService.search(v);
                    if (dialogContext.mounted) {
                      setDialogState(() {
                        results = r
                            .where((e) => e.type == 'crm')
                            .take(20)
                            .toList();
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: results.isEmpty
                      ? const Center(child: Text('输入关键词搜索 CRM 记录'))
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final r = results[index];
                            return ListTile(
                              dense: true,
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
                              onTap: () {
                                Navigator.pop(dialogContext, r);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    ).then((selected) {
      if (selected is GlobalSearchResult) {
        _addAttachment('CRM《${selected.title}》\n${selected.snippet}');
      }
    });
  }

  /// 桌面端约束主列阅读宽度，移动端全宽。
  double _contentPadX(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    const maxWidth = 760.0;
    if (w <= 1024) return 16.0;
    final side = (w - maxWidth) / 2;
    return side < 16.0 ? 16.0 : side;
  }

  Widget _buildMetaChips(BuildContext context) {
    final diary = logic.canvasState.diary;
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          MoodIconComponent(value: diary.mood),
          const SizedBox(width: 8),
          Text(
            DateFormat('M月d日 HH:mm').format(diary.time),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          for (final tag in diary.tags.take(6))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 笔记区 + 追加按钮 + 分隔线 + AI 交互区，统一成一列 slivers。
  List<Widget> _contentSlivers(BuildContext context) {
    final padX = _contentPadX(context);

    return [
      Obx(() {
        // 注册展开/收起信号依赖：点击「展开全文/收起」后整列重建
        logic.expandTick.value;
        final blocks = logic.blockList.blocks.value;
        final diary = logic.canvasState.diary;
        if (logic.blockList.loading.value && blocks.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (blocks.isEmpty) {
          final colorScheme = Theme.of(context).colorScheme;
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padX, 40, padX, 8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 44,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '还没有内容，写下第一条笔记吧',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: _openAppendEditor,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('写第一张卡片'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final notes = blocks.where((b) => !b.meta.isAi).toList();
        final ais = blocks.where((b) => b.meta.isAi).toList();
        final slivers = <Widget>[];

        // 笔记区
        if (notes.isNotEmpty) {
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: padX),
              sliver: SliverList.separated(
                itemBuilder: (context, index) =>
                    _buildCard(context, notes[index], diary, isAi: false),
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemCount: notes.length,
              ),
            ),
          );
        }

        // 「+ 追加笔记」按钮（左下角，随新笔记下移）
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padX, notes.isNotEmpty ? 12 : 0, padX, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _openAppendEditor,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('追加笔记'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          ),
        );

        // 短横线分隔「内容由 AI 生成」+ AI 交互区
        if (ais.isNotEmpty) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padX, vertical: 6),
                child: Row(
                  children: [
                    const Expanded(child: Divider(height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '内容由 AI 生成',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(height: 1)),
                  ],
                ),
              ),
            ),
          );
          // 瀑布流 AI 对话（持久化 source=ai 块）
          final chatAis = ais.where((b) => b.meta.role.isNotEmpty).toList();
          if (chatAis.isNotEmpty) {
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padX),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) {
                    final block = chatAis[index];
                    return ChatBubble(
                      block: block,
                      isStreaming: logic.chatStreamingBlockId == block.id,
                      onCopy: () {
                        Clipboard.setData(
                          ClipboardData(text: block.content),
                        );
                        toast.success(message: '已复制');
                      },
                      onRegenerate: () => logic.regenerateAnswer(block.id),
                      onStop: logic.cancelStreaming,
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: chatAis.length,
                ),
              ),
            );
          }
          // 已保存的模板 AI 卡片
          final cardAis = ais.where((b) => b.meta.role.isEmpty).toList();
          if (cardAis.isNotEmpty) {
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padX),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) =>
                      _buildCard(context, cardAis[index], diary, isAi: true),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemCount: cardAis.length,
                ),
              ),
            );
          }
        }

        return SliverMainAxisGroup(slivers: slivers);
      }),
    ];
  }

  Widget _buildCard(
    BuildContext context,
    Block block,
    Diary diary, {
    required bool isAi,
  }) {
    final expanded = logic.isExpanded(block);
    final isStreaming = logic.streaming.isStreaming(block.id);
    final streamBuffer = isStreaming
        ? logic.streaming.buffer.value
        : block.streamBuffer.isNotEmpty
        ? block.streamBuffer
        : block.content;

    return SmartCard(
      key: ValueKey(block.id),
      block: block,
      diary: diary,
      expanded: expanded,
      streamBuffer: streamBuffer,
      isStreaming: isStreaming,
      isAi: isAi,
      onTap: () => resolveCardAction(block).execute(context, logic, block),
      onToggleExpand: () => logic.toggleExpand(block),
      onToggleTodo: (b) => logic.toggleTodo(b),
      onAi: () => _showAiTemplateSheet(block),
      onConvertTodo: () => logic.convertToTodo(block),
      onCopy: () {
        Clipboard.setData(ClipboardData(text: block.content));
        toast.success(message: '已复制卡片内容');
      },
      onStop: isStreaming ? logic.cancelStreaming : null,
      onKeepAsChat: block.streamComplete
          ? () => logic.keepAsChatCard(block)
          : null,
      onResume: () => logic.resumeAiBlock(block),
      onDelete: () => _confirmDelete(block),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Obx(
                    () => Text(
                      logic.canvasState.diaryTitle.value,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  leading: const PageBackButton(),
                  pinned: true,
                  actions: [
                    Obx(() {
                      final sync = logic.sync;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: sync.syncing.value
                            ? Tooltip(
                                message:
                                    '同步中：${sync.phase.value} ${(sync.progress.value * 100).toStringAsFixed(0)}%',
                                child: Icon(
                                  Icons.cloud_sync_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : const SizedBox.shrink(),
                      );
                    }),
                    PopupMenuButton<String>(
                      tooltip: '更多',
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'consolidate',
                          child: Text('笔记整合'),
                        ),
                        if (kDebugMode)
                          const PopupMenuItem(
                            value: 'demo_sync',
                            child: Text('测试同步事件流'),
                          ),
                      ],
                      onSelected: (v) {
                        if (v == 'consolidate') {
                          _openConsolidateEditor();
                        } else if (v == 'demo_sync') {
                          _runDemoSyncEvents();
                        }
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: _buildMetaChips(context),
                  ),
                ),
                ..._contentSlivers(context),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
          // 📎 已附加资料（可删除；作为 AI 对话上下文）
          if (_attachments.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _contentPadX(context),
                vertical: 4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _attachments.length; i++)
                      InputChip(
                        label: Text(
                          '资料 ${i + 1}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => setState(
                          () => _attachments.removeAt(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Obx(() {
            // 桌面端与内容区同宽对齐（720 阅读宽度），移动端全宽
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _contentPadX(context),
              ),
              child: SmartInputBar(
                controller: _aiInput,
                focusNode: _aiFocus,
                startActive: false,
                streaming: logic.isChatStreaming,
                collapsedHint: '按住输入语音',
                activeHint: '问问这条记录，或输入问题…',
                modelLabel: '记录问答',
                voiceMode: _voiceMode,
                onToggleVoice: () => setState(() => _voiceMode = !_voiceMode),
                onLongPressStart: _startVoiceInput,
                onLongPressEnd: _stopVoiceInput,
                listening: _listening,
                onModelSelect: logic.pickChatModel,
                onAt: logic.pickChatKnowledge,
                onPlus: _showAttachmentPicker,
                onSend: (text) {
                  _aiInput.clear();
                  logic.sendChat(text, attachments: List.of(_attachments));
                },
                onStop: logic.cancelStreaming,
              ),
            );
          }),
        ],
      ),
    );
  }

  void _openConsolidateEditor() {
    final diary = logic.canvasState.diary;
    Get.toNamed(
      AppRoutes.editPage,
      arguments: EditArguments(diary: diary.clone(), consolidate: true),
    )?.then((result) {
      if (result == 'changed') {
        logic.init();
      }
    });
  }

  void _openAppendEditor() {
    final diary = logic.canvasState.diary;
    Get.toNamed(
      AppRoutes.editPage,
      arguments: EditArguments(diary: diary.clone(), blockId: ''),
    )?.then((result) {
      if (result == 'changed') {
        logic.reloadBlocks();
        // 追加模式下标题改动写回集合标题，返回后同步刷新 AppBar 标题
        logic.refreshDiary();
      }
    });
  }

}
