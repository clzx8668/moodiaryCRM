import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/sheet.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/components/category_add/category_add_view.dart';
import 'package:moodiary/components/markdown_bar/markdown_bar.dart';
import 'package:moodiary/components/markdown_embed/image_embed.dart';
import 'package:moodiary/components/mood_icon/mood_icon_view.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'edit_logic.dart';

class EditPage extends StatelessWidget {
  const EditPage({super.key});

  Widget _buildMarkdownWidget({
    required Brightness brightness,
    required String data,
  }) {
    final config =
        brightness == Brightness.dark
            ? MarkdownConfig.darkConfig
            : MarkdownConfig.defaultConfig;
    return MarkdownWidget(
      data: data,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      config: config.copy(
        configs: [
          ImgConfig(
            builder: (src, _) {
              return MarkdownImageEmbed(isEdit: true, imageName: src);
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
    final logic = Bind.find<EditLogic>();
    final state = Bind.find<EditLogic>().state;

    // Widget buildAddContainer(Widget icon) {
    //   return Container(
    //     decoration: BoxDecoration(
    //       borderRadius: AppBorderRadius.smallBorderRadius,
    //       color: context.theme.colorScheme.surfaceContainerHighest,
    //     ),
    //     constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
    //     width: ((size.width - 56.0) / 3).truncateToDouble(),
    //     height: ((size.width - 56.0) / 3).truncateToDouble(),
    //     child: Center(child: icon),
    //   );
    // }

    //标签列表
    Widget? buildTagList() {
      return state.currentDiary.tags.isNotEmpty
          ? Wrap(
            spacing: 8.0,
            children: List.generate(state.currentDiary.tags.length, (index) {
              return Chip(
                label: Text(
                  state.currentDiary.tags[index],
                  style: TextStyle(
                    color: context.theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                backgroundColor: context.theme.colorScheme.secondaryContainer,
                onDeleted: () {
                  logic.removeTag(index);
                },
              );
            }),
          )
          : null;
    }

    // Widget buildAudioPlayer() {
    //   return Wrap(
    //     children: [
    //       ...List.generate(state.audioNameList.length, (index) {
    //         return AudioPlayerComponent(
    //             path: FileUtil.getCachePath(state.audioNameList[index]));
    //       }),
    //       ActionChip(
    //         label: const Text('添加'),
    //         avatar: const Icon(Icons.add),
    //         onPressed: () {
    //           showModalBottomSheet(
    //               context: context,
    //               showDragHandle: true,
    //               useSafeArea: true,
    //               isScrollControlled: true,
    //               builder: (context) {
    //                 return const RecordSheetComponent();
    //               });
    //         },
    //       )
    //     ],
    //   );
    // }

    // Widget buildImage() {
    //   return Padding(
    //     padding: const EdgeInsets.only(top: 8.0),
    //     child: Wrap(
    //       spacing: 8.0,
    //       runSpacing: 8.0,
    //       children: [
    //         ...List.generate(state.imageFileList.length, (index) {
    //           return InkWell(
    //             borderRadius: AppBorderRadius.smallBorderRadius,
    //             onLongPress: () {
    //               logic.setCover(index);
    //             },
    //             onTap: () {
    //               logic.toPhotoView(
    //                   List.generate(state.imageFileList.length, (index) {
    //                     return state.imageFileList[index].path;
    //                   }),
    //                   index);
    //             },
    //             child: Container(
    //               constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
    //               width: ((size.width - 56.0) / 3).truncateToDouble(),
    //               height: ((size.width - 56.0) / 3).truncateToDouble(),
    //               padding: const EdgeInsets.all(2.0),
    //               decoration: BoxDecoration(
    //                 borderRadius: AppBorderRadius.smallBorderRadius,
    //                 border: Border.all(color: context.theme.colorScheme.outline.withAlpha((255 * 0.5).toInt())),
    //                 image: DecorationImage(
    //                   image: FileImage(File(state.imageFileList[index].path)),
    //                   fit: BoxFit.cover,
    //                 ),
    //               ),
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 mainAxisAlignment: MainAxisAlignment.end,
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Container(
    //                     decoration: BoxDecoration(
    //                       color: context.theme.colorScheme.surface.withAlpha((255 * 0.5).toInt()),
    //                       borderRadius: AppBorderRadius.smallBorderRadius,
    //                     ),
    //                     child: IconButton(
    //                       onPressed: () {
    //                         showDialog(
    //                             context: context,
    //                             builder: (context) {
    //                               return AlertDialog(
    //                                 title: const Text('提示'),
    //                                 content: const Text('确认删除这张照片吗'),
    //                                 actions: [
    //                                   TextButton(
    //                                       onPressed: () {
    //                                         Get.backLegacy();
    //                                       },
    //                                       child: const Text('取消')),
    //                                   TextButton(
    //                                       onPressed: () {
    //                                         logic.deleteImage(index);
    //                                       },
    //                                       child: const Text('确认'))
    //                                 ],
    //                               );
    //                             });
    //                       },
    //                       constraints: const BoxConstraints(),
    //                       icon: Icon(
    //                         Icons.remove_circle_outlined,
    //                         color: context.theme.colorScheme.tertiary,
    //                       ),
    //                       style: IconButton.styleFrom(
    //                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    //                         padding: const EdgeInsets.all(4.0),
    //                       ),
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           );
    //         }),
    //         ...[
    //           InkWell(
    //             borderRadius: AppBorderRadius.smallBorderRadius,
    //             onTap: () {
    //               showDialog(
    //                   context: context,
    //                   builder: (context) {
    //                     return SimpleDialog(
    //                       title: const Text('选择来源'),
    //                       children: [
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.photo_library_outlined),
    //                               Text('相册'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.pickMultiPhoto();
    //                           },
    //                         ),
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.camera_alt_outlined),
    //                               Text('相机'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.pickPhoto(ImageSource.camera);
    //                           },
    //                         ),
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.image_search_outlined),
    //                               Text('网络'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.networkImage();
    //                           },
    //                         ),
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.draw_outlined),
    //                               Text('画画'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.toDrawPage();
    //                           },
    //                         ),
    //                       ],
    //                     );
    //                   });
    //             },
    //             child: buildAddContainer(const FaIcon(FontAwesomeIcons.image)),
    //           )
    //         ],
    //       ],
    //     ),
    //   );
    // }

    // Widget buildVideo() {
    //   return Padding(
    //     padding: const EdgeInsets.only(top: 8.0),
    //     child: Wrap(
    //       spacing: 8.0,
    //       runSpacing: 8.0,
    //       children: [
    //         ...List.generate(state.videoFileList.length, (index) {
    //           return InkWell(
    //             onTap: () {
    //               logic.toVideoView(
    //                   List.generate(state.videoFileList.length, (index) {
    //                     return state.videoFileList[index].path;
    //                   }),
    //                   index);
    //             },
    //             child: Container(
    //               constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
    //               width: ((size.width - 56.0) / 3).truncateToDouble(),
    //               height: ((size.width - 56.0) / 3).truncateToDouble(),
    //               padding: const EdgeInsets.all(2.0),
    //               decoration: BoxDecoration(
    //                   borderRadius: AppBorderRadius.smallBorderRadius,
    //                   border: Border.all(color: context.theme.colorScheme.outline.withAlpha((255 * 0.5).toInt())),
    //                   image: DecorationImage(
    //                     image: FileImage(File(state.videoThumbnailFileList[index].path)),
    //                     fit: BoxFit.cover,
    //                   )),
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 mainAxisAlignment: MainAxisAlignment.end,
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Container(
    //                     decoration: BoxDecoration(
    //                       color: context.theme.colorScheme.surface.withAlpha((255 * 0.5).toInt()),
    //                       borderRadius: AppBorderRadius.smallBorderRadius,
    //                     ),
    //                     child: IconButton(
    //                       onPressed: () {
    //                         showDialog(
    //                             context: context,
    //                             builder: (context) {
    //                               return AlertDialog(
    //                                 title: const Text('提示'),
    //                                 content: const Text('确认删除这个视频吗'),
    //                                 actions: [
    //                                   TextButton(
    //                                       onPressed: () {
    //                                         Get.backLegacy();
    //                                       },
    //                                       child: const Text('取消')),
    //                                   TextButton(
    //                                       onPressed: () {
    //                                         logic.deleteVideo(index);
    //                                       },
    //                                       child: const Text('确认'))
    //                                 ],
    //                               );
    //                             });
    //                       },
    //                       constraints: const BoxConstraints(),
    //                       icon: Icon(
    //                         Icons.remove_circle_outlined,
    //                         color: context.theme.colorScheme.tertiary,
    //                       ),
    //                       style: IconButton.styleFrom(
    //                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    //                         padding: const EdgeInsets.all(4.0),
    //                       ),
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           );
    //         }),
    //         if (state.videoFileList.length < 9) ...[
    //           InkWell(
    //             borderRadius: AppBorderRadius.smallBorderRadius,
    //             onTap: () {
    //               showDialog(
    //                   context: context,
    //                   builder: (context) {
    //                     return SimpleDialog(
    //                       title: const Text('选择来源'),
    //                       children: [
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.photo_library_outlined),
    //                               Text('相册'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.pickVideo(ImageSource.gallery);
    //                           },
    //                         ),
    //                         SimpleDialogOption(
    //                           child: const Row(
    //                             spacing: 8.0,
    //                             children: [
    //                               Icon(Icons.camera_alt_outlined),
    //                               Text('拍摄'),
    //                             ],
    //                           ),
    //                           onPressed: () {
    //                             logic.pickVideo(ImageSource.camera);
    //                           },
    //                         ),
    //                       ],
    //                     );
    //                   });
    //             },
    //             child: buildAddContainer(const FaIcon(FontAwesomeIcons.video)),
    //           )
    //         ],
    //       ],
    //     ),
    //   );
    // }

    Widget buildMoodSlider() {
      return Container(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            MoodIconComponent(value: state.currentDiary.mood),
            Expanded(
              child: Slider(
                value: state.currentDiary.mood,
                divisions: 10,
                label: '${(state.currentDiary.mood * 100).toStringAsFixed(0)}%',
                activeColor: Color.lerp(
                  AppColor.emoColorList.first,
                  AppColor.emoColorList.last,
                  state.currentDiary.mood,
                ),
                onChanged: (value) {
                  logic.changeRate(value);
                },
              ),
            ),
          ],
        ),
      );
    }

    Widget buildPickImage({bool allowMulti = false, bool isMarkdown = false}) {
      return SimpleDialog(
        title: Text(context.l10n.editPickImage),
        children: [
          SimpleDialogOption(
            child: Row(
              spacing: 8.0,
              children: [
                const Icon(Icons.photo_library_outlined),
                Text(context.l10n.editPickImageFromGallery),
              ],
            ),
            onPressed: () async {
              allowMulti
                  ? await logic.pickMultiPhoto(context)
                  : await logic.pickPhoto(
                    ImageSource.gallery,
                    context,
                    isMarkdown: isMarkdown,
                  );
            },
          ),
          if (Platform.isAndroid || Platform.isIOS)
            SimpleDialogOption(
              child: Row(
                spacing: 8.0,
                children: [
                  const Icon(Icons.camera_alt_outlined),
                  Text(context.l10n.editPickImageFromCamera),
                ],
              ),
              onPressed: () async {
                await logic.pickPhoto(
                  ImageSource.camera,
                  context,
                  isMarkdown: isMarkdown,
                );
              },
            ),
          SimpleDialogOption(
            child: Row(
              spacing: 8.0,
              children: [
                const Icon(Icons.image_search_outlined),
                Text(context.l10n.editPickImageFromWeb),
              ],
            ),
            onPressed: () async {
              await logic.networkImage(context);
            },
          ),
          SimpleDialogOption(
            child: Row(
              spacing: 8.0,
              children: [
                const Icon(Icons.draw_outlined),
                Text(context.l10n.editPickImageFromDraw),
              ],
            ),
            onPressed: () {
              logic.toDrawPage(context);
            },
          ),
        ],
      );
    }

    Widget buildDetail() {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          AdaptiveListTile(
            onTap: null,
            title: context.l10n.editDateAndTime,
            subtitle: GetBuilder<EditLogic>(
              id: 'Date',
              builder: (_) {
                return Text(state.currentDiary.time.toString().split('.')[0]);
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  onPressed: () async {
                    await logic.changeDate(context: context);
                  },
                  icon: const Icon(Icons.date_range),
                ),
                IconButton.filledTonal(
                  onPressed: () async {
                    await logic.changeTime(context: context);
                  },
                  icon: const Icon(Icons.access_time),
                ),
              ],
            ),
          ),
          GetBuilder<EditLogic>(
            id: 'Weather',
            builder: (_) {
              return AdaptiveListTile(
                title: context.l10n.editWeather,
                subtitle:
                    state.currentDiary.weather.isNotEmpty
                        ? Text(
                          '${state.currentDiary.weather[2]} ${state.currentDiary.weather[1]}°C',
                        )
                        : null,
                trailing:
                    state.isProcessing
                        ? const CircularProgressIndicator()
                        : IconButton.filledTonal(
                          onPressed: () async {
                            await logic.getPositionAndWeather(context: context);
                          },
                          icon: const Icon(Icons.location_on),
                        ),
              );
            },
          ),
          GetBuilder<EditLogic>(
            id: 'CategoryName',
            builder: (_) {
              return AdaptiveListTile(
                title: context.l10n.editCategory,
                subtitle:
                    state.categoryName.isNotEmpty
                        ? Text(state.categoryName)
                        : null,
                trailing: IconButton.filledTonal(
                  onPressed: () {
                    showFloatingModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return const CategoryAddComponent();
                      },
                    );
                  },
                  icon: const Icon(Icons.category),
                ),
              );
            },
          ),
          GetBuilder<EditLogic>(
            id: 'Tag',
            builder: (_) {
              return AdaptiveListTile(
                title: context.l10n.editTag,
                subtitle: buildTagList(),
                trailing: IconButton.filledTonal(
                  icon: const Icon(Icons.tag),
                  onPressed: () async {
                    final res = await showTextInputDialog(
                      style: AdaptiveStyle.material,
                      context: context,
                      title: context.l10n.editAddTag,
                      textFields: [
                        DialogTextField(hintText: context.l10n.editTag),
                      ],
                    );
                    if (res != null && res.isNotEmpty && context.mounted) {
                      logic.addTag(tag: res.first, context: context);
                    }
                  },
                ),
              );
            },
          ),
          AdaptiveListTile(
            title: context.l10n.editMood,
            subtitle: GetBuilder<EditLogic>(
              id: 'Mood',
              builder: (_) {
                return buildMoodSlider();
              },
            ),
          ),
          // AdaptiveListTile(
          //   title: const Text('图片'),
          //   subtitle: GetBuilder<EditLogic>(
          //       id: 'Image',
          //       builder: (_) {
          //         return buildImage();
          //       }),
          // ),
          // AdaptiveListTile(
          //   title: const Text('视频'),
          //   subtitle: GetBuilder<EditLogic>(
          //       id: 'Video',
          //       builder: (_) {
          //         return buildVideo();
          //       }),
          // ),
          // AdaptiveListTile(
          //   title: const Text('音频'),
          //   subtitle: GetBuilder<EditLogic>(
          //       id: 'Audio',
          //       builder: (_) {
          //         return buildAudioPlayer();
          //       }),
          // ),
        ],
      );
    }

    Widget buildType() {
      return Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainer.withValues(
            alpha: 0.8,
          ),
          borderRadius: AppBorderRadius.smallBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: RichText(
          text: TextSpan(
            text: '${context.l10n.diaryType} ',
            style: context.textTheme.labelSmall,
            children: [
              TextSpan(
                text: context.l10n.homeNewDiaryMarkdown,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildTimer() {
      return Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainer.withValues(
            alpha: 0.8,
          ),
          borderRadius: AppBorderRadius.smallBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Obx(() {
          return RichText(
            text: TextSpan(
              text: '${context.l10n.editTime} ',
              style: context.textTheme.labelSmall,
              children: [
                TextSpan(
                  text: state.durationString.value.toString(),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.theme.colorScheme.primary,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          );
        }),
      );
    }

    Widget buildCount() {
      return Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainer.withValues(
            alpha: 0.8,
          ),
          borderRadius: AppBorderRadius.smallBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Obx(() {
          return RichText(
            text: TextSpan(
              text: '${context.l10n.editCount} ',
              style: context.textTheme.labelSmall,
              children: [
                TextSpan(
                  text: state.totalCount.value.toString(),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.theme.colorScheme.primary,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          );
        }),
      );
    }

    Widget buildTitle() {
      return AutoSizeTextField(
        controller: logic.titleTextEditingController,
        focusNode: logic.titleFocusNode,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: context.textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.bold,
        ),
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          border: const UnderlineInputBorder(borderSide: BorderSide.none),
          hintText: context.l10n.editTitle,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        ),
      );
    }

    Widget markdownToolBar() {
      return Row(
        spacing: 8.0,
        children: [
          IconButton.filled(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '日记信息',
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              showFloatingModalBottomSheet(
                context: context,
                builder: (context) {
                  return buildDetail();
                },
              );
            },
          ),
          IconButton.filledTonal(
            onPressed: logic.renderMarkdown,
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Obx(() {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                reverseDuration: const Duration(milliseconds: 100),
                child:
                    state.renderMarkdown.value
                        ? const Icon(
                          Icons.visibility_off_rounded,
                          key: ValueKey('off_icon'),
                        )
                        : const Icon(
                          Icons.visibility_rounded,
                          key: ValueKey('on_icon'),
                        ),
              );
            }),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MarkdownToolbar(
                useIncludedTextField: false,
                collapsable: false,
                spacing: 8.0,
                controller: logic.markdownTextEditingController,
                focusNode: logic.contentFocusNode,
                backgroundColor: context.theme.colorScheme.surfaceContainer,
                iconColor: context.theme.colorScheme.onSurface,
                dropdownTextColor: context.theme.colorScheme.onSurface,
                borderRadius: BorderRadius.circular(20),
                width: 40,
                height: 40,
                beforeImagePressed: () async {
                  return await showDialog<String>(
                    context: context,
                    builder: (context) {
                      return buildPickImage(
                        allowMulti: false,
                        isMarkdown: true,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    Widget buildContent() {
      // 架构决策（2026-08-19）：统一 Markdown 编辑器
      return Positioned.fill(
        child: Obx(() {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                !state.renderMarkdown.value
                    ? GestureDetector(
                      onTap: logic.focusContent,
                      behavior: HitTestBehavior.translucent,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: TextField(
                          controller: logic.markdownTextEditingController,
                          focusNode: logic.contentFocusNode,
                          maxLength: null,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: context.l10n.editContent,
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              20,
                              16,
                              20,
                            ),
                            hintStyle: context.textTheme.bodyLarge?.copyWith(
                              fontSize: 20,
                              height: 1.5,
                              color: Colors.grey.withValues(alpha: 0.6),
                            ),
                          ),
                          maxLines: null,
                        ),
                      ),
                    )
                    : _buildMarkdownWidget(
                      brightness: context.theme.colorScheme.brightness,
                      data: logic.markdownTextEditingController!.text,
                    ),
          );
        }),
      );
    }

    Widget buildWriting() {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8.0,
              children: [
                buildType(),
                if (state.showWriteTime) buildTimer(),
                if (state.showWordCount) buildCount(),
              ],
            ),
          ),
          Flexible(
            child: Stack(
              children: [
                buildContent(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
            ),
            child: markdownToolBar(),
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (canPop, _) {
        if (canPop) return;
        logic.handleBack(context: context);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          GetBuilder<EditLogic>(
            id: 'body',
            builder: (_) {
              return Scaffold(
                appBar: AppBar(
                  title: buildTitle(),
                  titleSpacing: .0,
                  leading: PageBackButton(
                    onBack: () {
                      logic.handleBack(context: context);
                    },
                  ),
                  centerTitle: true,
                  actions: [
                    Obx(() {
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: state.isSaving.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                onPressed: () {
                                  logic.unFocus();
                                  logic.saveDiary(context: context);
                                },
                                icon: const Icon(Icons.check_rounded),
                                tooltip: context.l10n.save,
                              ),
                      );
                    }),
                  ],
                ),
                body: SafeArea(
                  child:
                      state.isInit
                          ? buildWriting()
                          : const Center(child: CircularProgressIndicator()),
                ),
              );
            },
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}
