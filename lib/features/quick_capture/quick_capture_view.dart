import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/features/ai/widgets/smart_input_bar.dart';
import 'package:moodiary/features/ai/chat_model_selector.dart';
import 'package:moodiary/features/ai/widgets/chat_model_picker_sheet.dart';
import 'package:moodiary/features/link_capture/link_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_logic.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/features/quick_capture/quick_capture_draft.dart';
import 'package:moodiary/features/vision/quick_vision.dart';
import 'package:moodiary/features/voice/widgets/voice_capture_panel.dart';
import 'package:moodiary/utils/image_decode_util.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 快速收集面板（进入即激活态两行输入框，提交后清空并退出）。
///
/// 说明：面板不承载「新建日记/格式选择」等入口——新建走首页 FAB 展开菜单，
/// 输入条与 AI 助手/详情页共用 [SmartInputBar]，保持三处交互一致。
class QuickCaptureSheet extends StatefulWidget {
  const QuickCaptureSheet({super.key});

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();

  /// 唤起底部收集面板
  static Future<bool> show(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => const QuickCaptureSheet(),
    );
    return saved ?? false;
  }
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  late final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final QuickCaptureLogic logic;
  late final QuickCaptureState state;
  Timer? _draftTimer;

  /// 当前对话模型的短标签（点 chip 可切换）
  String _modelLabel = '默认';

  @override
  void initState() {
    super.initState();
    // 每次打开都用全新的面板状态（避免残留上一条的附件/模板）
    if (Get.isRegistered<QuickCaptureLogic>()) {
      Get.delete<QuickCaptureLogic>(force: true);
    }
    logic = Get.put(QuickCaptureLogic());
    state = logic.state;
    _restoreDraft();
    _controller.addListener(_scheduleDraftSave);
    unawaited(_loadModelLabel());
  }

  Future<void> _loadModelLabel() async {
    try {
      final label = await ChatModelSelector.currentShortLabel();
      if (mounted && label != _modelLabel) setState(() => _modelLabel = label);
    } catch (_) {
      // 读取失败保持默认标签
    }
  }

  /// 切换当前对话模型（对标 ima 的模型选择弹层）
  Future<void> _pickModel(BuildContext context) async {
    final picked = await showChatModelPicker(context);
    if (picked != null) await _loadModelLabel();
  }

  /// 「临时记忆」：上次没写完就关掉的草稿，这次打开原样恢复
  void _restoreDraft() {
    final draft = QuickCaptureDraftStore.load();
    if (draft.isEmpty) return;
    _controller.text = draft.text;
    state.text.value = draft.text;
    state.selectedTemplate.value = draft.template;
    state.attachments.addAll(draft.attachments);
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  void _saveDraft() {
    // 只在防抖落地时同步一次 Rx（避免每次按键都触发 UI 重建，干扰输入法）
    state.text.value = _controller.text;
    QuickCaptureDraftStore.save(
      QuickCaptureDraft(
        text: _controller.text,
        template: state.selectedTemplate.value,
        attachments: state.attachments.toList(),
      ),
    );
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    // 面板关闭：停掉可能还在进行的录音并丢弃未保存的音频
    unawaited(logic.abandonVoiceInput());
    // 关掉面板即记住当前内容（下次打开继续写）
    _saveDraft();
    _controller.removeListener(_scheduleDraftSave);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerLow,
          borderRadius: AppBorderRadius.largeBorderRadius,
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAttachmentPreview(context, logic, state),
            Obx(() {
              // 文字输入 ↔ 语音输入：同一张面板内平滑切换（不新开页面，避免割裂）
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                ),
                child: state.voiceMode.value
                    ? VoiceCapturePanel(
                        key: const ValueKey('voice-capture'),
                        controller: logic.voiceCapture,
                        onExitKeyboard: () => unawaited(
                          logic.exitVoiceInput(),
                        ),
                        onCancel: () => unawaited(logic.exitVoiceInput()),
                        onRetake: () => unawaited(logic.retakeVoiceInput()),
                        onSave: () => _saveVoiceNote(context, logic),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('text-capture'),
                        child: SmartInputBar(
                          controller: _controller,
                          focusNode: _focusNode,
                          startActive: true,
                          streaming: state.saving.value,
                          activeHint: '记点什么，或点麦克风说话…',
                          modelLabel: _modelLabel,
                          onModelSelect: () => _pickModel(context),
                          // 速记面板不需要知识库提及：不传 onAt，输入条就不渲染 @（不再弹"功能预留"假提示）
                          // 点按麦克风＝切到语音输入页并直接开录（不再「按住说话」）
                          onToggleVoice: () =>
                              unawaited(logic.enterVoiceInput()),
                          onPlus: () => _showAttachmentGrid(context, logic),
                          onSend: (text) async {
                            state.text.value = text;
                            // 先取好 Navigator，避免 await 之后再触碰 context
                            final navigator = Navigator.of(context);
                            final saved = await logic.save();
                            if (!saved) return;
                            _controller.clear();
                            state.text.value = '';
                            state.attachments.clear();
                            state.selectedTemplate.value = '';
                            // 已入库：清掉临时草稿，下次打开是干净的
                            await QuickCaptureDraftStore.clear();
                            if (!mounted) return;
                            navigator.pop(true);
                          },
                        ),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 保存语音笔记：先落地（笔记 + 音频附件）→ 后台转写 → 关面板刷新首页。
  Future<void> _saveVoiceNote(
    BuildContext context,
    QuickCaptureLogic logic,
  ) async {
    final navigator = Navigator.of(context);
    final diary = await logic.saveVoiceInput();
    if (diary == null) return;
    if (!mounted) return;
    // 语音已入库为新笔记；面板里没写完的文字草稿保持不动
    _saveDraft();
    navigator.pop(true);
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
              onRemove: () {
                logic.removeAttachment(index);
                _saveDraft(); // 附件变化也进草稿
              },
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
                    _saveDraft();
                    Get.back();
                  },
                ),
              if (state.selectedTemplate.value.isNotEmpty)
                TextButton(
                  onPressed: () {
                    logic.selectTemplate(null);
                    _saveDraft();
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
                        logic.pickImages().then((_) => _saveDraft());
                      },
                    ),
                    _AppendTile(
                      icon: Icons.audiotrack_outlined,
                      label: '音频',
                      color: colorScheme.tertiaryContainer,
                      onTap: () {
                        Get.back();
                        logic.pickAudio().then((_) => _saveDraft());
                      },
                    ),
                    _AppendTile(
                      icon: Icons.description_outlined,
                      label: '文档',
                      color: colorScheme.secondaryContainer,
                      onTap: () {
                        Get.back();
                        logic.pickDocument().then((_) => _saveDraft());
                      },
                    ),
                    _AppendTile(
                      icon: Icons.folder_outlined,
                      label: '其他文档',
                      color: colorScheme.surfaceContainerHighest,
                      onTap: () {
                        Get.back();
                        logic.pickDocument(other: true).then((_) => _saveDraft());
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
                    _AppendTile(
                      icon: Icons.document_scanner_outlined,
                      label: '图片整理',
                      color: colorScheme.tertiaryContainer,
                      onTap: () {
                        Get.back();
                        _showVisionCapture(context);
                      },
                    ),
                    _AppendTile(
                      icon: Icons.photo_camera_outlined,
                      label: '拍照整理',
                      color: colorScheme.secondaryContainer,
                      onTap: () {
                        Get.back();
                        _showCameraCapture(context);
                      },
                    ),
                    // 模板入口（原先挂在输入条的模型 chip 上）：切到附件的同一张网格里
                    _AppendTile(
                      icon: Icons.auto_awesome_outlined,
                      label: 'AI 模板',
                      color: colorScheme.tertiaryContainer,
                      onTap: () {
                        Get.back();
                        _showTemplatePicker(context, logic, state);
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
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _LinkUrlDialog(),
    );
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

  /// 图片速记（对标得到大脑「智能拍书」）：选图 → 视觉整理 → 生成笔记。
  /// 复用 [QuickVisionActions]（未配置视觉模型时退化为附件速记，不丢图片）。
  Future<void> _showVisionCapture(BuildContext context) async {
    try {
      toast.info(message: '正在识别图片…');
      final diary = await QuickVisionActions.captureFromGallery();
      if (!mounted) return;
      if (diary == null) {
        toast.info(message: '已取消选图');
        return;
      }
      toast.success(message: '已生成图片笔记「${diary.title}」');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) toast.error(message: '图片速记失败：$e');
    }
  }

  /// 拍照速记（相机直拍 → 视觉整理 → 生成笔记）。
  Future<void> _showCameraCapture(BuildContext context) async {
    try {
      toast.info(message: '正在识别图片…');
      final diary = await QuickVisionActions.captureFromCamera();
      if (!mounted) return;
      if (diary == null) {
        toast.info(message: '已取消拍照');
        return;
      }
      toast.success(message: '已生成图片笔记「${diary.title}」');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) toast.error(message: '拍照速记失败：$e');
    }
  }
}

/// 粘贴链接对话框（自管理控制器，避免退场动画期间 dispose 崩溃）。
class _LinkUrlDialog extends StatefulWidget {
  const _LinkUrlDialog();

  @override
  State<_LinkUrlDialog> createState() => _LinkUrlDialogState();
}

class _LinkUrlDialogState extends State<_LinkUrlDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('粘贴链接'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          hintText: 'https://… 文章 / 公众号 / B站 / 抖音',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('采集'),
        ),
      ],
    );
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
          // 64×64 附件格：按实际格宽解码（缩略图没必要读整张原图）
          cacheWidth: ImageDecodeUtil.thumbnailWidth(
            logicalSize: 64,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
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
