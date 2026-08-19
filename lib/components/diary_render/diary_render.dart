import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/markdown_embed/image_embed.dart';

class DiaryRender extends StatefulWidget {
  final Diary diary;

  final ColorScheme? customColorScheme;

  /// Disable image embed
  final bool disableImage;

  /// Disable video embed
  final bool disableVideo;

  /// Disable audio embed
  final bool disableAudio;

  const DiaryRender({
    super.key,
    required this.diary,
    this.customColorScheme,
    this.disableImage = false,
    this.disableVideo = false,
    this.disableAudio = false,
  });

  @override
  State<DiaryRender> createState() => _DiaryRenderState();
}

class _DiaryRenderState extends State<DiaryRender> {
  Diary get diary => widget.diary;

  ColorScheme get colorScheme =>
      widget.customColorScheme ?? Theme.of(context).colorScheme;

  Widget _buildMarkdownWidget({
    required Brightness brightness,
    required String data,
  }) {
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

  @override
  Widget build(BuildContext context) {
    // 架构决策（2026-08-19）：内容统一 Markdown 渲染
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: _buildMarkdownWidget(
        brightness: colorScheme.brightness,
        data: diary.content,
      ),
    );
  }
}
