import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary/api/api.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/keyboard_listener/keyboard_listener.dart';
import 'package:moodiary/features/block/delta_to_markdown.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/smart_canvas/services/canvas_datasource.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/src/rust/api/jieba.dart';
import 'package:moodiary/src/rust/api/kmp.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/markdown_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import 'edit_arguments.dart';
import 'edit_state.dart';

class EditLogic extends GetxController {
  final EditState state = EditState();

  //标题
  late final TextEditingController titleTextEditingController =
      TextEditingController();

  // markdown控制器
  TextEditingController? markdownTextEditingController;

  //聚焦对象
  late FocusNode contentFocusNode = FocusNode();
  late FocusNode titleFocusNode = FocusNode();
  Timer? _timer;

  late final KeyboardObserver keyboardObserver;

  /// 是否有未保存改动（用于返回时自动保存，避免内容归一化带来的误判）
  bool _dirty = false;

  /// 子笔记编辑模式：非空 = 编辑既有 Block；'' = 追加新 Block；null = 整篇/新建/整合
  String? _blockId;

  /// 笔记整合模式：保存后删除该日记下所有子笔记（保留 AI 对话）块
  bool _consolidate = false;

  @override
  void onInit() {
    if (state.showWriteTime) _calculateDuration();
    keyboardObserver = KeyboardObserver(
      onHeightChanged: (_) {},
      onStateChanged: (state) {
        switch (state) {
          case KeyboardState.opening:
            break;
          case KeyboardState.closing:
            unFocus();
            break;
          case KeyboardState.closed:
            break;
          case KeyboardState.unknown:
            break;
        }
      },
    );
    keyboardObserver.start();
    super.onInit();
  }

  @override
  void onReady() async {
    await _initEdit();
    markdownTextEditingController?.addListener(_listenCount);
    titleTextEditingController.addListener(() => _dirty = true);
    super.onReady();
  }

  @override
  void onClose() {
    keyboardObserver.stop();
    titleTextEditingController.dispose();
    titleFocusNode.dispose();
    contentFocusNode.dispose();
    markdownTextEditingController?.dispose();
    _timer?.cancel();
    _timer = null;
    super.onClose();
  }

  Future<void> _initEdit() async {
    final args = Get.arguments;
    if (args is EditArguments) {
      await _initFromArguments(args);
    } else if (args is List) {
      // 兼容旧调用（新建）：[type, categoryId]
      await _initNew(
        type: DiaryType.markdown,
        categoryId: args.length > 1 ? args[1] as String? : null,
      );
    } else if (args is Diary) {
      // 兼容旧调用：整篇编辑
      await _initEditDiary(args);
    }
    state.isInit = true;
    update(['body']);
  }

  Future<void> _initFromArguments(EditArguments args) async {
    if (args.diary == null) {
      await _initNew(
        type: args.type ?? DiaryType.markdown,
        categoryId: args.categoryId,
      );
      return;
    }
    _blockId = args.blockId;
    _consolidate = args.consolidate;
    await _initEditDiary(args.diary!);
    if (args.initialContent != null) {
      // 子笔记编辑 / 笔记整合：用传入的初始正文覆盖日记内容
      markdownTextEditingController?.text = args.initialContent!;
      state.currentDiary.content = args.initialContent!;
      state.totalCount.value = _toPlainText().length;
    } else if (args.blockId == '') {
      // 追加笔记：打开空白编辑器新建子笔记，不预填主笔记内容与媒体资源
      markdownTextEditingController?.clear();
      state.currentDiary.content = '';
      state.currentDiary.contentText = '';
      state.imageFileList.clear();
      state.videoFileList.clear();
      state.audioFileList.clear();
      state.audioNameList.clear();
      state.totalCount.value = 0;
    }
  }

  /// 新建模式初始化（架构决策 2026-08-19：统一 Markdown）
  Future<void> _initNew({
    DiaryType type = DiaryType.markdown,
    String? categoryId,
  }) async {
    state.type = type;
    markdownTextEditingController = TextEditingController();
    state.currentDiary = Diary();
    if (state.autoWeather) {
      unawaited(getPositionAndWeather(context: Get.context!));
    }
    if (state.autoCategory) selectCategory(categoryId);
  }

  /// 编辑模式初始化（整篇 / 子笔记 / 笔记整合共用）：装载日记资源与 Markdown 正文。
  Future<void> _initEditDiary(Diary diary) async {
    state.isNew = false;
    state.originalDiary = diary;
    state.type = DiaryType.values.firstWhere(
      (type) => type.value == diary.type,
    );
    state.currentDiary = diary.clone();
    // 获取分类名称
    if (diary.categoryId != null) {
      state.categoryName = IsarUtil.getCategoryName(diary.categoryId!)!.categoryName;
    }
    // 初始化标题控制器
    titleTextEditingController.text = diary.title;
    // 待替换的字符串map
    final Map<String, String> replaceMap = {};
    // 临时拷贝一份图片数据
    for (final name in diary.imageName) {
      final xFile = XFile(FileUtil.getRealPath('image', name));
      replaceMap[name] = xFile.path;
      state.imageFileList.add(xFile);
    }
    // 临时拷贝一份音频数据到缓存目录
    for (final name in diary.audioName) {
      state.audioNameList.add(name);
      await File(
        FileUtil.getRealPath('audio', name),
      ).copy(FileUtil.getCachePath(name));
    }
    // 临时拷贝一份视频数据，别忘记了缩略图
    for (final name in diary.videoName) {
      final videoXFile = XFile(FileUtil.getRealPath('video', name));
      replaceMap[name] = videoXFile.path;
      state.videoFileList.add(videoXFile);
    }
    // 旧版 Delta 内容统一转换为 Markdown
    final markdown = diary.type == DiaryType.markdown.value
        ? diary.content
        : DeltaToMarkdown.convertIfDelta(diary.content);
    markdownTextEditingController = TextEditingController(
      text: await Kmp.replaceWithKmp(
        text: markdown,
        replacements: replaceMap,
      ),
    );
    state.type = DiaryType.markdown;
    state.totalCount.value = _toPlainText().length;
  }

  //计算写作时长
  void _calculateDuration() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state.duration += const Duration(seconds: 1);
      state.durationString.value = state.duration
          .toString()
          .split('.')[0]
          .padLeft(8, '0');
    });
  }

  String _toPlainText() {
    return _markdownToPlainText(markdownTextEditingController!.text);
  }

  String _markdownToPlainText(String markdown) {
    if (markdown.isEmpty) return '';

    return MarkdownConverter.convert(markdown);
  }

  void _listenCount() {
    state.totalCount.value = markdownTextEditingController?.text.length ?? 0;
    _dirty = true;
  }

  // 在 Markdown 光标处插入图片语法
  void insertMarkdownImage({required String imagePath}) {
    final controller = markdownTextEditingController;
    if (controller == null) return;
    final selection = controller.selection;
    final text = '![]($imagePath)';
    controller.text = controller.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    controller.selection = TextSelection.collapsed(
      offset: selection.start + text.length,
    );
  }

  // 在 Markdown 光标处插入媒体链接
  void insertMarkdownMedia({required String path, required String label}) {
    final controller = markdownTextEditingController;
    if (controller == null) return;
    final selection = controller.selection;
    final text = '[$label]($path)';
    controller.text = controller.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    controller.selection = TextSelection.collapsed(
      offset: selection.start + text.length,
    );
  }

  Future<void> addNewImage(XFile xFile, {bool isMarkdown = false}) async {
    state.imageFileList.add(xFile);
    insertMarkdownImage(imagePath: xFile.path);
    update(['Image']);
  }

  // 多张图片

  Future<void> pickMultiPhoto(BuildContext context) async {
    final List<XFile> photoList = await MediaUtil.pickMultiPhoto(10);
    if (photoList.isNotEmpty && context.mounted) {
      Navigator.pop(context);
      for (final photo in photoList) {
        await addNewImage(photo, isMarkdown: false);
      }
      return;
    } else {
      if (!context.mounted) return;
      toast.info(message: context.l10n.cancelSelect);
    }
  }

  //单张照片
  Future<void> pickPhoto(
    ImageSource imageSource,
    BuildContext context, {
    bool isMarkdown = false,
  }) async {
    //获取一张图片
    final XFile? photo = await MediaUtil.pickPhoto(imageSource);
    if (photo != null && context.mounted) {
      Navigator.pop<String>(context, photo.path);
      await addNewImage(photo, isMarkdown: isMarkdown);
    } else {
      if (!context.mounted) return;
      toast.info(message: context.l10n.cancelSelect);
    }
  }

  //画图照片
  Future<void> pickDraw(Uint8List dataList, BuildContext context) async {
    final path = FileUtil.getCachePath('${const Uuid().v7()}.png');
    Navigator.pop(context, path);
    addNewImage(XFile.fromData(dataList, path: path)..saveTo(path));
  }

  //网络图片
  Future<void> networkImage(BuildContext context) async {
    toast.info(message: context.l10n.imageFetching);
    final imageUrl = await Api.updateImageUrl();
    if (imageUrl == null && context.mounted) {
      toast.error(message: context.l10n.imageFetchError);
      return;
    }
    final imageData = await Api.getImageData(imageUrl!.first);
    if (imageData == null && context.mounted) {
      toast.error(message: context.l10n.imageFetchError);
      return;
    }
    final path = FileUtil.getCachePath('${const Uuid().v7()}.png');
    if (context.mounted) Navigator.pop(context, path);
    addNewImage(XFile.fromData(imageData!, path: path)..saveTo(path));
  }

  Future<void> addNewVideo(XFile xFile) async {
    state.videoFileList.add(xFile);
    insertMarkdownMedia(path: xFile.path, label: '视频');
    update(['Video']);
  }

  //选择视频
  Future<void> pickVideo(ImageSource imageSource, BuildContext context) async {
    // 获取一个视频
    final XFile? video = await MediaUtil.pickVideo(imageSource);
    if (video != null && context.mounted) {
      Navigator.pop(context);
      await addNewVideo(video);
    } else {
      if (!context.mounted) return;
      toast.info(message: context.l10n.cancelSelect);
    }
  }

  //预览图片
  // void toPhotoView(List<String> imagePath, int index) {
  //   Get.toNamed(AppRoutes.photoPage, arguments: [imagePath, index]);
  // }

  //预览视频
  // void toVideoView(List<String> videoPath, int index) {
  //   Get.toNamed(AppRoutes.videoPage, arguments: [videoPath, index]);
  // }

  //删除图片
  void deleteImage({required String path}) async {
    // 移除这个图片
    state.imageFileList.removeWhere((file) => file.path == path);
    await FileUtil.deleteFile(path);
    //Get.backLegacy();
    toast.success(message: '删除成功');
    update(['Image']);
  }

  //长按设置封面
  void setCover(int index) {
    final coverFile = state.imageFileList[index];
    state.imageFileList
      ..removeAt(index)
      ..insert(0, coverFile);
    toast.info(message: '设置第${index + 1}张图片为封面');
    update(['Image']);
  }

  //获取封面颜色
  Future<int?> getCoverColor() async {
    if (state.imageFileList.isNotEmpty) {
      return await MediaUtil.getColorScheme(
        FileImage(File(state.imageFileList.first.path)),
      );
    } else {
      return null;
    }
  }

  //获取封面比例
  Future<double?> getCoverAspect() async {
    //如果有封面就获取
    if (state.imageFileList.isNotEmpty) {
      return await MediaUtil.getImageAspectRatio(
        FileImage(File(state.imageFileList.first.path)),
      );
    } else {
      return null;
    }
  }

  //保存日记
  Future<void> saveDiary({required BuildContext context}) async {
    if (state.isSaving.value) return;
    state.isSaving.value = true;
    update(['modal']);
    // 根据文本中的实际内容移除不需要的资源
    final originContent = markdownTextEditingController!.text.trim();
    final needImage = await Kmp.findMatches(
      text: originContent,
      patterns: state.imagePathList,
    );
    final needVideo = await Kmp.findMatches(
      text: originContent,
      patterns: state.videoPathList,
    );
    final needAudio = await Kmp.findMatches(
      text: originContent,
      patterns: state.audioNameList,
    );
    state.imageFileList.removeWhere((file) => !needImage.contains(file.path));
    state.videoFileList.removeWhere((file) => !needVideo.contains(file.path));
    state.audioNameList.removeWhere((name) => !needAudio.contains(name));
    // 保存图片
    final imageNameMap = await MediaUtil.saveImages(
      imageFileList: state.imageFileList,
    );
    // 保存视频
    final videoNameMap = await MediaUtil.saveVideo(
      videoFileList: state.videoFileList,
    );
    //保存录音
    final audioNameMap = await MediaUtil.saveAudio(state.audioNameList);
    final content = await Kmp.replaceWithKmp(
      text: originContent,
      replacements: {...imageNameMap, ...videoNameMap, ...audioNameMap},
    );

    if (_blockId != null) {
      // 子笔记编辑 / 追加：正文写回 Block，标题改动同步到日记
      // 标题 = 集合标题：无论从哪张 Block 卡进入，标题框都写回所属 Diary.title
      state.currentDiary.title = titleTextEditingController.text;
      if (_blockId!.isEmpty) {
        await _saveAppendBlock(content);
      } else {
        await _saveEditBlock(content);
      }
    } else if (_consolidate) {
      // 笔记整合：融合全文写回主日记并删除子笔记
      await _saveConsolidated(content);
    } else {
      // 新建 / 整篇编辑（原有逻辑）
      final contentText = _toPlainText().removeLineBreaks();
      final tokenizer = await JiebaRs.cutAll(text: contentText);
      final keywords = await JiebaRs.extractKeywordsTfidf(
        text: contentText,
        topK: BigInt.from(5),
        allowedPos: [],
      );
      final sortByWeight = keywords
        ..sort((a, b) => b.weight.compareTo(a.weight));
      final sortedKeywords = sortByWeight.map((e) => e.keyword).toList();
      state.currentDiary
        ..title = titleTextEditingController.text
        ..content = content
        ..type = DiaryType.markdown.value
        ..contentText = contentText
        ..audioName = state.audioNameList
        ..imageName = imageNameMap.values.toList()
        ..videoName = videoNameMap.values.toList()
        ..tokenizer = tokenizer
        ..keywords = sortedKeywords
        ..imageColor = await getCoverColor()
        ..aspect = await getCoverAspect();

      await IsarUtil.updateADiary(
        oldDiary: state.originalDiary,
        newDiary: state.currentDiary,
      );
      // 智能块结构：同步该日记的首个 text Block
      await IsarUtil.upsertDiaryTextBlock(state.currentDiary);
    }
    _dirty = false;
    state.isSaving.value = false;
    // M1：新建日记保存后提交 AI 自动标签/分类任务（异步）
    if (state.isNew) {
      unawaited(
        AiTaskQueueWorker.instance.submitTask(
          type: 'auto_tag',
          refId: state.currentDiary.id,
        ),
      );
    }
    state.isNew
        ? Get.back(result: state.currentDiary.categoryId ?? '')
        : Get.back(result: 'changed');
    if (!context.mounted) return;
    toast.success(
      message:
          state.isNew
              ? context.l10n.editSaveSuccess
              : context.l10n.editChangeSuccess,
    );
  }

  /// 子笔记编辑保存：正文更新到既有 Block 并刷新聚合投影。
  Future<void> _saveEditBlock(String content) async {
    final block = await IsarUtil.getBlockById(_blockId!);
    if (block == null) {
      toast.error(message: '卡片不存在或已删除');
      return;
    }
    await CanvasDatasource().updateBlockContent(block, content);
    await _syncDiaryMetaChanges();
  }

  /// 追加子笔记保存：在所属日记下新增 source=appended 的 text 块。
  Future<void> _saveAppendBlock(String content) async {
    final diary = await IsarUtil.getDiaryById(state.currentDiary.id);
    if (diary == null) {
      toast.error(message: '所属日记不存在或已删除');
      return;
    }
    await CanvasDatasource().appendNote(diary: diary, text: content);
    await _syncDiaryMetaChanges();
  }

  /// 笔记整合保存：融合全文写回主日记，随后删除子笔记（保留 AI 对话块）。
  Future<void> _saveConsolidated(String content) async {
    final contentText = _toPlainText().removeLineBreaks();
    state.currentDiary
      ..title = titleTextEditingController.text
      ..content = content
      ..contentText = contentText;
    await IsarUtil.updateADiary(
      oldDiary: state.originalDiary,
      newDiary: state.currentDiary,
    );
    // 融合后删除子笔记，主日记承载全部内容；下次进入详情页由 initial 卡物化
    await IsarUtil.softDeleteNoteBlocksByDiary(state.currentDiary.id);
  }

  /// 子笔记模式下集合元数据改动同步到日记（不覆盖聚合投影）。
  /// 标题与心情遵循同一原则：从哪张 Block 卡进入，AppBar 标题 / 心情
  /// 编辑的都写入所属 Diary（集合），与正文（写回 Block）互不干扰。
  Future<void> _syncDiaryMetaChanges() async {
    final titleChanged = state.originalDiary?.title != state.currentDiary.title;
    final moodChanged = state.originalDiary?.mood != state.currentDiary.mood;
    if (!titleChanged && !moodChanged) return;
    final fresh = await IsarUtil.getDiaryById(state.currentDiary.id);
    if (fresh == null) return;
    if (titleChanged) fresh.title = state.currentDiary.title;
    if (moodChanged) fresh.mood = state.currentDiary.mood;
    fresh.lastModified = DateTime.now();
    await IsarUtil.updateADiary(oldDiary: fresh, newDiary: fresh);
  }

  DateTime? oldTime;

  void handleBack({required BuildContext context}) {
    final DateTime currentTime = DateTime.now();
    if (oldTime != null &&
        currentTime.difference(oldTime!) < const Duration(seconds: 3)) {
      if (_dirty) {
        // 有未保存改动：失焦并自动保存后再返回（与 CRM 失焦自动保存语义一致）
        unFocus();
        saveDiary(context: context);
      } else {
        Get.back();
      }
    } else {
      oldTime = currentTime;
      toast.info(message: '再点一次返回（有改动会自动保存）');
    }
  }

  Future<void> changeDate({required BuildContext context}) async {
    final nowDateTime = await showDatePicker(
      context: context,
      initialDate: state.currentDiary.time,
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.day,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
    );
    if (nowDateTime != null) {
      state.currentDiary.time = state.currentDiary.time.copyWith(
        year: nowDateTime.year,
        month: nowDateTime.month,
        day: nowDateTime.day,
      );
      _dirty = true;
      update(['Date']);
    }
  }

  Future<void> changeTime({required BuildContext context}) async {
    final nowTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(state.currentDiary.time),
    );
    if (nowTime != null) {
      state.currentDiary.time = state.currentDiary.time.copyWith(
        hour: nowTime.hour,
        minute: nowTime.minute,
      );
      _dirty = true;
      update(['Date']);
    }
  }

  void unFocus() {
    titleFocusNode.unfocus();
    contentFocusNode.unfocus();
  }

  //去画画
  void toDrawPage(BuildContext context) {
    unFocus();
    Get.toNamed(AppRoutes.drawPage);
  }

  void changeRate(value) {
    state.currentDiary.mood = value;
    _dirty = true;
    update(['Mood']);
  }

  //获取天气，同时获取定位
  Future<void> getPositionAndWeather({required BuildContext context}) async {
    final key = PrefUtil.getValue<String>('qweatherKey');
    final apiHost = PrefUtil.getValue<String>('qweatherApiHost');
    if (key.isNullOrBlank || apiHost.isNullOrBlank) return;

    try {
      state.isProcessing = true;
      update(['Weather']);

      // 获取定位
      final position = await Api.updatePosition(context);
      if (position == null && context.mounted) {
        _handleError(context, context.l10n.locationError);
        return;
      }
      state.currentDiary.position = position!;
      if (!context.mounted) return;
      // 获取天气
      final weather = await Api.updateWeather(
        context: context,
        position: LatLng(double.parse(position[0]), double.parse(position[1])),
      );
      if (weather == null && context.mounted) {
        _handleError(context, context.l10n.weatherError);
        return;
      }
      state.currentDiary.weather = weather!;
      state.isProcessing = false;
      if (context.mounted) {
        toast.success(message: context.l10n.weatherSuccess);
      }
      update(['Weather']);
    } catch (e) {
      state.isProcessing = false;
      update(['Weather']);
      if (context.mounted) {
        toast.error(message: context.l10n.weatherError);
      }
    }
  }

  void _handleError(BuildContext context, String message) {
    state.isProcessing = false;
    update(['Weather']);
    if (context.mounted) {
      toast.error(message: message);
    }
  }

  Future<void> pickAudio(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withReadStream: true,
      );

      if (result == null && context.mounted) {
        toast.info(message: context.l10n.cancelSelect);
        return;
      }

      final pickedFile = result!.files.single;
      final originalFileName = pickedFile.name;
      final fileExtension = extension(originalFileName);

      final audioName = 'audio-${const Uuid().v7()}$fileExtension';
      final cachePath = FileUtil.getCachePath(audioName);

      await pickedFile.readStream!.pipe(File(cachePath).openWrite());

      if (context.mounted) {
        Navigator.pop(context);
      }

      setAudioName(audioName);
    } catch (e) {
      if (!context.mounted) return;
      toast.error(message: context.l10n.audioFileError);
    }
  }

  //获取音频名称
  void setAudioName(String name) {
    state.audioNameList.add(name);
    insertMarkdownMedia(path: name, label: '音频');
    update(['Audio']);
  }

  //删除音频
  Future<void> deleteAudio(String path) async {
    // 删除文件
    await FileUtil.deleteFile(path);
    // 删除对应的组件
    state.audioNameList.removeWhere((name) => path.endsWith(name));
    update(['Audio']);
    toast.success(message: '删除成功');
  }

  //添加一个标签
  void addTag({required String tag, required BuildContext context}) {
    tag = tag.trim();
    if (tag.isNotEmpty) {
      if (state.currentDiary.tags.contains(tag)) {
        toast.info(message: context.l10n.editAddTagAlreadyExist);
        return;
      }
      state.currentDiary.tags.add(tag);
      // 标签创建时按序取色，供详情页背景自动取色使用
      final palette = AppColor.themeColorList;
      state.currentDiary.tagColors[tag] =
          palette[state.currentDiary.tags.length % palette.length].toARGB32();
      _dirty = true;
      update(['Tag']);
    } else {
      toast.info(message: context.l10n.editAddTagCannotEmpty);
    }
  }

  //移除一个标签
  void removeTag(index) {
    final removed = state.currentDiary.tags.removeAt(index);
    if (removed.isNotEmpty) {
      state.currentDiary.tagColors.remove(removed);
    }
    _dirty = true;
    update(['Tag']);
  }

  /// 设置自定义背景色（编辑器工具栏）；传 null 表示清除，回退到第一个标签颜色。
  void setBgColor(int? color) {
    state.currentDiary.bgColor = color;
    _dirty = true;
    update(['BgColor']);
  }

  void selectCategory(String? id) {
    if (state.currentDiary.categoryId == id) return;
    state.currentDiary.categoryId = id;
    _dirty = true;
    if (id == null) {
      state.categoryName = '';
    } else {
      final category = IsarUtil.getCategoryName(id);
      if (category != null) {
        state.categoryName = category.categoryName;
      }
    }
    update(['CategoryName']);
  }

  void renderMarkdown() {
    state.renderMarkdown.value = !state.renderMarkdown.value;
  }

  void focusContent() {
    if (!contentFocusNode.hasFocus) contentFocusNode.requestFocus();
  }
}
