import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/mood_icon/mood_icon_view.dart';
import 'package:moodiary/features/ai/ai_config.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/smart_canvas/services/append_input_bar.dart';
import 'package:moodiary/features/smart_canvas/services/card_action_router.dart';
import 'package:moodiary/features/smart_canvas/smart_canvas_logic.dart';
import 'package:moodiary/features/smart_canvas/widgets/smart_card.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/src/rust/api/ffi_api.dart' as rust_ffi;
import 'package:moodiary/utils/notice_util.dart';

/// 中间详情页（SmartCanvasPage）：智能卡片工作台。
///
/// 结构：SliverAppBar（日记元信息） + 卡片栈 + 底部常驻追加输入条。
/// 交互：点卡片按类型路由（CardActionRouter），卡片菜单触发 AI 处理。
class SmartCanvasPage extends StatefulWidget {
  const SmartCanvasPage({super.key});

  @override
  State<SmartCanvasPage> createState() => _SmartCanvasPageState();
}

class _SmartCanvasPageState extends State<SmartCanvasPage> {
  late final String _tag;
  late final SmartCanvasLogic logic;

  @override
  void initState() {
    super.initState();
    _tag = (Get.arguments[0] as Diary).id;
    logic = Get.isRegistered<SmartCanvasLogic>(tag: _tag)
        ? Get.find<SmartCanvasLogic>(tag: _tag)
        : Get.put(SmartCanvasLogic(), tag: _tag);
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
              child: Text('AI 处理模板', style: Theme.of(context).textTheme.titleMedium),
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

  Future<void> _showAiSettings() async {
    final config = await AiConfig.load();
    if (!mounted) return;
    final baseUrl = TextEditingController(text: config.baseUrl);
    final apiKey = TextEditingController(text: config.apiKey);
    final model = TextEditingController(text: config.model);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI 设置（OpenAI 兼容）'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baseUrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.deepseek.com/v1',
                ),
              ),
              TextField(
                controller: apiKey,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'API Key'),
              ),
              TextField(
                controller: model,
                decoration: const InputDecoration(
                  labelText: '模型',
                  hintText: 'deepseek-chat',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await AiConfig.save(
                baseUrl: baseUrl.text.trim(),
                apiKey: apiKey.text.trim(),
                model: model.text.trim(),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) {
      toast.success(message: 'AI 设置已保存');
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
            DateFormat.yMMMd().add_Hms().format(diary.time),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          for (final tag in diary.tags.take(6))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                label: Text(tag),
                labelStyle: const TextStyle(fontSize: 11),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardList(BuildContext context) {
    return Obx(() {
      final blocks = logic.blockList.blocks;
      if (blocks.isEmpty) {
        if (logic.blockList.loading.value) {
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Text(
              '暂无卡片，在下方输入框追加笔记',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }
      return Column(
        children: [
          for (final block in blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCard(context, block),
            ),
        ],
      );
    });
  }

  Widget _buildCard(BuildContext context, Block block) {
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
      expanded: expanded,
      streamBuffer: streamBuffer,
      isStreaming: isStreaming,
      onTap: () => resolveCardAction(block).execute(context, logic, block),
      onToggleExpand: () => logic.toggleExpand(block),
      onToggleTodo: (b) => logic.toggleTodo(b),
      onAi: () => _showAiTemplateSheet(block),
      onConvertTodo: () => logic.convertToTodo(block),
      onCopy: () {
        Clipboard.setData(
          ClipboardData(text: block.content),
        );
        toast.success(message: '已复制卡片内容');
      },
      onStop: isStreaming ? logic.cancelStreaming : null,
      onKeepAsChat: block.streamComplete
          ? () => logic.keepAsChatCard(block)
          : null,
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
                      logic.canvasState.diary.title,
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
                          value: 'ai_settings',
                          child: Text('AI 设置'),
                        ),
                        const PopupMenuItem(
                          value: 'edit_diary',
                          child: Text('编辑整篇日记'),
                        ),
                        const PopupMenuItem(
                          value: 'demo_sync',
                          child: Text('测试同步事件流'),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == 'ai_settings') {
                          _showAiSettings();
                        } else if (v == 'edit_diary') {
                          _openWholeDiaryEditor();
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
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: _buildCardList(context)),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
          AppendInputBar(
            onSend: (text, template) => logic.appendNote(text, template: template),
          ),
        ],
      ),
    );
  }

  void _openWholeDiaryEditor() {
    final diary = logic.canvasState.diary;
    Get.toNamed(
      AppRoutes.editPage,
      arguments: diary.clone(),
    )?.then((result) {
      if (result == 'changed') {
        logic.init();
      }
    });
  }
}
