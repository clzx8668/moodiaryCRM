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
import 'package:moodiary/features/ai/extract/ai_extract_meta.dart';
import 'package:moodiary/features/ai/extract/extract_plan_config.dart';
import 'package:moodiary/features/ai/extract/extract_plan_types.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/local/crm_write_service.dart';
import 'package:moodiary/features/crm/resolve/crm_entity_resolver.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/features/search/global_search_service.dart';
import 'package:moodiary/features/smart_canvas/services/card_action_router.dart';
import 'package:moodiary/features/smart_canvas/smart_canvas_logic.dart';
import 'package:moodiary/features/smart_canvas/widgets/chat_bubble.dart';
import 'package:moodiary/features/smart_canvas/widgets/smart_card.dart';
import 'package:moodiary/features/voice/speech_service.dart';
import 'package:moodiary/pages/edit/edit_arguments.dart';
import 'package:moodiary/persistence/pref.dart';
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
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Obsidian 笔记'),
              onTap: () => Navigator.pop(context, 'obsidian'),
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
      case 'obsidian':
        await _pickObsidianAttachment();
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

  /// 📎 附加知识：Obsidian Vault 笔记（关键词搜索单选）。
  Future<void> _pickObsidianAttachment() async {
    if (!ObsidianConfig.enabled.value) {
      toast.info(message: 'Obsidian 未启用，请先在设置中开启');
      return;
    }
    await ObsidianService.instance.scan();
    if (!mounted) return;
    final controller = TextEditingController();
    var results = <ObsidianFile>[];
    await showDialog<ObsidianFile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('选择 Obsidian 笔记作为参考资料'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '搜索 Obsidian 笔记…',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    setDialogState(() {
                      results = ObsidianService.instance
                          .search(v)
                          .take(20)
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            controller.text.trim().isEmpty
                                ? '输入关键词搜索 Vault 笔记'
                                : '无匹配结果',
                          ),
                        )
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final f = results[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                f.relativePath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                f.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.pop(dialogContext, f),
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
      if (selected != null) {
        final text = selected.content.trim();
        _addAttachment(
          'Obsidian《${selected.name}》\n'
          '${text.length > 2000 ? text.substring(0, 2000) : text}',
        );
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
      onCleanColloquial: () => logic.cleanBlockColloquial(block),
      onRestoreColloquial: () => logic.restoreBlockColloquial(block),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 集合变化信号：背景/AppBar 着色随集合重载跟随重绘
      logic.canvasState.diaryRevision.value;
      final scheme = Theme.of(context).colorScheme;
      final dynamicOn = PrefUtil.getValue<bool>('dynamicColor') == true;
      final accent = _resolveBgColor(logic.canvasState.diary);
      final accentColor =
          (dynamicOn && accent != null) ? Color(accent) : null;
      return Scaffold(
        backgroundColor: accentColor == null
            ? null
            : Color.alphaBlend(
                accentColor.withValues(alpha: 0.10),
                scheme.surface,
              ),
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
                  backgroundColor: accentColor == null
                      ? null
                      : Color.alphaBlend(
                          accentColor.withValues(alpha: 0.16),
                          scheme.surface,
                        ),
                  surfaceTintColor: accentColor,
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
                        const PopupMenuItem(
                          value: 'voice',
                          child: Text('语音记录'),
                        ),
                        const PopupMenuItem(
                          value: 'extract',
                          child: Text('AI 抽取'),
                        ),
                        const PopupMenuItem(
                          value: 'plan',
                          child: Text('抽取计划'),
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
                        } else if (v == 'voice') {
                          Get.toNamed(AppRoutes.voiceRecordPage);
                        } else if (v == 'extract') {
                          _showAiExtract(context);
                        } else if (v == 'plan') {
                          _showPlanSettings(context);
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
                    child: Obx(() {
                      // 集合变化信号：标题/心情等元数据重载后让元信息区跟随重绘
                      logic.canvasState.diaryRevision.value;
                      final summary =
                          logic.canvasState.diary.summary.trim();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetaChips(context),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '摘要：$summary',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
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
    });
  }

  /// 背景着色源：自定义背景色 > 第一个标签的颜色 > 无。
  int? _resolveBgColor(Diary diary) {
    if (diary.bgColor != null) return diary.bgColor;
    if (diary.tags.isNotEmpty) {
      return diary.tagColors[diary.tags.first];
    }
    return null;
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

  Future<void> _showAiExtract(BuildContext context) async {
    final meta = await logic.runExtractPlan();
    if (!context.mounted) return;
    if (meta == null) return;
    if (meta.status == 'failed') {
      toast.info(
        message: meta.message.isEmpty ? 'AI 抽取未成功，可稍后重试' : meta.message,
      );
    } else {
      toast.success(
        message: '已抽取：待办/日程 ${meta.scheduleIds.length}，CRM 建议 ${meta.crmProposals.length}',
      );
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AiExtractSheet(meta: meta),
    );
  }

  Future<void> _showPlanSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ExtractPlanSheet(),
    );
  }

}

/// 抽取计划开关：决定「AI 抽取」只抽哪些内容。
class _ExtractPlanSheet extends StatefulWidget {
  const _ExtractPlanSheet();

  @override
  State<_ExtractPlanSheet> createState() => _ExtractPlanSheetState();
}

class _ExtractPlanSheetState extends State<_ExtractPlanSheet> {
  late final ExtractPlanConfig _config = ExtractPlanConfig.load();

  Future<void> _save() async {
    await ExtractPlanConfig.save(_config);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('抽取计划', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            SwitchListTile(
              title: const Text('抽取待办'),
              value: _config.todo,
              onChanged: (v) => setState(() => _config.todo = v),
              dense: true,
            ),
            SwitchListTile(
              title: const Text('抽取日程'),
              value: _config.schedule,
              onChanged: (v) => setState(() => _config.schedule = v),
              dense: true,
            ),
            SwitchListTile(
              title: const Text('抽取 CRM'),
              value: _config.crm,
              onChanged: (v) => setState(() => _config.crm = v),
              dense: true,
            ),
            SwitchListTile(
              title: const Text('生成摘要'),
              value: _config.summary,
              onChanged: (v) => setState(() => _config.summary = v),
              dense: true,
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}

/// AI 抽取结果审核面板：展示已生成的待办/日程 + 待确认的 CRM 提案（确认后才写库）。
class _AiExtractSheet extends StatelessWidget {
  final AiExtractMeta meta;
  const _AiExtractSheet({required this.meta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 抽取结果', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (meta.status == 'failed')
            Card.filled(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  meta.message.isEmpty ? '抽取未成功' : meta.message,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          if (meta.summary.isNotEmpty)
            Card.filled(
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('摘要：${meta.summary}'),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.task_alt_rounded),
            title: Text('已生成 ${meta.scheduleIds.length} 个待办/日程'),
            subtitle: const Text('已保存至日历，可稍后查看/编辑'),
            dense: true,
          ),
          if (meta.crmProposals.isNotEmpty) ...[
            const Divider(),
            Text('CRM 建议（确认后写入）',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final crm in meta.crmProposals)
              _CrmProposalTile(proposal: crm),
          ],
        ],
      ),
    );
  }
}

class _CrmProposalTile extends StatefulWidget {
  final ExtractCrm proposal;
  const _CrmProposalTile({required this.proposal});

  @override
  State<_CrmProposalTile> createState() => _CrmProposalTileState();
}

class _CrmProposalTileState extends State<_CrmProposalTile> {
  String _status = '解析中…';
  CrmResolveMatch? _match;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final c = widget.proposal;
    if (c.type != 'account' &&
        c.type != 'contact' &&
        c.type != 'opportunity' &&
        c.type != 'contract') {
      if (mounted) setState(() => _status = '将新建（支持类型）');
      return;
    }
    final result = await CrmEntityResolver().resolve(
      objectType: c.type,
      name: c.name,
      phone: c.fields['phone']?.toString(),
      email: c.fields['email']?.toString(),
    );
    if (!mounted) return;
    if (result.best != null) {
      _match = result.best;
      setState(() => _status = '匹配到「${result.best!.name}」（更新）');
    } else {
      setState(() => _status = '未匹配到（将新建）');
    }
  }

  Future<void> _confirm() async {
    final c = widget.proposal;
    try {
      final proposal = await CrmWriteService.buildProposal(
        action: 'create',
        args: {
          'object': c.type,
          'fields': {'name': c.name, ...c.fields},
        },
      );
      final ok = await Get.dialog<bool>(
        AlertDialog(
          title: Text('创建 ${proposal.objectLabel}？'),
          content: Text(
            _match == null
                ? '将新建「${proposal.targetName}」'
                : '已存在「${_match!.name}」，切换为更新该记录',
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
            FilledButton(onPressed: () => Get.back(result: true), child: const Text('确认')),
          ],
        ),
      );
      if (ok == true) {
        await CrmWriteService.execute(proposal);
        if (mounted) {
          toast.success(message: '已写入 CRM：${proposal.objectLabel}');
        }
      }
    } catch (e) {
      if (mounted) toast.error(message: '写入失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.proposal;
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(Icons.business_rounded, color: theme.colorScheme.primary),
        title: Text(c.name.isNotEmpty ? c.name : '未命名'),
        subtitle: Text(_status),
        dense: true,
        trailing: IconButton(
          tooltip: '确认写入',
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: _confirm,
        ),
      ),
    );
  }
}
