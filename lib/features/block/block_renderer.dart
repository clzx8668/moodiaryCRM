import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/diary_render/diary_render.dart';
import 'package:moodiary/components/markdown_embed/image_embed.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/block/markdown_link.dart';
import 'package:moodiary/features/smart_canvas/widgets/reading_typography.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/image_decode_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:url_launcher/url_launcher.dart';

/// Markdown 渲染的标题层级口径。
enum MarkdownHeadingScale {
  /// 与编辑器一致（H1 = 32px）
  standard,

  /// 卡片正文阅读态（标题整体收敛一档）
  card,
}

/// Markdown 内容渲染（统一配置 + 图片解析）
class MarkdownContentView extends StatelessWidget {
  final String data;
  final ColorScheme? customColorScheme;

  /// 是否允许文本选择（SelectionArea）。详情页卡片内关闭，避免拦截点击进编辑器。
  final bool selectable;

  /// 阅读态标题层级：card 表示「卡片正文」（标题收敛，避免巨字墙），
  /// 默认与编辑器一致（保持上层行为不变）。
  final MarkdownHeadingScale headingScale;

  const MarkdownContentView({
    super.key,
    required this.data,
    this.customColorScheme,
    this.selectable = true,
    this.headingScale = MarkdownHeadingScale.standard,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = customColorScheme ?? Theme.of(context).colorScheme;
    final brightness = colorScheme.brightness;
    final config =
        brightness == Brightness.dark
            ? MarkdownConfig.darkConfig
            : MarkdownConfig.defaultConfig;
    final typography = headingScale == MarkdownHeadingScale.card
        ? ReadingTypography.configs(colorScheme)
        : const <LeafConfig>[];
    return MarkdownBlock(
      data: data,
      selectable: selectable,
      config: config.copy(
        configs: [
          ...typography,
          // 链接可点：外链走浏览器；本地附件（正文里的 📎 相对路径）解析到沙盒后交给系统应用
          LinkConfig(onTap: (url) => openLink(context, url)),
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

  /// 打开 Markdown 链接（纯逻辑在 [MarkdownLink]，这里只做打开与提示）。
  static Future<void> openLink(BuildContext context, String url) async {
    final kind = MarkdownLink.kindOf(url);
    if (kind == MarkdownLinkKind.invalid) return;
    try {
      if (kind == MarkdownLinkKind.external) {
        final uri = Uri.parse(url.trim());
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) toast.info(message: '无法打开链接');
        return;
      }
      final path = MarkdownLink.localPathOf(url);
      if (path == null) return;
      final file = File(path);
      if (!file.existsSync()) {
        if (context.mounted) toast.info(message: '附件不存在（可能已被清理）');
        return;
      }
      final ok = await launchUrl(
        Uri.file(path),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        toast.info(message: '没有可打开该格式的应用');
      }
    } catch (e) {
      if (context.mounted) toast.info(message: '打开失败：$e');
    }
  }
}

/// 智能块视图（Notion 式）：按 Block 列表渲染功能内容块。
/// 无 Block 时回退到 Markdown 渲染（DiaryRender）。
class SmartBlockView extends StatelessWidget {
  final Diary diary;
  final ColorScheme? customColorScheme;

  /// 点击块的回调（文本/Markdown 块点击进入编辑器）
  final void Function(Block block)? onTapBlock;

  const SmartBlockView({
    super.key,
    required this.diary,
    this.customColorScheme,
    this.onTapBlock,
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
            for (final block in blocks)
              _BlockItem(
                block: block,
                colorScheme: colorScheme,
                onTap: onTapBlock == null
                    ? null
                    : () => onTapBlock!(block),
              ),
          ],
        );
      },
    );
  }
}

class _BlockItem extends StatelessWidget {
  final Block block;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  const _BlockItem({required this.block, required this.colorScheme, this.onTap});

  @override
  Widget build(BuildContext context) {
    switch (block.blockType) {
      case BlockType.text:
      case BlockType.aiStream:
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: MarkdownContentView(
              data: block.content,
              customColorScheme: colorScheme,
            ),
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
            child: LayoutBuilder(
              builder: (context, constraints) => Image.file(
                File(FileUtil.getRealPath('image', name)),
                fit: BoxFit.contain,
                // 按块可用宽度解码（手机原图全尺寸解码会吃掉几十 MB）
                cacheWidth: ImageDecodeUtil.cacheWidthFor(
                  logicalWidth: constraints.maxWidth,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                ),
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
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
