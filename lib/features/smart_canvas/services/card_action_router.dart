import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/smart_canvas/editors/entity_editor_page.dart';
import 'package:moodiary/features/smart_canvas/smart_canvas_logic.dart';
import 'package:moodiary/features/smart_canvas/services/canvas_datasource.dart';
import 'package:moodiary/pages/edit/edit_arguments.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 卡片点击路由（策略模式）：文档卡 → Markdown 编辑器，实体卡 → 表单页，
/// 待办 → 原地勾选，图片 → 全屏预览，图表 → 查看。
///
/// 新增卡片类型只需在 [cardActionRouter] 注册一行。
abstract class CardAction {
  Future<void> execute(
    BuildContext context,
    SmartCanvasLogic logic,
    Block block,
  );
}

class MarkdownEditAction implements CardAction {
  const MarkdownEditAction();

  @override
  Future<void> execute(
    BuildContext context,
    SmartCanvasLogic logic,
    Block block,
  ) async {
    final diary = await CanvasDatasource().loadDiary(block.diaryId);
    if (diary == null) {
      toast.error(message: '所属日记不存在或已删除');
      return;
    }
    final changed = await Get.toNamed(
      AppRoutes.editPage,
      arguments: EditArguments(
        diary: diary.clone(),
        blockId: block.id,
        initialContent: block.content,
      ),
    );
    if (changed == 'changed') {
      await logic.reloadBlock(block.id);
    }
  }
}

class EntityEditAction implements CardAction {
  const EntityEditAction();

  @override
  Future<void> execute(
    BuildContext context,
    SmartCanvasLogic logic,
    Block block,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EntityEditorPage(
          payload: EntityEditPayload(
            diaryId: block.diaryId,
            blockId: block.id,
          ),
        ),
      ),
    );
    if (changed == true) {
      await logic.reloadBlock(block.id);
    }
  }
}

class TodoToggleAction implements CardAction {
  const TodoToggleAction();

  @override
  Future<void> execute(
    BuildContext context,
    SmartCanvasLogic logic,
    Block block,
  ) async {
    await logic.toggleTodo(block);
  }
}

class ImagePreviewAction implements CardAction {
  const ImagePreviewAction();

  @override
  Future<void> execute(
    BuildContext context,
    SmartCanvasLogic logic,
    Block block,
  ) async {
    final name = block.content.trim();
    if (name.isEmpty) return;
    final path = FileUtil.getRealPath('image', name);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartViewAction implements CardAction {
  const ChartViewAction();

  @override
  Future<void> execute(
    BuildContext context,
    SmartCanvasLogic logic,
    Block block,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('图表数据'),
        content: SingleChildScrollView(
          child: SelectableText(block.content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class AiStreamAction implements CardAction {
  const AiStreamAction();

  @override
  Future<void> execute(
    BuildContext context,
    SmartCanvasLogic logic,
    Block block,
  ) async {
    // 流式/对话卡的交互集中在尾部按钮（停止/保留/重跑），点击卡片本身无动作。
  }
}

/// 类型 → 动作注册表
final Map<BlockType, CardAction> cardActionRouter = {
  BlockType.text: const MarkdownEditAction(),
  BlockType.code: const MarkdownEditAction(),
  BlockType.smartEntity: const EntityEditAction(),
  BlockType.todo: const TodoToggleAction(),
  BlockType.image: const ImagePreviewAction(),
  BlockType.chart: const ChartViewAction(),
  BlockType.aiStream: const AiStreamAction(),
};

/// 未知类型回退：按 Markdown 编辑
CardAction resolveCardAction(Block block) {
  return cardActionRouter[block.blockType] ?? const MarkdownEditAction();
}
