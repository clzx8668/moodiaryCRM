import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/mood_icon/mood_icon_view.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/ai/skills/ai_skill.dart';
import 'package:moodiary/features/ai/skills/works_service.dart';
import 'package:moodiary/features/ai/autolink/auto_link_service.dart';
import 'package:moodiary/features/ai/autolink/semantic_link_service.dart';
import 'package:moodiary/features/ai/widgets/smart_input_bar.dart';
import 'package:moodiary/features/ai/chat_model_selector.dart';
import 'package:moodiary/features/ai/widgets/chat_model_picker_sheet.dart';
import 'package:moodiary/features/smart_canvas/widgets/relative_time.dart';
import 'package:moodiary/features/smart_canvas/widgets/canvas_skeleton.dart';
import 'package:moodiary/features/collection/kb_collection_service.dart';
import 'package:moodiary/features/ai/extract/ai_extract_meta.dart';
import 'package:moodiary/features/ai/extract/extract_plan_config.dart';
import 'package:moodiary/features/ai/extract/extract_plan_service.dart';
import 'package:moodiary/features/ai/extract/extract_plan_types.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/local/crm_write_service.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_entity_creator.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/models/crm_content_link.dart';
import 'package:moodiary/features/crm/crm_create_form_panel.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/schedule/views/schedule_detail_page.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/pages/diary_details/diary_details_logic.dart';
import 'package:moodiary/features/search/global_search_service.dart';
import 'package:moodiary/features/rag/models/knowledge_base.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/features/smart_canvas/services/card_action_router.dart';
import 'package:moodiary/features/smart_canvas/services/diary_delete_service.dart';
import 'package:moodiary/features/smart_canvas/smart_canvas_logic.dart';
import 'package:moodiary/features/smart_canvas/widgets/chat_bubble.dart';
import 'package:moodiary/features/smart_canvas/widgets/smart_card.dart';
import 'package:moodiary/features/voice/voice_note_info.dart';
import 'package:moodiary/features/voice/voice_input_controller.dart';
import 'package:moodiary/features/voice/widgets/voice_note_header.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/features/ai/tasks/pending_content_service.dart';
import 'package:moodiary/pages/edit/edit_arguments.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:uuid/uuid.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';
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

  /// 长按说话控制器（与快捷收集面板共用同一套「录音落盘 + 云端转写」逻辑）
  late final VoiceInputController _voiceInput;
  final ValueNotifier<bool> _voiceBusy = ValueNotifier<bool>(false);

  /// 追加模式：底部输入条发出去的是新卡片，而不是 AI 提问
  bool _appendMode = false;

  /// 触发底部输入条展开（追加模式进入时立刻可打字）
  final ValueNotifier<int> _activateInput = ValueNotifier<int>(0);

  /// 滚动到一定距离后，才在顶栏显示笔记标题（滚动前标题已在正文首卡里，避免重复）。
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _barTitleVisible = ValueNotifier<bool>(false);

  /// 📎 附加知识文本列表（文件/笔记/CRM），注入 AI 对话上下文
  final List<String> _attachments = [];

  /// 录音笔记：顶部「录音原文 / 笔记内容」当前页（普通笔记不使用）
  VoiceNoteTab _voiceTab = VoiceNoteTab.note;

  /// 转写进行中的自动刷新（转好即写入正文，不必手动返回重进）
  Timer? _transcribePoll;

  /// 当前对话模型短标签（底部输入条 chip）
  String _chatModelLabel = '默认';

  @override
  void initState() {
    super.initState();
    _tag = (Get.arguments[0] as Diary).id;
    logic = Get.isRegistered<SmartCanvasLogic>(tag: _tag)
        ? Get.find<SmartCanvasLogic>(tag: _tag)
        : Get.put(SmartCanvasLogic(), tag: _tag);
    _scrollController.addListener(_onScrollForBarTitle);
    unawaited(_loadChatModelLabel());
    _voiceInput = VoiceInputController(
      onText: (text) {
        _aiInput.text = appendVoiceText(_aiInput.text, text);
        _aiInput.selection = TextSelection.collapsed(
          offset: _aiInput.text.length,
        );
      },
    );
    _voiceInput.busy.addListener(_onVoiceBusyChanged);
  }

  @override
  void dispose() {
    _transcribePoll?.cancel();
    _voiceInput.busy.removeListener(_onVoiceBusyChanged);
    _voiceInput.dispose();
    _voiceBusy.dispose();
    _scrollController.removeListener(_onScrollForBarTitle);
    _scrollController.dispose();
    _barTitleVisible.dispose();
    _activateInput.dispose();
    _aiInput.dispose();
    _aiFocus.dispose();
    // 手动注册的 SmartCanvasLogic 需显式删除，否则每次进详情页泄漏
    if (Get.isRegistered<SmartCanvasLogic>(tag: _tag)) {
      Get.delete<SmartCanvasLogic>(tag: _tag, force: true);
    }
    super.dispose();
  }

  void _onScrollForBarTitle() {
    if (!_scrollController.hasClients) return;
    final visible = _scrollController.offset > 56;
    if (_barTitleVisible.value != visible) {
      _barTitleVisible.value = visible;
    }
  }

  Future<void> _loadChatModelLabel() async {
    try {
      final label = await ChatModelSelector.currentShortLabel();
      if (mounted && label != _chatModelLabel) {
        setState(() => _chatModelLabel = label);
      }
    } catch (_) {
      // 读取失败保持默认标签
    }
  }

  /// 切换当前对话模型（与快速收集/AI 助手共用同一面板与配置）
  Future<void> _pickChatModel(BuildContext context) async {
    final picked = await showChatModelPicker(context);
    if (picked != null) await _loadChatModelLabel();
  }

  /// 选择「知识库上下文」：提问时先在该库里做 RAG 检索，把命中片段交给模型。
  Future<void> _pickChatKnowledge(BuildContext context) async {
    final kbs = await RagService().listKnowledgeBases();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('知识库上下文'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('不使用知识库'),
              trailing: logic.chatKnowledgeBase.value == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                logic.chatKnowledgeBase.value = null;
                Navigator.pop(sheetContext);
                toast.info(message: '已关闭知识库上下文');
              },
            ),
            if (kbs.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text('还没有知识库：可在「设置 → 知识库」里创建并索引内容'),
              )
            else
              for (final kb in kbs)
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: Text(kb.name),
                  subtitle: kb.description.trim().isEmpty
                      ? const Text('提问时在该库里检索相关片段')
                      : Text(kb.description.trim()),
                  trailing: logic.chatKnowledgeBase.value?.id == kb.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    logic.chatKnowledgeBase.value = kb;
                    Navigator.pop(sheetContext);
                    toast.success(message: '已选用知识库：${kb.name}');
                  },
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

  /// 删除整条记录（详情页右上角菜单）：移入回收站，可恢复。
  Future<void> _deleteCurrentDiary() async {
    final diary = logic.canvasState.diary;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text(
          '记录会移入回收站（含这条记录下的所有卡片），'
          '可在「设置 → 回收站」里恢复或彻底删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    final navigator = Navigator.of(context);
    try {
      await DiaryDeleteService.moveToRecycle(
        diaryId: diary.id,
        isarId: diary.isarId,
      );
    } catch (e) {
      toast.error(message: '删除失败：$e');
      return;
    }
    toast.success(message: '已删除，可在「设置 → 回收站」恢复');
    // 首页/日历/各分类列表刷新
    try {
      if (Get.isRegistered<HomeLogic>()) {
        await Get.find<HomeLogic>().refreshDiaryLists();
      }
    } catch (_) {}
    if (!mounted) return;
    navigator.pop();
  }

  /// 语音识别：长按「按住 说话」开始，识别结果追加到输入框。
  Future<void> _startVoiceInput() async {
    if (_listening) return;
    await _voiceInput.start();
    if (mounted) setState(() => _listening = _voiceInput.busy.value);
  }

  /// 松手结束识别。
  Future<void> _stopVoiceInput() async {
    if (!_listening) return;
    await _voiceInput.stop();
    if (mounted) setState(() => _listening = false);
  }

  /// 录音结束到转写回填之间也保持「正在聆听…」反馈
  void _onVoiceBusyChanged() {
    if (!mounted) return;
    final busy = _voiceInput.busy.value;
    if (busy == _listening) return;
    setState(() => _listening = busy);
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
            relativeTimeLabel(diary.time),
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
  /// 含录音的笔记在正上方追加播放器与转写状态区块；非语音笔记返回空列表。
  List<Widget> _voiceSlivers(BuildContext context) {
    return [
      Obx(() {
        final info = VoiceNoteInfo.from(
          diary: logic.canvasState.diary,
          blocks: logic.blockList.blocks.value,
        );
        _syncTranscribePoll(info);
        if (info == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final padX = _contentPadX(context);
        return SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(padX, 4, padX, 12),
            child: VoiceNoteHeader(
              info: info,
              audioPath: FileUtil.getRealPath('audio', info.audioFile),
              tab: _voiceTab,
              onTabChanged: (t) => setState(() => _voiceTab = t),
              onRetry: () => _retryVoiceTranscription(info),
            ),
          ),
        );
      }),
    ];
  }

  /// 转写中每 3 秒拉一次块列表：转好即自动写入正文，用户不必退出重进。
  void _syncTranscribePoll(VoiceNoteInfo? info) {
    final shouldPoll = info?.status == VoiceNoteStatus.transcribing;
    if (!shouldPoll) {
      _transcribePoll?.cancel();
      _transcribePoll = null;
      return;
    }
    _transcribePoll ??= Timer.periodic(const Duration(seconds: 3), (_) async {
      await logic.reloadBlocks();
    });
  }

  /// 重试转写：占位卡改回「处理中」并重新入队（原始录音一直在本地）。
  Future<void> _retryVoiceTranscription(VoiceNoteInfo info) async {
    final diaryId = logic.canvasState.diary.id;
    final ok = await PendingContentService.markPending(
      diaryId: diaryId,
      template: VoiceNoteInfo.transcribeTemplate,
      text: '${PendingContentService.pendingPrefix}正在转写录音，稍后自动写入正文…',
    );
    if (!ok) {
      toast.error(message: '找不到转写占位卡，无法重试');
      return;
    }
    await AiTaskQueueWorker.instance.submitTask(
      type: AiTaskType.voiceTranscribe,
      refId: diaryId,
      payload: info.audioFile,
    );
    await logic.reloadBlocks();
    toast.success(message: '已重新提交转写');
  }

  List<Widget> _contentSlivers(BuildContext context) {
    final padX = _contentPadX(context);

    return [
      Obx(() {
        // 注册展开/收起信号依赖：点击「展开全文/收起」后整列重建
        logic.expandTick.value;
        final blocks = logic.blockList.blocks.value;
        final diary = logic.canvasState.diary;
        if (logic.blockList.loading.value && blocks.isEmpty) {
          // 骨架屏代替居中转圈：结构先到位，内容到了再替换
          return SliverToBoxAdapter(child: CanvasSkeleton(padding: padX));
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
                      onPressed: _enterAppendMode,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('写第一张卡片'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final voiceInfo = VoiceNoteInfo.from(diary: diary, blocks: blocks);
        final isVoice = voiceInfo != null;
        // 语音笔记：源块往往为空、正文由转写结果承担，这里改为「按 Tab 呈现段落」
        final notes = isVoice
            ? <Block>[]
            : blocks.where((b) => !b.meta.isAi).toList();
        final ais = blocks
            .where((b) => b.meta.isAi)
            // 转写占位/结果卡的职责已由顶部区块承担，不再重复成卡
            .where(
              (b) =>
                  !(isVoice &&
                      b.meta.aiTemplate == VoiceNoteInfo.transcribeTemplate),
            )
            .toList();
        final slivers = <Widget>[];

        // 语音笔记正文：录音原文 ↔ 笔记内容
        if (isVoice && voiceInfo.hasText) {
          final text = _voiceTab == VoiceNoteTab.raw
              ? voiceInfo.rawText
              : voiceInfo.noteText;
          if (text.trim().isNotEmpty) {
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padX),
                sliver: SliverToBoxAdapter(
                  child: SelectableText(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.65,
                    ),
                  ),
                ),
              ),
            );
          }
        }

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

        // 「+ 追加笔记」入口：轻量文字按钮（避免大药丸抢走正文注意力）
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                notes.isNotEmpty ? padX - 8 : padX,
                notes.isNotEmpty ? 4 : 0,
                padX,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _enterAppendMode,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('追加笔记'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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

        slivers.add(SliverToBoxAdapter(child: _RelatedNotesSection(diary: diary)));
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
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  // 标题在正文首卡里已大字展示：滚动前不重复，滚过首屏后再淡入顶栏
                  title: ValueListenableBuilder<bool>(
                    valueListenable: _barTitleVisible,
                    builder: (context, visible, child) => AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: child,
                    ),
                    child: Obx(
                      () => Text(
                        logic.canvasState.diaryTitle.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                        // ① 写：内联追加 / 全屏写卡片
                        const PopupMenuItem(
                          value: 'fullscreen_append',
                          child: Text('全屏编辑（新卡片）'),
                        ),
                        const PopupMenuDivider(),
                        // ② 整理：把这条记录归档、沉淀
                        const PopupMenuItem(
                          value: 'consolidate',
                          child: Text('笔记整合'),
                        ),
                        const PopupMenuItem(
                          value: 'kb',
                          child: Text('加入知识库'),
                        ),
                        const PopupMenuItem(
                          value: 'voice',
                          child: Text('语音记录'),
                        ),
                        const PopupMenuDivider(),
                        // ③ AI 产出（抽取/技能在底部动作条，这里不重复）
                        const PopupMenuItem(
                          value: 'works',
                          child: Text('生成作品'),
                        ),
                        const PopupMenuDivider(),
                        // ④ 设置
                        const PopupMenuItem(
                          value: 'plan',
                          child: Text('抽取设置'),
                        ),
                        const PopupMenuDivider(),
                        // ⑤ 危险操作：不需要的记录直接在详情页删掉
                        const PopupMenuItem(
                          value: 'delete_diary',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Color(0xFFE53935),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '删除这条记录',
                                style: TextStyle(color: Color(0xFFE53935)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == 'consolidate') {
                          _openConsolidateEditor();
                        } else if (v == 'fullscreen_append') {
                          _openAppendEditor();
                        } else if (v == 'voice') {
                          Get.toNamed(AppRoutes.voiceRecordPage);
                        } else if (v == 'plan') {
                          _showPlanSettings(context);
                        } else if (v == 'works') {
                          _showWorksSheet(context);
                        } else if (v == 'kb') {
                          _showKbSheet(context);
                        } else if (v == 'delete_diary') {
                          _deleteCurrentDiary();
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
                // 含录音的笔记：置顶播放器 + 转写状态 + 原文/正文切换（区别于普通详情页）
                ..._voiceSlivers(context),
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
          _buildSuggestionBar(context),
          if (_appendMode) _buildAppendModeBar(context),
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
                activationTrigger: _activateInput,
                streaming: logic.isChatStreaming,
                collapsedHint: _appendMode ? '记点什么，或按住说话' : '按住输入语音',
                activeHint: _appendMode
                    ? '记点什么…回车保存为新卡片'
                    : '问问这条记录，或输入问题…',
                modelLabel: _appendMode ? '追加到笔记' : _chatModelLabel,
                voiceMode: _voiceMode,
                onToggleVoice: () => setState(() => _voiceMode = !_voiceMode),
                onLongPressStart: _startVoiceInput,
                onLongPressEnd: _stopVoiceInput,
                listening: _listening,
                onModelSelect: () => _pickChatModel(context),
                atActive: logic.chatKnowledgeBase.value != null,
                onAt: () => _pickChatKnowledge(context),
                onPlus: _showAttachmentPicker,
                onSend: (text) {
                  _aiInput.clear();
                  if (_appendMode) {
                    logic.appendNote(text);
                    _exitAppendMode();
                    toast.success(message: '已追加为新卡片');
                    return;
                  }
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

  /// 主动建议动作条（对标得到大脑的「主动」）：低打扰地给出下一步动作。
  Widget _buildSuggestionBar(BuildContext context) {
    final actions = <({String label, IconData icon, VoidCallback onTap})>[
      (
        label: '提取待办',
        icon: Icons.checklist_rounded,
        onTap: () => _showAiExtract(context),
      ),
      (
        label: '点评',
        icon: Icons.mode_comment_outlined,
        onTap: () => logic.runSkill(AiSkillType.comment),
      ),
      (
        label: '发芽',
        icon: Icons.eco_outlined,
        onTap: () => logic.runSkill(AiSkillType.sprout),
      ),
      (
        label: '拷问',
        icon: Icons.local_fire_department_outlined,
        onTap: () => logic.runSkill(AiSkillType.interrogate),
      ),
      (
        label: '打磨成稿',
        icon: Icons.auto_fix_high_rounded,
        onTap: () => logic.runSkill(AiSkillType.polish),
      ),
    ];
    return Obx(() {
      if (logic.blockList.blocks.value.isEmpty) return const SizedBox.shrink();
      final running = logic.runningAction.value;
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: _contentPadX(context)),
          itemCount: actions.length + (running.isEmpty ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            // 进行中：最前面显示运行指示器（小转圈 + 动作名），其余动作置灰防重复点击
            if (running.isNotEmpty && index == 0) {
              return Chip(
                avatar: const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: Text(
                  '正在$running…',
                  style: const TextStyle(fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
              );
            }
            final action = actions[running.isEmpty ? index : index - 1];
            return ActionChip(
              avatar: Icon(action.icon, size: 16),
              label: Text(
                action.label,
                style: const TextStyle(fontSize: 12),
              ),
              visualDensity: VisualDensity.compact,
              onPressed: running.isEmpty ? action.onTap : null,
            );
          },
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

  /// 进入/退出「追加模式」：底部输入条从「记录问答」切到「追加到笔记」，
  /// 发出去的是新卡片而不是 AI 提问（比跳全屏编辑页少两步）。
  void _enterAppendMode() {
    setState(() => _appendMode = true);
    // 展开输入条并聚焦（只 requestFocus 不会把折叠态展开）
    _activateInput.value++;
  }

  void _exitAppendMode() {
    if (!_appendMode) return;
    setState(() => _appendMode = false);
  }

  /// 追加模式提示条：明确当前输入的去向，并提供一键退出。
  Widget _buildAppendModeBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _contentPadX(context),
        0,
        _contentPadX(context),
        4,
      ),
      child: Row(
        children: [
          Icon(Icons.playlist_add_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '追加模式：输入的内容会保存为新卡片',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: _exitAppendMode,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
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
    final meta = await logic.runExclusive('提取待办', logic.runExtractPlan);
    if (!context.mounted) return;
    if (meta == null) return;
    if (meta.status == 'failed') {
      toast.info(
        message: meta.message.isEmpty ? 'AI 抽取未成功，可稍后重试' : meta.message,
      );
      return;
    }
    // 没有提取到任何待办/日程/CRM 建议：明确告知并返回
    if (meta.pendingItems.isEmpty && meta.crmProposals.isEmpty) {
      toast.info(message: '没有提取到待办或日程');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AiExtractSheet(
        meta: meta,
        diaryId: logic.canvasState.diary.id,
        noteTitle: logic.canvasState.diary.title,
      ),
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

  /// 弹出「生成作品」格式选择，把本日记合成草稿。
  void _showWorksSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '生成作品',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final format in WorksFormat.values)
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(format.label),
                  subtitle: Text(format.hint),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    logic.runWorks(format);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 加入主题知识库：列出既有知识库，多选成员关系落在主文本块 meta 上。
  Future<void> _showKbSheet(BuildContext context) async {
    final blocks = await logic.datasource.loadBlocks(logic.canvasState.diary.id);
    final primary = blocks
        .where((b) => !b.isDeleted && b.blockType == BlockType.text)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (primary.isEmpty) {
      toast.info(message: '没有可归类的文本卡片');
      return;
    }
    if (!mounted) return;
    final kbs = await RagService().listKnowledgeBases();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _KbMembershipSheet(
        block: primary.first,
        kbs: kbs,
      ),
    );
    // 关闭后刷新投影（meta 变化影响徽标）
    await logic.refreshDiary();
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

/// 智能详情页底部的「相关笔记」建议区（建议制，自动加载，点击跳转）。
class _RelatedNotesSection extends StatefulWidget {
  final Diary diary;

  const _RelatedNotesSection({required this.diary});

  @override
  State<_RelatedNotesSection> createState() => _RelatedNotesSectionState();
}

class _RelatedNotesSectionState extends State<_RelatedNotesSection> {
  List<RelatedNote>? _suggestions;

  /// 关联笔记的正文预览（标题为空时的兜底显示）
  Map<String, String> _previews = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 只关联「在库」的笔记：回收站/已删除的不参与，避免点开是空的
    final all = (await IsarUtil.getAllDiaries())
        .where((d) => d.show)
        .toList();
    _previews = {
      for (final d in all)
        d.id: d.contentText.trim().replaceAll(RegExp(r'\s+'), ' '),
    };
    // 优先语义相似（向量），失败/未配置时回退标签 + 标题重叠
    final candidates = all
        .where((d) => d.id != widget.diary.id)
        .map(
          (d) => (
            id: d.id,
            title: d.title,
            text: SemanticLinkService.embedText(d.title, d.contentText),
          ),
        )
        .toList();
    var result = await SemanticLinkService.suggest(
      diaryId: widget.diary.id,
      targetText: SemanticLinkService.embedText(
        widget.diary.title,
        widget.diary.contentText,
      ),
      candidates: candidates,
      topK: 4,
    );
    if (result.isEmpty) {
      final target = NoteSummary(
        id: widget.diary.id,
        title: widget.diary.title,
        tags: widget.diary.tags,
      );
      final others = all
          .where((d) => d.id != widget.diary.id)
          .map((d) => NoteSummary(id: d.id, title: d.title, tags: d.tags))
          .toList();
      result = AutoLinkService.suggest(target: target, all: others, topK: 4);
    }
    if (mounted) setState(() => _suggestions = result);
  }

  Future<void> _open(RelatedNote r) async {
    final d = await IsarUtil.getDiaryById(r.diaryId);
    if (d == null || !d.show) {
      // 目标笔记已被删除/进回收站：给出明确提示并刷新建议列表
      toast.info(message: '这条关联笔记已不在（可能在回收站）');
      await _load();
      return;
    }
    Bind.lazyPut(() => DiaryDetailsLogic(), tag: d.id);
    // GetX 的 preventDuplicates 默认为 true：当前就在「日记详情」路由上，
    // 再 push 同名路由会被静默忽略（真机表现为"点了没反应"），必须显式关掉
    await Get.toNamed(
      AppRoutes.diaryPage,
      arguments: [d.clone(), false],
      preventDuplicates: false,
    );
    if (mounted) await _load(); // 回来时刷新建议（可能已变化）
  }

  /// 标题为空时用正文预览兜底（很多速记没有标题，否则整行是空的）
  String _labelOf(RelatedNote r) {
    final title = r.title.trim();
    if (title.isNotEmpty) return title;
    final preview = (_previews[r.diaryId] ?? '').trim();
    if (preview.isEmpty) return '（无标题笔记）';
    return preview.length > 24 ? '${preview.substring(0, 24)}…' : preview;
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    if (suggestions == null || suggestions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('相关笔记', style: theme.textTheme.titleSmall),
          ),
          for (final r in suggestions)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.link_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              title: Text(
                _labelOf(r),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                r.similarity > 0
                    ? '相似度 ${(r.similarity * 100).round()}%'
                    : (r.sharedTags > 0 ? '共享 ${r.sharedTags} 个标签' : '标题相关'),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              onTap: () => _open(r),
            ),
        ],
      ),
    );
  }
}

/// 主题知识库成员选择（多选；成员关系存于主文本块 meta.knowledgeBaseIds）。
class _KbMembershipSheet extends StatefulWidget {
  final Block block;
  final List<KnowledgeBase> kbs;

  const _KbMembershipSheet({required this.block, required this.kbs});

  @override
  State<_KbMembershipSheet> createState() => _KbMembershipSheetState();
}

class _KbMembershipSheetState extends State<_KbMembershipSheet> {
  late final Set<String> _selected =
      KbCollectionService.parse(widget.block.meta.knowledgeBaseIds).toSet();

  Future<void> _save(String raw) async {
    widget.block.meta.knowledgeBaseIds = raw;
    await IsarUtil.updateBlock(widget.block);
  }

  Future<void> _toggle(String kbId, bool value) async {
    setState(() {
      if (value) {
        _selected.add(kbId);
      } else {
        _selected.remove(kbId);
      }
    });
    await _save(KbCollectionService.encode(_selected.toList()));
    if (mounted) toast.success(message: '已更新知识库成员');
  }

  /// AI 推荐归类：按知识库名称与笔记内容/标签的词重叠，自动加入最匹配的一个。
  Future<void> _aiRecommend() async {
    if (widget.kbs.isEmpty) {
      toast.info(message: '请先在设置创建知识库');
      return;
    }
    final text = '${widget.block.content} ${widget.block.meta.title}'.toLowerCase();
    final tokens = _tokens(text);
    KnowledgeBase? best;
    var bestScore = 0;
    for (final kb in widget.kbs) {
      final kbTokens = _tokens('${kb.name} ${kb.description}'.toLowerCase());
      final overlap = tokens.where(kbTokens.contains).toSet().length;
      if (overlap > bestScore) {
        bestScore = overlap;
        best = kb;
      }
    }
    if (best == null || bestScore == 0) {
      toast.info(message: '未找到明显相关的知识库');
      return;
    }
    _selected.add(best.id);
    await _save(KbCollectionService.encode(_selected.toList()));
    if (mounted) {
      setState(() {});
      toast.success(message: '已推荐归入「${best.name}」');
    }
  }

  static List<String> _tokens(String s) =>
      s.split(RegExp(r'[\s,，。、；;：:/#]+'))
          .map((e) => e.trim())
          .where((e) => e.length >= 2)
          .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('加入知识库', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (widget.kbs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '还没有知识库，请先在「设置 → 知识库」创建',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final kb in widget.kbs)
                      CheckboxListTile(
                        dense: true,
                        value: _selected.contains(kb.id),
                        title: Text(kb.name),
                        subtitle: kb.description.isEmpty
                            ? null
                            : Text(kb.description, maxLines: 1),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => _toggle(kb.id, v ?? false),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: widget.kbs.isEmpty ? null : _aiRecommend,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('AI 推荐归类'),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 抽取结果审核面板：展示已生成的待办/日程 + 待确认的 CRM 提案（确认后才写库）。
class _AiExtractSheet extends StatefulWidget {
  final AiExtractMeta meta;
  final String diaryId;
  final String noteTitle;

  const _AiExtractSheet({
    required this.meta,
    required this.diaryId,
    required this.noteTitle,
  });

  @override
  State<_AiExtractSheet> createState() => _AiExtractSheetState();
}

class _AiExtractSheetState extends State<_AiExtractSheet> {
  final ScheduleRepository _scheduleRepo = ScheduleRepository();
  final Map<String, Schedule> _schedules = {};

  /// 已确认创建的条目下标 → 预先生成的日程 id
  final Map<int, String> _createdIds = {};

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    for (final id in widget.meta.scheduleIds) {
      final s = await _scheduleRepo.getById(id);
      if (s != null) _schedules[id] = s;
    }
    if (mounted) setState(() {});
  }

  Future<void> _openSchedule(Schedule s) async {
    await Get.to<bool>(() => ScheduleDetailPage(editable: s));
  }

  /// 待确认条目的呈现：确认「创建」→ 打开**预填**的待办/日程创建页 →
  /// 用户改完保存才真正落库（并自动建立「日记 ↔ 待办」双向关联）。
  Widget _buildPendingItem(BuildContext context, ThemeData theme, int index) {
    final item = widget.meta.pendingItems[index];
    final created = _createdIds.containsKey(index);
    final when = (item.start ?? '').trim();
    return ListTile(
      leading: Icon(
        item.isTodo ? Icons.check_circle_outline_rounded : Icons.event_rounded,
        color: created ? theme.colorScheme.primary : null,
      ),
      title: Text(item.title),
      subtitle: Text(
        created
            ? '已创建'
            : [
                item.isTodo ? '待办' : '日程',
                if (when.isNotEmpty) when,
                if (item.floating) '浮动',
              ].join(' · '),
      ),
      dense: true,
      trailing: created
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : TextButton(
              onPressed: () => _confirmCreate(index),
              child: const Text('创建'),
            ),
    );
  }

  /// 打开预填创建页；保存成功后记录 id（供 AI 提取块与后续双向关联使用）。
  Future<void> _confirmCreate(int index) async {
    final item = widget.meta.pendingItems[index];
    final id = const Uuid().v7();
    final draft = ExtractPlanService.scheduleFromPending(
      item,
      id: id,
      diaryId: widget.diaryId,
    );
    final saved = await Get.to<bool>(
      () => ScheduleDetailPage(prefilled: draft),
    );
    if (saved != true) return;
    _createdIds[index] = id;
    _schedules[id] = draft;
    // 双向关联 + 状态回写（供详情页展示与后续审计）
    await ExtractPlanService.recordCreatedSchedule(
      diaryId: widget.diaryId,
      scheduleId: id,
    );
    if (mounted) {
      setState(() {});
      toast.success(message: '已创建${item.isTodo ? '待办' : '日程'}：${item.title}');
    }
  }

  Future<void> _createCrm(ExtractCrm crm) async {
    final fields = {
      'name': crm.name,
      ...crm.fields,
    };
    await Get.to<void>(
      () => CrmCreatePage(
        objectType: crm.type,
        title: CrmWriteService.objectLabels[crm.type] ?? crm.type,
        fields: kBaseObjectFields[crm.type] ?? const [],
        contextLabel: 'AI 提取：${widget.noteTitle}',
        initialValues: fields,
        onCreate: (data) async {
          final id = await createCrmEntity(
            repo: CrmLocalRepository(),
            objectType: crm.type,
            data: data,
          );
          if (id != null) {
            // 双向关系：日记 ↔ CRM 实体
            await IsarUtil.upsertCrmContentLinks([
              CrmContentLink()
                ..localType = CrmContentLink.localTypeDiary
                ..localId = widget.diaryId
                ..targetType = crm.type
                ..targetId = id
                ..status = CrmContentLink.statusLinked,
            ]);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = widget.meta;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ListView(
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
            if (meta.pendingItems.isNotEmpty) ...[
              const Divider(),
              Text(
                '待确认（确认后才写入待办/日程）',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < meta.pendingItems.length; i++)
                _buildPendingItem(context, theme, i),
            ],
            if (_schedules.isNotEmpty) ...[
              const Divider(),
              Text('已创建（点击编辑）', style: theme.textTheme.labelLarge),
              for (final s in _schedules.values)
                ListTile(
                  leading: const Icon(Icons.event_rounded),
                  title: Text(s.title),
                  subtitle: Text(
                    s.floating ? '浮动' : '${s.day.month}月${s.day.day}日',
                  ),
                  dense: true,
                  onTap: () => _openSchedule(s),
                ),
            ],
            if (meta.crmProposals.isNotEmpty) ...[
              const Divider(),
              Text('CRM 建议（预填新建，审核后入库）', style: theme.textTheme.labelLarge),
              for (final crm in meta.crmProposals)
                ListTile(
                  leading: const Icon(Icons.business_rounded),
                  title: Text(crm.name.isNotEmpty ? crm.name : '未命名'),
                  subtitle: Text(CrmWriteService.objectLabels[crm.type] ?? crm.type),
                  dense: true,
                  trailing: IconButton(
                    tooltip: '预填新建',
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () => _createCrm(crm),
                  ),
                ),
            ],
            if (_schedules.isEmpty &&
                meta.crmProposals.isEmpty &&
                meta.pendingItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('未抽取到待办/日程或 CRM 建议'),
              ),
          ],
        ),
      ),
    );
  }
}
