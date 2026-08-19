import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/diary_render/diary_render.dart';
import 'package:moodiary/components/markdown_embed/image_embed.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';

/// Markdown 内容渲染（统一配置 + 图片解析）
class MarkdownContentView extends StatelessWidget {
  final String data;
  final ColorScheme? customColorScheme;

  const MarkdownContentView({
    super.key,
    required this.data,
    this.customColorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = customColorScheme ?? Theme.of(context).colorScheme;
    final brightness = colorScheme.brightness;
    final config =
        brightness == Brightness.dark
            ? MarkdownConfig.darkConfig
            : MarkdownConfig.defaultConfig;
    return MarkdownBlock(
      data: data,
      config: config.copy(
        configs: [
          ImgConfig(
            builder: (src, _) {
              return MarkdownImageEmbed(isEdit: false, imageName: src);
            },
          ),
          brightness == Brightness.dark
              ? PreConfig.darkConfig.copy(theme: a11yDarkTheme)
              : const PreConfig().copy(theme: a11yLightTheme),
        ],
      ),
    );
  }
}

/// 智能块视图（Notion 式）：按 Block 列表渲染功能内容块。
/// 无 Block 时回退到 Markdown 渲染（DiaryRender）。
class SmartBlockView extends StatelessWidget {
  final Diary diary;
  final ColorScheme? customColorScheme;

  const SmartBlockView({
    super.key,
    required this.diary,
    this.customColorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = customColorScheme ?? Theme.of(context).colorScheme;
    return FutureBuilder<List<Block>>(
      future: IsarUtil.getBlocksByDiary(diary.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final blocks = snapshot.data!;
        if (blocks.isEmpty) {
          // 回退：整篇 Markdown 渲染
          return DiaryRender(
            diary: diary,
            customColorScheme: colorScheme,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final block in blocks) _BlockItem(block: block, colorScheme: colorScheme),
          ],
        );
      },
    );
  }
}

class _BlockItem extends StatelessWidget {
  final Block block;
  final ColorScheme colorScheme;

  const _BlockItem({required this.block, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    switch (block.blockType) {
      case BlockType.text:
      case BlockType.aiStream:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MarkdownContentView(
            data: block.content,
            customColorScheme: colorScheme,
          ),
        );
      case BlockType.todo:
        return Card.outlined(
          margin: const EdgeInsets.all(8.0),
          child: CheckboxListTile(
            value: block.content.trim().startsWith('[x]'),
            onChanged: null,
            title: Text(
              block.content
                  .replaceAll(RegExp(r'^\[[ xX]\]\s*'), '')
                  .trim(),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      case BlockType.image:
        final name = block.content.trim();
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(FileUtil.getRealPath('image', name)),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        );
      case BlockType.chart:
      case BlockType.code:
      case BlockType.smartEntity:
        return Card.outlined(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: Icon(
              block.blockType == BlockType.chart
                  ? Icons.bar_chart_rounded
                  : block.blockType == BlockType.code
                  ? Icons.code_rounded
                  : Icons.widgets_rounded,
            ),
            title: Text(
              block.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(block.blockType.name),
          ),
        );
    }
  }
}
