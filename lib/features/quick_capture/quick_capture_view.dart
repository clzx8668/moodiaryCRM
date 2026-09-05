import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/ai/widgets/smart_input_bar.dart';
import 'package:moodiary/features/link_capture/link_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_logic.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 快速收集面板（进入即激活态两行输入框，提交后清空并退出）。
class QuickCaptureSheet extends StatefulWidget {
  /// 快速新建入口（Markdown/纯文本/富文本），由调用方注入
  final Future<void> Function(DiaryType type)? onCreate;

  const QuickCaptureSheet({super.key, this.onCreate});

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();

  /// 唤起底部收集面板
  static Future<bool> show(
    BuildContext context, {
    Future<void> Function(DiaryType type)? onCreate,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => QuickCaptureSheet(onCreate: onCreate),
    );
    return saved ?? false;
  }
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  late final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 面板每次打开都确保全新控制器（打开前清理旧实例）
    if (Get.isRegistered<QuickCaptureLogic>()) {
      Get.delete<QuickCaptureLogic>(force: true);
    }
    final logic = Get.put(QuickCaptureLogic());
    final state = logic.state;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerLow,
          borderRadius: AppBorderRadius.largeBorderRadius,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDragHandle(context),
            _buildAttachmentPreview(context, logic, state),
            const SizedBox(height: 4),
            Obx(() {
              return SmartInputBar(
                controller: _controller,
                focusNode: _focusNode,
                startActive: true,
                streaming: state.saving.value,
                activeHint: '发消息或按住说话',
                modelLabel: state.selectedTemplate.value.isEmpty
                    ? '快速'
                    : state.selectedTemplate.value,
                voiceMode: state.voiceMode.value,
                onModelSelect: () => _showTemplatePicker(context, logic, state),
                onAt: () => toast.info(message: '智能提及功能预留'),
                onToggleVoice: logic.toggleVoiceMode,
                onLongPressStart: () => logic.startRecording(
                  onText: (text) {
                    final base = _controller.text.trim();
                    _controller.text = base.isEmpty ? text : '$base\n$text';
                    state.text.value = _controller.text;
                  },
                ),
                onLongPressEnd: logic.stopRecording,
                listening: state.recording.value,
                onPlus: () => _showAttachmentGrid(context, logic),
                onSend: (text) async {
                  state.text.value = text;
                  final saved = await logic.save();
                  if (saved && context.mounted) {
                    _controller.clear();
                    state.text.value = '';
                    state.attachments.clear();
                    Navigator.of(context).pop(true);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 顶部：拖拽条 + 更多新建方式
  Widget _buildDragHandle(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 32),
        Expanded(
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        if (widget.onCreate != null)
          PopupMenuButton<DiaryType>(
            tooltip: '更多新建方式',
            icon: const Icon(Icons.more_horiz, size: 20),
            onSelected: (type) async {
              await widget.onCreate!(type);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: DiaryType.markdown,
                child: Text('Markdown 日记'),
              ),
              const PopupMenuItem(
                value: DiaryType.text,
                child: Text('纯文本日记'),
              ),
              const PopupMenuItem(
                value: DiaryType.richText,
                child: Text('富文本日记'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAttachmentPreview(
    BuildContext context,
    QuickCaptureLogic logic,
    QuickCaptureState state,
  ) {
    return Obx(() {
      if (state.attachments.isEmpty) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: state.attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            return _AttachmentThumb(
              attachment: state.attachments[index],
              onRemove: () => logic.removeAttachment(index),
            );
          },
        ),
      );
    });
  }

  void _showTemplatePicker(
    BuildContext context,
    QuickCaptureLogic logic,
    QuickCaptureState state,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('功能模板', style: context.textTheme.titleMedium),
              ),
              for (final template in quickCaptureTemplates)
                ListTile(
                  title: Row(
                    children: [
                      if (state.selectedTemplate.value == template)
                        const Icon(Icons.check, size: 18),
                      const SizedBox(width: 8),
                      Text(template),
                    ],
                  ),
                  onTap: () {
                    logic.selectTemplate(template);
                    Get.back();
                  },
                ),
              if (state.selectedTemplate.value.isNotEmpty)
                TextButton(
                  onPressed: () {
                    logic.selectTemplate(null);
                    Get.back();
                  },
                  child: const Text('清除模板'),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentGrid(BuildContext context, QuickCaptureLogic logic) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = context.theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('添加附件', style: context.textTheme.titleMedium),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                  children: [
                    _AppendTile(
                      icon: Icons.image_outlined,
                      label: '图片',
                      color: colorScheme.primaryContainer,
                      onTap: () {
                        Get.back();
                        logic.pickImages();
                      },
                    ),
                    _AppendTile(
                      icon: Icons.audiotrack_outlined,
                      label: '音频',
                      color: colorScheme.tertiaryContainer,
                      onTap: () {
                        Get.back();
                        logic.pickAudio();
                      },
                    ),
                    _AppendTile(
                      icon: Icons.description_outlined,
                      label: '文档',
                      color: colorScheme.secondaryContainer,
                      onTap: () {
                        Get.back();
                        logic.pickDocument();
                      },
                    ),
                    _AppendTile(
                      icon: Icons.folder_outlined,
                      label: '其他文档',
                      color: colorScheme.surfaceContainerHighest,
                      onTap: () {
                        Get.back();
                        logic.pickDocument(other: true);
                      },
                    ),
                    _AppendTile(
                      icon: Icons.link_rounded,
                      label: '链接',
                      color: colorScheme.primaryContainer,
                      onTap: () {
                        Get.back();
                        _showLinkCapture(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 粘贴链接 → 采集 → 落库（G1 链接速记）。
  Future<void> _showLinkCapture(BuildContext context) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('粘贴链接'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://… 文章 / 公众号 / B站 / 抖音',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('采集'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (url == null || url.trim().isEmpty) return;

    toast.info(message: '正在采集链接…');
    try {
      final diary = await LinkCaptureSaver.saveFromUrl(url.trim());
      if (mounted) {
        toast.success(message: '已保存链接笔记（AI 整理中）${diary.id}');
      }
    } catch (e) {
      if (mounted) toast.error(message: '链接采集失败：$e');
    }
  }
}

class _AppendTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AppendTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppBorderRadius.smallBorderRadius,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppBorderRadius.smallBorderRadius,
            ),
            child: Icon(icon, size: 22, color: context.theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(label, style: context.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  final QuickAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentThumb({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.surfaceContainerHigh,
                  borderRadius: AppBorderRadius.smallBorderRadius,
                ),
                clipBehavior: Clip.antiAlias,
                child: _preview(context),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            attachment.type.hint,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    switch (attachment.type) {
      case QuickAttachmentType.image:
        return Image.file(
          File(attachment.path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        );
      case QuickAttachmentType.audio:
        return const Center(child: Icon(Icons.audiotrack_rounded));
      case QuickAttachmentType.document:
        return const Center(child: Icon(Icons.description_outlined));
      case QuickAttachmentType.other:
        return const Center(child: Icon(Icons.folder_outlined));
    }
  }
}
