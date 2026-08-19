import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/quick_capture/quick_capture_logic.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/l10n/l10n.dart';

/// 快速收集面板：文本速记 + 附件缩略图 + 语音入口预留（架构文档"二、1. 首页"）。
class QuickCaptureSheet extends StatelessWidget {
  /// 快速新建入口（Markdown/纯文本/富文本），由调用方注入
  final Future<void> Function(DiaryType type)? onCreate;

  const QuickCaptureSheet({super.key, this.onCreate});

  /// 唤起底部半屏收集面板
  static Future<void> show(
    BuildContext context, {
    Future<void> Function(DiaryType type)? onCreate,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuickCaptureSheet(onCreate: onCreate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(QuickCaptureLogic());
    final state = logic.state;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text(
                      context.l10n.homeNavigatorDiary,
                      style: context.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (onCreate != null)
                      PopupMenuButton<DiaryType>(
                        tooltip: '更多新建方式',
                        onSelected: (type) async {
                          await onCreate!(type);
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
                        icon: const Icon(Icons.more_horiz),
                      ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // 速记输入区（富文本编辑器 P1.5 后续迭代，先用多行文本）
                    TextField(
                      autofocus: true,
                      minLines: 4,
                      maxLines: 10,
                      onChanged: (value) => state.text.value = value,
                      decoration: const InputDecoration(
                        hintText: '快速记录此刻的想法…',
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorderRadius,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 附件缩略图列表
                    Obx(() {
                      if (state.attachments.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < state.attachments.length; i++)
                            _AttachmentThumb(
                              attachment: state.attachments[i],
                              onRemove: () => logic.removeAttachment(i),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // 底部操作栏
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: logic.pickImages,
                      tooltip: '添加图片',
                      icon: const FaIcon(FontAwesomeIcons.image),
                    ),
                    IconButton(
                      onPressed: logic.pickDocument,
                      tooltip: '添加文档',
                      icon: const FaIcon(FontAwesomeIcons.filePdf),
                    ),
                    IconButton(
                      onPressed: () {
                        Get.snackbar(
                          '语音输入',
                          '语音识别引擎接入中，敬请期待',
                        );
                      },
                      tooltip: '语音输入（预留）',
                      icon: const FaIcon(FontAwesomeIcons.microphone),
                    ),
                    const Spacer(),
                    Obx(() {
                      return FilledButton.icon(
                        onPressed: state.saving.value ? null : () async {
                          final saved = await logic.save();
                          if (saved && Get.isBottomSheetOpen == true) {
                            Get.back();
                          }
                        },
                        icon: state.saving.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(state.saving.value ? '保存中' : '保存'),
                      );
                    }),
                  ],
                ),
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

  const _AttachmentThumb({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final Widget preview;
    if (attachment.isImage) {
      preview = ClipRRect(
        borderRadius: AppBorderRadius.smallBorderRadius,
        child: Image.file(
          File(attachment.path),
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        ),
      );
    } else {
      preview = Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppBorderRadius.smallBorderRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.file),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        preview,
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
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
