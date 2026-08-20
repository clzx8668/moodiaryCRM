import 'dart:async';

import 'package:get/get.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/smart_canvas/services/canvas_datasource.dart';
import 'package:moodiary/features/smart_canvas/states/block_list_state.dart';
import 'package:moodiary/features/smart_canvas/states/canvas_state.dart';
import 'package:moodiary/features/smart_canvas/states/edit_state.dart';
import 'package:moodiary/features/smart_canvas/states/streaming_state.dart';
import 'package:moodiary/features/smart_canvas/states/sync_state.dart';
import 'package:moodiary/features/sync_events/sync_event_service.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/utils/notice_util.dart';

/// SmartCanvasPage 协调者：组合五层状态，不写具体页面渲染。
///
/// 架构文档 6.2：BlockList/Streaming/Edit/Search/Sync 各自独立；
/// 本类只做编排（加载、追加、AI 生命周期、编辑回写）。
class SmartCanvasLogic extends GetxController {
  final CanvasState canvasState = CanvasState();
  final BlockListState blockList = BlockListState();
  final StreamingState streaming = StreamingState();
  final EditState edit = EditState();
  final SyncState sync = SyncState();

  late final CanvasDatasource datasource;
  late AiProvider aiProvider;

  /// 展开的卡片 id 集合（折叠策略）
  final Set<String> expandedIds = <String>{};

  /// 卡片折叠阈值（超过则默认折叠）
  static const int collapseThreshold = 500;

  bool _streamCancelRequested = false;

  SmartCanvasLogic({
    CanvasDatasource? datasource,
    AiProvider? aiProvider,
  }) {
    this.datasource = datasource ?? CanvasDatasource();
    this.aiProvider = aiProvider ?? const UnconfiguredAiProvider();
  }

  /// 异步初始化真实 Provider（避免构造期读安全存储）
  Future<void> loadAiProvider() async {
    if (aiProvider is UnconfiguredAiProvider) {
      aiProvider = await AiProviderFactory.load();
    }
  }

  @override
  void onInit() {
    super.onInit();
    _subscribeSyncEvents();
    unawaited(init());
  }

  void _subscribeSyncEvents() {
    SyncEventService.instance.syncEvents.listen((event) {
      onSyncEvent(
        phase: event.phase.name,
        progress: event.progress,
      );
    });
  }

  Future<void> init() async {
    blockList.loading.value = true;
    try {
      final fresh = await datasource.loadDiary(canvasState.diary.id);
      if (fresh != null) {
        canvasState.diary = fresh;
        canvasState.diaryTitle.value = fresh.title;
      }
      await datasource.ensureInitialBlock(canvasState.diary);
      await reloadBlocks();
      blockList.initialized.value = true;
      final incomplete = blockList.blocks
          .where(
            (b) =>
                b.blockType == BlockType.aiStream &&
                !b.streamComplete &&
                b.streamBuffer.isNotEmpty,
          )
          .length;
      if (incomplete > 0) {
        toast.info(message: '存在 $incomplete 张未完成的 AI 卡片，可点击「继续生成」');
      }
    } catch (e) {
      toast.error(message: '详情页加载失败：$e');
    } finally {
      blockList.loading.value = false;
    }
  }

  Future<void> reloadBlocks() async {
    final blocks = await datasource.loadBlocks(canvasState.diary.id);
    blockList.blocks.assignAll(blocks);
  }

  /// 追加笔记（无模板 = 纯追加；带模板 = 追加后触发 AI 处理）
  Future<void> appendNote(String text, {String template = ''}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final block = await datasource.appendNote(
        diary: canvasState.diary,
        text: trimmed,
        template: template,
      );
      blockList.blocks.add(block);
      if (template.isNotEmpty) {
        await runAiTemplate(block, template);
      }
    } catch (e) {
      toast.error(message: '追加失败：$e');
    }
  }

  /// AI 模板处理完整生命周期：创建流式卡 → 流式渲染 → 转正。
  Future<void> runAiTemplate(Block source, String template) async {
    final aiBlock = await datasource.createAiStreamBlock(
      diary: canvasState.diary,
      template: template,
      sourceContent: source.content,
    );
    blockList.blocks.add(aiBlock);
    await _streamIntoBlock(
      aiBlock,
      sourceContent: source.content,
      template: template,
    );
  }

  /// 断点恢复（P2.9）：复用未完成的 aiStream 卡片继续生成。
  ///
  /// 源内容来自 meta.sourceContent（创建时快照）；缺失时回退 streamBuffer。
  Future<void> resumeAiBlock(Block block) async {
    if (block.blockType != BlockType.aiStream || block.streamComplete) return;
    final meta = block.meta;
    final source = meta.sourceContent.isNotEmpty
        ? meta.sourceContent
        : block.streamBuffer.isNotEmpty
        ? block.streamBuffer
        : '';
    if (source.isEmpty) {
      toast.info(message: '缺少源内容，无法继续生成');
      return;
    }
    final template = meta.aiTemplate.isEmpty ? AiTemplates.summary : meta.aiTemplate;
    await _streamIntoBlock(
      block,
      sourceContent: source,
      template: template,
    );
  }

  /// 流式核心：把 AI 输出灌入指定 aiStream 卡片，完成后按模板转正。
  Future<void> _streamIntoBlock(
    Block aiBlock, {
    required String sourceContent,
    required String template,
  }) async {
    await loadAiProvider();
    if (!aiProvider.isConfigured) {
      toast.info(message: 'AI 未配置，请在设置中填写 API Key');
      return;
    }
    streaming.start(aiBlock.id);
    await SyncLogService.instance.write(
      level: SyncLogLevel.info,
      operation: 'ai',
      target: 'template',
      detail: '模板【${AiTemplates.label(template)}】AI 处理开始（block ${aiBlock.id}）',
    );

    await for (final chunk in aiProvider.streamTemplate(
      content: sourceContent,
      template: template,
    )) {
      if (_streamCancelRequested) break;
      if (chunk.error != null) {
        streaming.stop();
        toast.error(message: chunk.error!);
        return;
      }
      streaming.append(chunk.text);
      aiBlock.streamBuffer = streaming.buffer.value;
      if (streaming.sincePersist >= 50) {
        await datasource.persistStreamBuffer(aiBlock, streaming.buffer.value);
        streaming.resetPersistCounter();
        blockList.replace(aiBlock);
      }
      if (chunk.done) break;
    }
    streaming.stop();

    if (_streamCancelRequested) {
      _streamCancelRequested = false;
      if (streaming.buffer.value.isNotEmpty) {
        await datasource.persistStreamBuffer(aiBlock, streaming.buffer.value);
        blockList.replace(aiBlock);
      }
      toast.info(message: 'AI 处理已停止，已保存已生成部分');
      return;
    }

    final result = streaming.buffer.value.trim();
    if (result.isEmpty) {
      toast.info(message: 'AI 未返回内容');
      return;
    }
    final targetType =
        template == AiTemplates.todo ? BlockType.todo : BlockType.text;
    final content =
        template == AiTemplates.todo ? todoListFromText(result) : result;
    final promoted = await datasource.promoteAiBlock(
      block: aiBlock,
      targetType: targetType,
      content: content,
    );
    blockList.replace(promoted);
    toast.success(message: 'AI【${AiTemplates.label(template)}】处理完成');
  }

  /// 把 AI 输出的任务清单整理为 todo Block 内容
  /// 把 AI 输出的任务清单整理为 todo Block 内容（公开供测试）
  static String todoListFromText(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '- [ ] ';
    return lines
        .map((l) => RegExp(r'^- \[[ xX]\]').hasMatch(l) ? l : '- [ ] $l')
        .join('\n');
  }

  /// 文本卡 → 待办卡（手动转正）
  Future<void> convertToTodo(Block block) async {
    if (block.blockType == BlockType.todo) return;
    final lines = block.content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final content = lines
        .map((l) => RegExp(r'^- \[[ xX]\]').hasMatch(l) ? l : '- [ ] $l')
        .join('\n');
    final converted = await datasource.promoteAiBlock(
      block: block,
      targetType: BlockType.todo,
      content: content,
    );
    blockList.replace(converted);
  }

  /// 待办勾选
  Future<void> toggleTodo(Block block) async {
    await datasource.toggleTodo(block);
    blockList.replace(block);
  }

  /// 软删除卡片并刷新聚合投影
  Future<void> deleteBlock(Block block) async {
    await datasource.softDeleteBlock(block.id);
    blockList.remove(block.id);
    expandedIds.remove(block.id);
    await datasource.refreshDiaryProjection(canvasState.diary);
  }

  /// 编辑保存后局部刷新（Markdown 编辑器 / 实体表单返回）
  Future<void> reloadBlock(String blockId) async {
    final block = await datasource.loadBlock(blockId);
    if (block != null) {
      blockList.replace(block);
    }
    final fresh = await datasource.loadDiary(canvasState.diary.id);
    if (fresh != null) {
      canvasState.diary = fresh;
      canvasState.diaryTitle.value = fresh.title;
    }
  }

  /// AI 卡片"保留为对话卡"（不再转正，streamComplete 标记完成）
  Future<void> keepAsChatCard(Block block) async {
    block
      ..streamComplete = true
      ..content = streaming.buffer.value.isNotEmpty
          ? streaming.buffer.value
          : block.streamBuffer
      ..updatedAt = DateTime.now();
    await datasource.saveBlock(block);
    blockList.replace(block);
  }

  bool isExpanded(Block block) {
    if (block.blockType != BlockType.text && block.blockType != BlockType.aiStream) {
      return true;
    }
    if (expandedIds.contains(block.id)) return true;
    return block.content.length < collapseThreshold;
  }

  void toggleExpand(Block block) {
    if (expandedIds.contains(block.id)) {
      expandedIds.remove(block.id);
    } else {
      expandedIds.add(block.id);
    }
    update(['expand:${block.id}']);
  }

  void onSyncEvent({required String phase, double progress = 0, String error = ''}) {
    sync.onEvent(phase: phase, progress: progress, error: error);
  }

  /// 取消当前 AI 流式处理
  void cancelStreaming() {
    _streamCancelRequested = true;
  }
}

/// 未配置占位 Provider（构造期使用，init 后由真实实现替换）
class UnconfiguredAiProvider implements AiProvider {
  const UnconfiguredAiProvider();

  @override
  bool get isConfigured => false;

  @override
  Stream<AiChunk> streamTemplate({
    required String content,
    required String template,
  }) {
    return Stream.value(AiChunk.error('AI Provider 未初始化'));
  }

  @override
  Stream<AiChunk> streamChat(List<AiChatMessage> messages) {
    return Stream.value(AiChunk.error('AI Provider 未初始化'));
  }

  @override
  Future<List<double>> embed(String text) async {
    throw StateError('AI Provider 未初始化');
  }
}
