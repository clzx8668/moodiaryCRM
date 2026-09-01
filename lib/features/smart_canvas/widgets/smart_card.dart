import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_meta.dart';
import 'package:moodiary/features/block/block_visuals.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/voice/voice_media_player.dart';
import 'package:moodiary/features/voice/voice_record_meta.dart';
import 'package:moodiary/features/smart_canvas/widgets/chart_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/code_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/entity_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/image_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/streaming_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/text_card.dart';
import 'package:moodiary/features/smart_canvas/widgets/todo_card.dart';

/// 智能卡片容器（闪念贝壳式）：顶部色条/「已生成卡片」标签 + 内容 + 底部标签/操作。
///
/// - [isAi] = false：笔记区卡片（色条 + 时间 + 内容 + #标签 + 复制/菜单）；
/// - [isAi] = true ：AI 交互区卡片（「已生成卡片：<模板>」 + 标题 + 内容 + 查看更多/复制/删除）。
/// 点击行为由 [onTap] 通过 CardActionRouter 注入，本组件只负责结构。
class SmartCard extends StatelessWidget {
  final Block block;
  final Diary diary;
  final bool expanded;
  final String streamBuffer;
  final bool isStreaming;

  /// 是否属于 AI 交互区（meta.source == ai）
  final bool isAi;

  final VoidCallback? onTap;
  final VoidCallback? onToggleExpand;
  final void Function(Block block)? onToggleTodo;
  final VoidCallback? onAi;
  final VoidCallback? onConvertTodo;
  final VoidCallback? onCopy;
  final VoidCallback? onStop;
  final VoidCallback? onKeepAsChat;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;
  final Future<void> Function()? onCleanColloquial;
  final Future<void> Function()? onRestoreColloquial;

  const SmartCard({
    super.key,
    required this.block,
    required this.diary,
    required this.expanded,
    required this.streamBuffer,
    required this.isStreaming,
    required this.isAi,
    this.onTap,
    this.onToggleExpand,
    this.onToggleTodo,
    this.onAi,
    this.onConvertTodo,
    this.onCopy,
    this.onStop,
    this.onKeepAsChat,
    this.onResume,
    this.onDelete,
    this.onCleanColloquial,
    this.onRestoreColloquial,
  });

  String get _relativeTime {
    final diff = DateTime.now().difference(block.updatedAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return DateFormat('M月d日 HH:mm').format(block.updatedAt);
  }

  String get _aiLabel {
    if (block.meta.aiTemplate.isNotEmpty) {
      return AiTemplates.label(block.meta.aiTemplate);
    }
    return blockTypeLabel(block.blockType);
  }

  String get _tagText {
    if (diary.tags.isNotEmpty) {
      return diary.tags.take(3).map((t) => '#$t').join('  ');
    }
    if (block.meta.source == BlockMeta.sourceAi) return '#AI';
    return '#${blockTypeLabel(block.blockType)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card.filled(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: blockBackground(block.blockType, colorScheme),
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (details) =>
            _openContextMenu(context, details.globalPosition),
        hoverColor: colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              isAi ? _buildAiHead(context) : _buildNoteHead(context),
              const SizedBox(height: 10),
              _buildBody(context),
              const SizedBox(height: 2),
              _buildFoot(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 笔记区头部：类型色条 + 来源徽标 + 时间。
  Widget _buildNoteHead(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meta = block.meta;
    return Row(
      children: [
        Text(
          _relativeTime,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (meta.source != BlockMeta.sourceInitial) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              blockSourceLabel(meta.source),
              style: TextStyle(fontSize: 10, color: colorScheme.onSurface),
            ),
          ),
        ],
        ..._statusIcons(colorScheme),
      ],
    );
  }

  /// AI 区头部：「已生成卡片：<模板>」+ 标题。
  Widget _buildAiHead(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = block.meta.title.isNotEmpty ? block.meta.title : _aiLabel;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已生成卡片：$_aiLabel',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Text(
          _relativeTime,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        ..._statusIcons(colorScheme),
      ],
    );
  }

  /// 待同步 / 冲突轻提示图标。
  List<Widget> _statusIcons(ColorScheme colorScheme) {
    final meta = block.meta;
    return [
      if (meta.isPending)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: '待同步',
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      if (meta.isConflict)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: '冲突',
            child: Icon(
              Icons.sync_problem_rounded,
              size: 13,
              color: colorScheme.error,
            ),
          ),
        ),
    ];
  }

  Widget _buildFoot(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isAi) {
      return Row(
        children: [
          if (isStreaming)
            _FootIcon(
              icon: Icons.stop_circle_outlined,
              tooltip: '停止',
              color: colorScheme.error,
              onTap: onStop,
            )
          else if (block.blockType == BlockType.aiStream &&
              !block.streamComplete)
            _FootIcon(
              icon: Icons.play_circle_outline_rounded,
              tooltip: '继续生成',
              onTap: onResume,
            )
          else
            // 展开/收起统一由正文卡片（TextCard）内的按钮控制，避免重复入口
            const SizedBox.shrink(),
          const Spacer(),
          _FootIcon(
            icon: Icons.copy_rounded,
            tooltip: '复制',
            onTap: onCopy,
          ),
          _FootIcon(
            icon: Icons.delete_outline_rounded,
            tooltip: '删除',
            color: colorScheme.error,
            onTap: onDelete,
          ),
        ],
      );
    }

    // 笔记区底部：左 #标签，右 复制 + ⋮ 菜单
    final hasClean = DeColoquialMeta.has(block);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (hasClean) ...[
                _cleanChip(context, colorScheme),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  _tagText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        _FootIcon(
          icon: Icons.copy_rounded,
          tooltip: '复制',
          onTap: onCopy,
        ),
        PopupMenuButton<String>(
          tooltip: '更多',
          padding: EdgeInsets.zero,
          iconSize: 16,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(28, 26),
            maximumSize: const Size(28, 26),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: _dispatchMenu,
          itemBuilder: (_) => _menuEntries(),
        ),
      ],
    );
  }

  /// 「已去口语化」小标识：点击查看原文/清洗稿并可还原。
  Widget _cleanChip(BuildContext context, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _showCleanResult(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_fix_high_rounded, size: 11),
            const SizedBox(width: 3),
            Text(
              '去口语化',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCleanResult(BuildContext context) async {
    final meta = DeColoquialMeta.read(block);
    if (meta == null) return;
    await Get.dialog<void>(
      AlertDialog(
        title: const Text('去口语化结果'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cleanBlock(context, '原文', meta.original),
              const Divider(height: 20),
              _cleanBlock(context, '已清洗', meta.cleaned),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await onRestoreColloquial?.call();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('恢复原文'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _cleanBlock(BuildContext context, String label, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(text),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (block.blockType) {
      case BlockType.text:
        final dcm = DeColoquialMeta.read(block);
        if (dcm != null) {
          return _ColloquialTextView(
            block: block,
            dcm: dcm,
            expanded: expanded,
            onToggleExpand: onToggleExpand ?? () {},
          );
        }
        return TextCard(
          content: block.content,
          expanded: expanded,
          onToggleExpand: onToggleExpand ?? () {},
          // 卡片正文关闭文本选择：SelectionArea 不再拦截点击，点卡片进编辑器
          selectable: false,
        );
      case BlockType.code:
        return CodeCard(content: block.content);
      case BlockType.todo:
        return TodoCard(block: block, onToggle: onToggleTodo);
      case BlockType.smartEntity:
        return EntityCard(block: block);
      case BlockType.image:
        return ImageCard(imageName: block.content.trim());
      case BlockType.chart:
        return ChartCard(content: block.content);
      case BlockType.aiStream:
        return StreamingCard(
          buffer: streamBuffer,
          streaming: isStreaming,
          onStop: onStop,
        );
    }
  }

  /// 卡片「更多」菜单项（⋮ 按钮与右键共用，保证移动/桌面一致）。
  List<PopupMenuEntry<String>> _menuEntries() {
    return [
      const PopupMenuItem(value: 'edit', child: Text('编辑')),
      const PopupMenuItem(value: 'ai', child: Text('AI 处理')),
      if (block.blockType != BlockType.todo)
        const PopupMenuItem(value: 'todo', child: Text('转待办')),
      if (block.blockType == BlockType.text && !DeColoquialMeta.has(block))
        const PopupMenuItem(value: 'colloquial', child: Text('去口语化')),
      const PopupMenuItem(value: 'delete', child: Text('删除')),
    ];
  }

  void _dispatchMenu(String value) {
    switch (value) {
      case 'edit':
        onTap?.call();
        break;
      case 'ai':
        onAi?.call();
        break;
      case 'todo':
        onConvertTodo?.call();
        break;
      case 'colloquial':
        onCleanColloquial?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }

  /// 桌面右键：在指针位置弹出与 ⋮ 一致的菜单。
  Future<void> _openContextMenu(BuildContext context, Offset globalPos) async {
    final size = MediaQuery.sizeOf(context);
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        size.width - globalPos.dx,
        size.height - globalPos.dy,
      ),
      items: _menuEntries(),
    );
    if (value != null) _dispatchMenu(value);
  }
}

class _FootIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _FootIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(28, 26),
        maximumSize: const Size(28, 26),
        padding: EdgeInsets.zero,
      ),
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

/// 已去口语化的文本卡片：默认展示清洗稿，可一键切换原文；含录音时提供播放。
class _ColloquialTextView extends StatefulWidget {
  final Block block;
  final DeColoquialMeta dcm;
  final bool expanded;
  final VoidCallback onToggleExpand;

  const _ColloquialTextView({
    required this.block,
    required this.dcm,
    required this.expanded,
    required this.onToggleExpand,
  });

  @override
  State<_ColloquialTextView> createState() => _ColloquialTextViewState();
}

class _ColloquialTextViewState extends State<_ColloquialTextView> {
  bool _showCleaned = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audio = VoiceRecordMeta.read(widget.block);
    final content = _showCleaned
        ? widget.dcm.cleaned
        : widget.dcm.original;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildToggle(theme, '已清洗', _showCleaned, () {
              setState(() => _showCleaned = true);
            }),
            const SizedBox(width: 6),
            _buildToggle(theme, '原文', !_showCleaned, () {
              setState(() => _showCleaned = false);
            }),
            const Spacer(),
            if (audio != null && audio.absolutePath != null)
              IconButton(
                tooltip: '播放录音',
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                onPressed: () => _openPlayer(context, audio.absolutePath!),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextCard(
          content: content,
          expanded: widget.expanded,
          onToggleExpand: widget.onToggleExpand,
          selectable: false,
        ),
      ],
    );
  }

  Widget _buildToggle(
    ThemeData theme,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.secondaryContainer
              : Colors.transparent,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _openPlayer(BuildContext context, String path) async {
    await Get.dialog<void>(
      Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: VoiceMediaPlayer(path: path, label: '录音回放'),
        ),
      ),
    );
  }
}
