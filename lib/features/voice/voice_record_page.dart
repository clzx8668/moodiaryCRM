import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_meta.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_service.dart';
import 'package:moodiary/features/ai/voice/audio_transcribe_service.dart';
import 'package:moodiary/features/ai/voice/long_audio_transcribe_service.dart';
import 'package:moodiary/features/ai/voice/meeting_minutes_service.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/voice/speech_service.dart';
import 'package:moodiary/features/voice/voice_media_player.dart';
import 'package:moodiary/features/voice/voice_record_meta.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 语音记录页（独立页，P0 增强）。
///
/// 保留录音文件 + 原始转写文本，支持：播放重听、语音转写/重新转写、去口语化、
/// 保存为日记（文本块带 `audio` 与 `deColoquial` 元数据，原文始终保留）。
class VoiceRecordPage extends StatefulWidget {
  const VoiceRecordPage({super.key, this.autoStart = false});

  /// 进入页面后自动开始录音（首页 FAB 长按直达、长按图标「语音速记」）。
  final bool autoStart;

  /// 录音时长格式化（纯函数，便于单测）。
  static String formatRecordDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  State<VoiceRecordPage> createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<VoiceRecordPage> {
  final _titleCtrl = TextEditingController();
  final _transcriptCtrl = TextEditingController();

  String? _audioFile; // audio 目录下的文件名
  String _cleaned = '';
  bool _listening = false;
  bool _saving = false;
  bool _recording = false;
  bool _transcribing = false;
  String _transcribeLabel = '云端转写';
  bool _generatingMinutes = false;
  MeetingMinutesResult? _minutes;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  final AudioRecorder _recorder = AudioRecorder();

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_toggleRecording());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _titleCtrl.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  /// 应用内直接录音（Android/iOS 用 m4a，桌面用 wav）。
  Future<void> _toggleRecording() async {
    if (_recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _elapsed = Duration.zero;
      });
      toast.success(message: '录音完成，可回放或转写');
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) toast.error(message: '未获得麦克风权限');
      return;
    }
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final ext = isDesktop ? '.wav' : '.m4a';
    final name = 'audio-${const Uuid().v7()}$ext';
    final path = FileUtil.getRealPath('audio', name);
    try {
      await _recorder.start(
        RecordConfig(
          encoder: isDesktop ? AudioEncoder.wav : AudioEncoder.aacLc,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _audioFile = name;
        _elapsed = Duration.zero;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed += const Duration(seconds: 1));
        }
      });
    } catch (e) {
      if (mounted) toast.error(message: '录音失败：$e');
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final file = (result != null && result.files.isNotEmpty)
        ? result.files.first
        : null;
    final path = file?.path;
    if (path == null || !File(path).existsSync()) {
      if (mounted) toast.info(message: '未选择音频文件');
      return;
    }
    final ext = p.extension(path).isEmpty ? '.m4a' : p.extension(path);
    final name = 'audio-${const Uuid().v7()}$ext';
    await File(path).copy(FileUtil.getRealPath('audio', name));
    if (mounted) {
      setState(() => _audioFile = name);
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text = p.basenameWithoutExtension(path);
      }
    }
  }

  Future<void> _dictate() async {
    if (_listening) {
      await SpeechService.instance.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    final ok = await SpeechService.instance.startListening((text) {
      if (mounted) {
        setState(() {
          _transcriptCtrl.text = text;
          _cleaned = '';
          _listening = false;
        });
      }
    });
    if (!ok && mounted) {
      setState(() => _listening = false);
      toast.info(message: '当前设备不支持语音识别');
    }
  }

  /// 云端转写：把录音/已选音频交给语音识别模型（不依赖设备语音服务）。
  /// 长录音（WAV）自动切片逐段识别后合并。
  Future<void> _transcribeCloud() async {
    final fileName = _audioFile;
    if (fileName == null) {
      toast.info(message: '请先录音或在右上角选择音频文件');
      return;
    }
    if (_transcribing) return;
    setState(() {
      _transcribing = true;
      _transcribeLabel = '云端转写中…';
    });
    try {
      final result = await LongAudioTranscribeService.transcribe(
        FileUtil.getRealPath('audio', fileName),
        onProgress: (progress) {
          if (mounted) {
            setState(() => _transcribeLabel = progress.label);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _transcriptCtrl.text = result.text;
        _cleaned = '';
        if (_titleCtrl.text.trim().isEmpty) {
          _titleCtrl.text = result.text.length > 16
              ? '${result.text.substring(0, 16)}…'
              : result.text;
        }
      });
      toast.success(
        message: result.chunked
            ? '云端转写完成（${result.chunkCount} 段合并）'
            : '云端转写完成',
      );
    } on TranscribeException catch (e) {
      if (mounted) toast.error(message: e.message);
    } catch (e) {
      if (mounted) toast.error(message: '云端转写失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _transcribing = false;
          _transcribeLabel = '云端转写';
        });
      }
    }
  }

  Future<void> _deColloquial() async {
    final text = _transcriptCtrl.text.trim();
    if (text.isEmpty) {
      toast.info(message: '请先输入或转写文本');
      return;
    }
    final result = await DeColoquialService.apply(text);
    if (result == null) {
      toast.info(message: '内容无需处理，或 AI 未配置 / 校验未通过');
      return;
    }
    if (mounted) setState(() => _cleaned = result.cleaned);
  }

  /// 生成结构化纪要：转写文本 → 摘要/决定/待办/正文（保存后进入 AI 生成区）。
  Future<void> _generateMinutes() async {
    final text = _transcriptCtrl.text.trim();
    if (text.isEmpty) {
      toast.info(message: '请先转写或输入文本');
      return;
    }
    if (_generatingMinutes) return;
    setState(() => _generatingMinutes = true);
    try {
      final result = await MeetingMinutesService.generate(
        text,
        title: _titleCtrl.text.trim(),
      );
      if (!mounted) return;
      if (result == null) {
        toast.error(message: '生成纪要失败：AI 未配置或未返回可用结果');
        return;
      }
      setState(() {
        _minutes = result;
        if (_titleCtrl.text.trim().isEmpty && result.title.isNotEmpty) {
          _titleCtrl.text = result.title;
        }
      });
      toast.success(message: '纪要已生成，保存后进入 AI 生成区');
    } catch (e) {
      if (mounted) toast.error(message: '生成纪要失败：$e');
    } finally {
      if (mounted) setState(() => _generatingMinutes = false);
    }
  }

  Future<void> _save() async {
    final raw = _transcriptCtrl.text.trim();
    if (raw.isEmpty) {
      toast.info(message: '请先输入或转写文本');
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final diary = Diary()
        ..id = const Uuid().v7()
        ..title = _titleCtrl.text.trim().isEmpty
            ? raw.length > 16
                ? '${raw.substring(0, 16)}…'
                : raw
            : _titleCtrl.text.trim()
        ..content = raw
        ..contentText = raw
        ..type = DiaryType.markdown.value
        ..time = now
        ..lastModified = now
        ..show = true
        ..mood = 0.5;
      if (_audioFile != null) diary.audioName = [_audioFile!];
      await IsarUtil.insertADiary(diary);

      final block = Block()
        ..diaryId = diary.id
        ..blockType = BlockType.text
        ..content = raw
        ..sortOrder = 0
        ..createdAt = now
        ..updatedAt = now
        // 先落 BlockMeta，再由 VoiceRecordMeta/DeColoquialMeta 往 metaJson 里补字段
        ..meta = BlockMeta(
          source: BlockMeta.sourceInitial,
          captureType: 'voice',
        );
      if (_audioFile != null) {
        VoiceRecordMeta.write(
          block,
          VoiceRecordMeta(file: _audioFile!, rawTranscript: raw),
        );
      }
      if (_cleaned.trim().isNotEmpty && _cleaned.trim() != raw) {
        DeColoquialMeta.write(
          block,
          DeColoquialMeta(
            original: raw,
            cleaned: _cleaned.trim(),
            ts: now.millisecondsSinceEpoch,
          ),
        );
      }
      await IsarUtil.insertBlock(block);

      // 纪要：落 AI 生成区（新块，原文保留），并异步抽取待办/日程
      final minutes = _minutes;
      var minutesSaved = false;
      if (minutes != null) {
        minutesSaved =
            await MeetingMinutesService.saveAsAiBlock(
              diaryId: diary.id,
              minutes: minutes,
              sourceContent: raw,
            ) !=
            null;
        if (minutesSaved) {
          unawaited(
            AiTaskQueueWorker.instance.submitTask(
              type: AiTaskType.extractPlan,
              refId: diary.id,
            ),
          );
        }
      }

      // 与其它采集入口保持一致：保存后异步补自动标签/分类/摘要
      unawaited(
        AiTaskQueueWorker.instance.submitTask(
          type: AiTaskType.autoTag,
          refId: diary.id,
        ),
      );

      if (!mounted) return;
      toast.success(
        message: minutesSaved
            ? '已保存语音记录（纪要已存，待办/日程抽取中…）'
            : '已保存语音记录',
      );
      Get.back(result: true);
    } catch (e) {
      if (mounted) toast.error(message: '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back(),
        ),
        title: const Text('语音记录'),
        actions: [
          IconButton(
            tooltip: '选择录音文件',
            icon: const Icon(Icons.library_music_outlined),
            onPressed: _pickAudio,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card.filled(
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _recording
                        ? Icons.graphic_eq_rounded
                        : Icons.mic_none_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _recording
                              ? '正在录音 ${VoiceRecordPage.formatRecordDuration(_elapsed)}'
                              : '直接录音',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '也可点右上角选择已有音频文件（m4a / wav / mp3）；'
                          '录完可用「云端转写」识别',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(
                      _recording
                          ? Icons.stop_rounded
                          : Icons.fiber_manual_record_rounded,
                      size: 18,
                    ),
                    label: Text(_recording ? '停止' : '录音'),
                  ),
                ],
              ),
            ),
          ),
          if (_audioFile != null) ...[
            const SizedBox(height: 12),
            VoiceMediaPlayer(
              path: FileUtil.getRealPath('audio', _audioFile!),
              label: '录音回放（重听）',
            ),
          ],

          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '标题（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transcriptCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '转写文本 *',
              hintText: '点「云端转写」识别录音，或「语音转写」当场朗读',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _cleaned = ''),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _listening ? null : _dictate,
                icon: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_rounded,
                ),
                label: Text(_listening ? '停止转写' : '语音转写'),
              ),
              FilledButton.tonalIcon(
                onPressed: _transcribing || _audioFile == null
                    ? null
                    : _transcribeCloud,
                icon: _transcribing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_rounded),
                label: Text(_transcribeLabel),
              ),
              OutlinedButton.icon(
                onPressed: _cleaned.isNotEmpty ? null : _deColloquial,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('去口语化'),
              ),
              OutlinedButton.icon(
                onPressed: _generatingMinutes ? null : _generateMinutes,
                icon: _generatingMinutes
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.summarize_rounded),
                label: Text(_generatingMinutes ? '生成纪要中…' : '生成纪要'),
              ),
            ],
          ),

          if (_cleaned.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Card.filled(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('已清洗',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        )),
                    const SizedBox(height: 4),
                    SelectableText(_cleaned),
                  ],
                ),
              ),
            ),
          ],

          if (_minutes != null) ...[
            const SizedBox(height: 12),
            Card.filled(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.summarize_rounded,
                          size: 16,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '纪要预览',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _minutes!.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '保存后进入该笔记的 AI 生成区，并自动抽取待办/日程',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF57C00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? '保存中…' : '保存为日记'),
            ),
          ),
        ],
      ),
    );
  }
}
