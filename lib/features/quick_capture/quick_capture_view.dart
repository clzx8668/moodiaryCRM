import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/quick_capture/quick_capture_logic.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 快速收集面板（仿 ima AI 交流提交框：扁平化、单一圆角框）。
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
            // 顶部：拖拽条 + 更多新建方式
            Row(
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
            ),
            // 附件预览行（缩略图 + 提示短句）
            Obx(() {
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
            }),
            const SizedBox(height: 4),
            // 输入区（键盘 / 语音）
            Obx(() {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: state.voiceMode.value
                    ? _buildVoiceButton(context, logic, state)
                    : _buildInputField(context, logic, state),
              );
            }),
            const SizedBox(height: 12),
            // 功能区
            _buildFunctionBar(context, logic, state),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 面板关闭（提交保存 / 失焦 / 手势关闭）即销毁控制器，
    // 下次打开恢复初始输入状态
    if (Get.isRegistered<QuickCaptureLogic>()) {
      Get.delete<QuickCaptureLogic>(force: true);
    }
    super.dispose();
  }

  Widget _buildInputField(
    BuildContext context,
    QuickCaptureLogic logic,
    QuickCaptureState state,
  ) {
    return GestureDetector(
      key: const ValueKey('input'),
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (_) => logic.startRecording(),
      onLongPressEnd: (_) => logic.stopRecording(),
      child: TextField(
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        onChanged: (value) => state.text.value = value,
        decoration: InputDecoration(
          hintText: '发消息或按住说话',
          hintStyle: context.textTheme.bodyLarge?.copyWith(
            color: context.theme.colorScheme.outline,
          ),
          filled: true,
          fillColor: context.theme.colorScheme.surfaceContainerHigh,
          border: const OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceButton(
    BuildContext context,
    QuickCaptureLogic logic,
    QuickCaptureState state,
  ) {
    return GestureDetector(
      key: const ValueKey('voice'),
      onLongPressStart: (_) => logic.startRecording(),
      onLongPressEnd: (_) => logic.stopRecording(),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: state.recording.value
              ? context.theme.colorScheme.errorContainer
              : context.theme.colorScheme.surfaceContainerHigh,
          borderRadius: AppBorderRadius.mediumBorderRadius,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.recording.value ? Icons.mic : Icons.mic_none_rounded,
              color: state.recording.value
                  ? context.theme.colorScheme.onErrorContainer
                  : context.theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              state.recording.value ? '松开 结束' : '按住 说话',
              style: context.textTheme.bodyLarge?.copyWith(
                color: state.recording.value
                    ? context.theme.colorScheme.onErrorContainer
                    : context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionBar(
    BuildContext context,
    QuickCaptureLogic logic,
    QuickCaptureState state,
  ) {
    return Row(
      children: [
        // 功能模板
        Obx(() {
          return PopupMenuButton<String>(
            tooltip: '功能模板',
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: state.selectedTemplate.value.isNotEmpty
                  ? context.theme.colorScheme.primary
                  : null,
            ),
            onSelected: logic.selectTemplate,
            itemBuilder: (context) => [
              for (final template in quickCaptureTemplates)
                PopupMenuItem(
                  value: template,
                  child: Row(
                    children: [
                      if (state.selectedTemplate.value == template)
                        const Icon(Icons.check, size: 18),
                      const SizedBox(width: 8),
                      Text(template),
                    ],
                  ),
                ),
            ],
          );
        }),
        // @ 按钮（预留）
        IconButton(
          tooltip: '智能提及（预留）',
          icon: const Icon(Icons.alternate_email_rounded),
          onPressed: () {
            toast.info(message: '智能提及功能预留');
          },
        ),
        const Spacer(),
        // 语音/键盘切换
        Obx(() {
          return IconButton(
            tooltip: '语音/键盘',
            icon: Icon(
              state.voiceMode.value
                  ? Icons.keyboard_alt_outlined
                  : Icons.mic_none_rounded,
            ),
            onPressed: logic.toggleVoiceMode,
          );
        }),
        // 圆圈加号：附件
        IconButton(
          tooltip: '添加附件',
          iconSize: 28,
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () => _showAttachmentSheet(context, logic),
        ),
        // 发送按钮（有内容时显示）
        Obx(() {
          final hasContent = state.text.value.trim().isNotEmpty;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: hasContent
                ? IconButton.filled(
                    key: const ValueKey('send'),
                    tooltip: '发送',
                    onPressed: state.saving.value
                        ? null
                        : () async {
                            final saved = await logic.save();
                            if (saved) Get.back(result: true);
                          },
                    icon: state.saving.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  )
                : const SizedBox.shrink(key: ValueKey('no-send')),
          );
        }),
      ],
    );
  }

  void _showAttachmentSheet(BuildContext context, QuickCaptureLogic logic) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('图片'),
                onTap: () {
                  Get.back();
                  logic.pickImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack_outlined),
                title: const Text('声音文件'),
                onTap: () {
                  Get.back();
                  logic.pickAudio();
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('文档'),
                onTap: () {
                  Get.back();
                  logic.pickDocument();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('其他文档'),
                onTap: () {
                  Get.back();
                  logic.pickDocument(other: true);
                },
              ),
            ],
          ),
        );
      },
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
