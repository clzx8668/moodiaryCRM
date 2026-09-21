import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/tasks/pending_content_service.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/features/quick_capture/quick_capture_template_action.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/features/voice/voice_capture_controller.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart' as p;

/// 快速收集面板逻辑（ima 式输入框）
class QuickCaptureLogic extends GetxController {
  final state = QuickCaptureState();

  /// 语音输入页录音控制器（先录音、后决定保存/取消；批次 94）
  late final VoiceCaptureController voiceCapture = VoiceCaptureController();

  /// 重置输入面板状态（每次打开面板时调用，确保不残留上次内容）
  void reset() {
    state.text.value = '';
    state.attachments.clear();
    state.selectedTemplate.value = '';
    state.voiceMode.value = false;
    state.saving.value = false;
  }

  /// 从相册选择多张图片
  Future<void> pickImages() async {
    try {
      final files = await MediaUtil.pickMultiPhoto(null);
      for (final file in files) {
        state.addAttachment(
          QuickAttachment(
            path: file.path,
            type: QuickAttachmentType.image,
            name: p.basename(file.path),
          ),
        );
      }
    } catch (e) {
      toast.error(message: '选择图片失败：$e');
    }
  }

  /// 选择文档
  Future<void> pickDocument({bool other = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null) return;
      for (final file in result.files) {
        state.addAttachment(
          QuickAttachment(
            path: file.path ?? '',
            type: other
                ? QuickAttachmentType.other
                : QuickAttachmentType.document,
            name: file.name,
          ),
        );
      }
    } catch (e) {
      toast.error(message: '选择文件失败：$e');
    }
  }

  /// 选择声音文件
  Future<void> pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result == null) return;
      for (final file in result.files) {
        state.addAttachment(
          QuickAttachment(
            path: file.path ?? '',
            type: QuickAttachmentType.audio,
            name: file.name,
          ),
        );
      }
    } catch (e) {
      toast.error(message: '选择音频失败：$e');
    }
  }

  void removeAttachment(int index) {
    state.removeAttachment(index);
  }

  /// 选择功能模板
  void selectTemplate(String? template) {
    state.selectedTemplate.value = template ?? '';
    if (template != null && template.isNotEmpty) {
      toast.info(message: '已选择模板：$template');
    }
  }

  /// 进入语音输入页（点按麦克风）：**只切页，不自动开始录音**。
  ///
  /// 为什么要取消"自动开录"（批次 112，用户反馈）：
  /// 以前点话筒后先闪一下"开始录音"界面、等一会才自动开录，再跳到暂停/停止，
  /// 画面跳动且节奏不受控。现在进来就是稳定的一屏（播放/暂停 + 停止），
  /// **由用户按播放键决定真正开始**。
  Future<void> enterVoiceInput() async {
    if (state.voiceMode.value) return;
    state.voiceMode.value = true;
    // 不启动录音；顺手清掉上一次的残留（音频文件/状态）
    await voiceCapture.discard();
  }

  /// 开始 / 继续录音（面板上的播放键）。
  ///
  /// 优先走端侧实时转写（边说边出字）；模型没装/引擎不可用则退回云端路径。
  /// 返回 null 表示成功，否则返回可展示的错误文案。
  Future<String?> startVoiceRecording() async {
    if (voiceCapture.phase.value == VoiceCapturePhase.recording) return null;
    if (voiceCapture.phase.value == VoiceCapturePhase.paused) {
      await voiceCapture.resume();
      return null;
    }
    var error = await voiceCapture.startStreaming();
    if (error != null) error = await voiceCapture.start();
    return error;
  }

  /// 面板调用：开始录音并把失败原因提示出来。
  Future<void> startVoiceRecordingFromPanel() async {
    final error = await startVoiceRecording();
    if (error != null) toast.error(message: error);
  }

  /// 取消：丢弃录音并回到键盘输入（不留记录）。
  Future<void> exitVoiceInput() async {
    await voiceCapture.discard();
    state.voiceMode.value = false;
  }

  /// 重录：丢弃当前音频，回到"待开始"状态（仍然不自动开录）。
  Future<void> retakeVoiceInput() async {
    await voiceCapture.discard();
  }

  /// 保存语音笔记（先落地）：立刻入库（笔记 + 音频附件 + 占位卡），
  /// 转写交给后台队列，用户不必等待；返回落库后的日记。
  Future<Diary?> saveVoiceInput() async {
    final name = voiceCapture.audioFileName;
    if (name == null) return null;
    final diary = await saveVoiceNoteFast(name);
    if (diary != null) {
      voiceCapture.reset();
      state.voiceMode.value = false;
    }
    return diary;
  }

  /// 面板关闭时调用：停止录音并丢弃未保存的音频（避免麦克风常开/残留文件）。
  Future<void> abandonVoiceInput() async {
    await voiceCapture.discard();
    state.voiceMode.value = false;
  }

  /// 语音速记（先落地）：把刚刚录好的音频**立即**存成一条语音笔记，
  /// 转写交给后台队列，用户不必等待。
  Future<Diary?> saveVoiceNoteFast(String audioFileName) async {
    try {
      final diary = await PendingContentService.saveVoiceFast(
        audioFileName: audioFileName,
        // 把录音的响度包络一起存下来：详情页播放时按真实响度显示波形
        waveform: voiceCapture.waveformForSave,
        durationMs: voiceCapture.elapsed.value.inMilliseconds,
        // 端侧实时转写草稿：直接做正文，列表/详情立刻可读
        draftText: voiceCapture.liveTranscript.value,
      );
      final hasDraft = voiceCapture.liveTranscript.value.trim().isNotEmpty;
      toast.success(
        message: hasDraft ? '已保存语音笔记（本地转写，未联网）' : '已保存语音笔记，正在后台转写…',
      );
      return diary;
    } catch (e) {
      toast.error(message: '保存语音笔记失败：$e');
      return null;
    }
  }

  /// 保存速记（发送）
  Future<bool> save() async {
    if (state.saving.value) return false;
    final text = state.text.value.trim();
    if (text.isEmpty && state.attachments.isEmpty) {
      toast.info(message: '内容为空，无法保存');
      return false;
    }
    state.saving.value = true;
    try {
      final diary = await QuickCaptureSaver.save(
        text: text,
        attachments: state.attachments.toList(),
        template: state.selectedTemplate.value,
      );
      if (state.selectedTemplate.value.isNotEmpty) {
        final template = state.selectedTemplate.value;
        final action = quickCaptureActionFor(template);
        await SyncLogService.instance.write(
          level: SyncLogLevel.info,
          operation: 'ai',
          target: 'template',
          detail: action == null
              ? '模板【$template】已保存（无后台处理）'
              : '模板【$template】已提交 AI 处理（diary ${diary.id}）',
        );
        if (action != null) {
          unawaited(
            AiTaskQueueWorker.instance.submitTask(
              type: action.type,
              refId: diary.id,
              payload: action.payload,
            ),
          );
          toast.success(message: '已按【$template】保存，AI 正在处理…');
        } else {
          toast.success(message: '已按【$template】模板保存');
        }
      } else {
        toast.success(message: '已保存速记');
      }
      return true;
    } catch (e) {
      toast.error(message: '保存失败：$e');
      return false;
    } finally {
      state.saving.value = false;
    }
  }

  @override
  void onClose() {
    unawaited(voiceCapture.discardAndDispose());
    state.dispose();
    super.onClose();
  }
}
