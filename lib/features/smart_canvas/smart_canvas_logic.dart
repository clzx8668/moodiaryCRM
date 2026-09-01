import 'dart:async';

import 'package:get/get.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_service.dart';
import 'package:moodiary/features/ai/extract/ai_extract_meta.dart';
import 'package:moodiary/features/ai/extract/extract_cleanup_service.dart';
import 'package:moodiary/features/ai/extract/extract_plan_service.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/ai/tool_executor.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/widgets/crm_write_confirm_card.dart';
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

  /// 展开/收起变更信号：Obx 列表依赖此信号重建
  /// （RxSet.contains 不注册 Obx 依赖，需显式信号驱动）
  final RxInt expandTick = 0.obs;

  /// 卡片折叠阈值（超过则默认折叠）
  static const int collapseThreshold = 500;

  bool _streamCancelRequested = false;
  RxBool chatStreaming = false.obs;
  String? _chatStreamingBlockId;
  StreamSubscription<dynamic>? _syncSub;

  /// 详情页 AI 交流进行中（底部输入框显示停止）。
  bool get isChatStreaming => chatStreaming.value;

  /// 当前正在流式的对话块 id（用于气泡流式态）。
  String? get chatStreamingBlockId => _chatStreamingBlockId;

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
    _syncSub = SyncEventService.instance.syncEvents.listen((event) {
      onSyncEvent(
        phase: event.phase.name,
        progress: event.progress,
      );
    });
  }

  @override
  void onClose() {
    _syncSub?.cancel();
    super.onClose();
  }

  Future<void> init() async {
    blockList.loading.value = true;
    try {
      final fresh = await datasource.loadDiary(canvasState.diary.id);
      if (fresh != null) {
        _applyDiary(fresh);
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

  /// 重新加载当前日记并刷新 AppBar 标题（追加/编辑后标题变化即时生效）。
  Future<void> refreshDiary() async {
    final fresh = await datasource.loadDiary(canvasState.diary.id);
    if (fresh == null) return;
    _applyDiary(fresh);
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
        await SyncLogService.instance.write(
          level: SyncLogLevel.error,
          operation: 'ai',
          target: 'template',
          detail: '模板【${AiTemplates.label(template)}】AI 处理失败：${chunk.error}',
        );
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

  /// 详情页 AI 交流：瀑布流式对话，**持久化为 source=ai 块**（role=user/assistant）。
  ///
  /// [attachments]：📎 附加知识文本列表（文件/笔记/CRM），注入 system 上下文。
  Future<void> sendChat(
    String text, {
    List<String> attachments = const [],
  }) async {
    final q = text.trim();
    if (q.isEmpty) return;
    if (chatStreaming.value) {
      toast.info(message: '正在生成，请稍候');
      return;
    }
    await loadAiProvider();
    if (!aiProvider.isConfigured) {
      toast.info(message: 'AI 未配置，请在设置中填写 API Key');
      return;
    }
    final user = await datasource.createChatBlock(
      diary: canvasState.diary,
      role: 'user',
      content: q,
    );
    final assistant = await datasource.createChatBlock(
      diary: canvasState.diary,
      role: 'assistant',
      content: '',
    );
    blockList.blocks.addAll([user, assistant]);
    await _streamChatBlock(assistant, userQuestion: q, attachments: attachments);
  }

  /// 针对某条助手块重新生成。
  Future<void> regenerateAnswer(String blockId) async {
    if (chatStreaming.value) {
      toast.info(message: '正在生成，请稍候');
      return;
    }
    final assistant = blockList.byId(blockId);
    if (assistant == null) return;
    final userQuestion = _prevUserQuestion(blockId);
    if (userQuestion.isEmpty) return;
    await loadAiProvider();
    if (!aiProvider.isConfigured) {
      toast.info(message: 'AI 未配置，请在设置中填写 API Key');
      return;
    }
    assistant
      ..content = ''
      ..streamBuffer = ''
      ..updatedAt = DateTime.now();
    await datasource.saveBlock(assistant);
    blockList.replace(assistant);
    await _streamChatBlock(assistant, userQuestion: userQuestion);
  }

  String _prevUserQuestion(String blockId) {
    final blocks = blockList.blocks.value
        .where((b) => b.meta.isAi && b.meta.role.isNotEmpty)
        .toList();
    final sorted = [...blocks]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = sorted.indexWhere((b) => b.id == blockId);
    for (var i = idx - 1; i >= 0; i--) {
      if (sorted[i].meta.role == 'user') return sorted[i].content;
    }
    return '';
  }

  Future<void> _streamChatBlock(
    Block assistant, {
    required String userQuestion,
    List<String> attachments = const [],
  }) async {
    chatStreaming.value = true;
    _chatStreamingBlockId = assistant.id;
    await SyncLogService.instance.write(
      level: SyncLogLevel.info,
      operation: 'ai',
      target: 'chat',
      detail: '详情页 AI 交流开始：$userQuestion',
    );
    final chatTurns = blockList.blocks.value
        .where((b) => b.meta.isAi && b.meta.role.isNotEmpty)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    // System：附加知识注入
    var system = '你是用户的智能记录助手。请结合上下文，用简洁、结构化的 Markdown 回答。';
    if (attachments.isNotEmpty) {
      final parts = [
        for (var i = 0; i < attachments.length; i++) '[资料 ${i + 1}]\n${attachments[i]}',
      ];
      system += '\n\n用户附加了以下参考资料，请优先参考：\n${parts.join('\n\n')}';
    }

    // M4：工具协商（单轮，失败静默降级普通对话）
    try {
      final executor = ToolExecutor()
        ..onCrmWriteConfirm = showCrmWriteConfirmDialog;
      final turns = [
        for (final b in chatTurns)
          if ((b.meta.role == 'user' || b.meta.role == 'assistant') &&
              b.content.trim().isNotEmpty)
            AiChatMessage(role: b.meta.role, content: b.content),
      ];
      final completion = await aiProvider.completeChat(
        [
          AiChatMessage(role: 'system', content: system),
          ...turns,
        ],
        tools: executor.toolDefs,
      );
      if (completion.toolCalls.isNotEmpty) {
        final toolParts = <String>[];
        for (final call in completion.toolCalls) {
          toolParts.add(
            '工具「${call.name}」返回：\n${await executor.execute(call)}',
          );
        }
        system += '\n\n【已调用工具，请基于工具结果回答并注明来源】\n'
            '${toolParts.join('\n\n')}';
      }
    } catch (_) {
      // 工具协商失败不影响普通对话
    }

    final history = <AiChatMessage>[
      AiChatMessage(role: 'system', content: system),
      for (final b in chatTurns)
        if ((b.meta.role == 'user' || b.meta.role == 'assistant') &&
            b.content.trim().isNotEmpty)
          AiChatMessage(role: b.meta.role, content: b.content),
    ];
    var acc = '';
    try {
      await for (final chunk in aiProvider.streamChat(history)) {
        if (_streamCancelRequested) break;
        if (chunk.error != null) {
          assistant.content = acc;
          await datasource.saveBlock(assistant);
          blockList.replace(assistant);
          toast.error(message: chunk.error!);
          return;
        }
        acc += chunk.text;
        assistant.content = acc;
        if (acc.length % 50 < chunk.text.length) {
          await datasource.persistStreamBuffer(assistant, acc);
          blockList.replace(assistant);
        }
        if (chunk.done) break;
      }
    } finally {
      chatStreaming.value = false;
      _chatStreamingBlockId = null;
    }

    if (_streamCancelRequested) {
      _streamCancelRequested = false;
      if (acc.isEmpty) {
        await datasource.softDeleteBlock(assistant.id);
        blockList.remove(assistant.id);
      } else {
        await datasource.saveBlock(assistant);
        blockList.replace(assistant);
      }
      toast.info(message: '已停止生成');
      return;
    }

    if (acc.trim().isEmpty) {
      await datasource.softDeleteBlock(assistant.id);
      blockList.remove(assistant.id);
      toast.info(message: 'AI 未返回内容');
      return;
    }
    assistant
      ..content = acc.trim()
      ..streamBuffer = ''
      ..streamComplete = true
      ..updatedAt = DateTime.now();
    await datasource.saveBlock(assistant);
    blockList.replace(assistant);
  }

  /// LLM 模型选择回调（预留：打开模型选择）。
  void pickChatModel() {
    toast.info(message: '模型选择接入中');
  }

  /// @ 知识库回调（预留）。
  void pickChatKnowledge() {
    toast.info(message: '@ 知识库接入中');
  }

  /// 待办勾选
  Future<void> toggleTodo(Block block) async {
    await datasource.toggleTodo(block);
    blockList.replace(block);
  }

  /// 软删除卡片并刷新聚合投影
  Future<void> deleteBlock(Block block) async {
    await datasource.softDeleteBlock(block.id);
    // 双向联动：级联清理该块抽取生成的日程
    await ExtractCleanupService().onBlockDeleted(block);
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
      _applyDiary(fresh);
    }
  }

  /// 手动「去口语化」：改写并写入 metaJson（原文保留），随后局部刷新。
  Future<void> cleanBlockColloquial(Block block) async {
    try {
      final ok = await DeColoquialService.cleanBlock(block);
      if (!ok) {
        toast.info(message: '内容无需处理，或 AI 未配置 / 校验未通过');
        return;
      }
      toast.success(message: '已生成去口语化版本（原文保留）');
      await reloadBlock(block.id);
    } catch (e) {
      toast.error(message: '去口语化失败：$e');
    }
  }

  /// 一键还原原文（清除清洗稿）。
  Future<void> restoreBlockColloquial(Block block) async {
    try {
      await DeColoquialService.restoreBlock(block);
      toast.info(message: '已恢复原文');
      await reloadBlock(block.id);
    } catch (e) {
      toast.error(message: '还原失败：$e');
    }
  }

  /// 对日记主文本块执行 extract_plan，返回写入的 [AiExtractMeta]（无则 null）。
  Future<AiExtractMeta?> runExtractPlan() async {
    try {
      final result = await ExtractPlanService.processDiary(canvasState.diary.id);
      await reloadBlocks();
      final blocks = await datasource.loadBlocks(canvasState.diary.id);
      for (final b in blocks) {
        final meta = AiExtractMeta.read(b);
        if (meta != null) return meta;
      }
      if (result == null) {
        toast.info(message: 'AI 未配置或未抽取到内容');
      }
      return null;
    } catch (e) {
      toast.error(message: 'AI 抽取失败：$e');
      return null;
    }
  }

  /// 应用最新集合：替换当前日记并通知元信息区重绘（标题 + 心情等）。
  void _applyDiary(Diary fresh) {
    canvasState.diary = fresh;
    canvasState.diaryTitle.value = fresh.title;
    canvasState.diaryRevision.value++;
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
    expandTick.value++;
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
  Future<AiChatCompletion> completeChat(
    List<AiChatMessage> messages, {
    List<AiToolDef>? tools,
  }) async {
    throw StateError('AI Provider 未初始化');
  }

  @override
  Future<List<double>> embed(String text) async {
    throw StateError('AI Provider 未初始化');
  }
}
