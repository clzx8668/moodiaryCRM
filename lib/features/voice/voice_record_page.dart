import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_meta.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_service.dart';
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
  const VoiceRecordPage({super.key});

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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
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
        ..updatedAt = now;
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

      if (!mounted) return;
      toast.success(message: '已保存语音记录');
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
          if (_audioFile != null) ...[
            VoiceMediaPlayer(
              path: FileUtil.getRealPath('audio', _audioFile!),
              label: '录音回放（重听）',
            ),
            const SizedBox(height: 12),
          ] else
            Card.filled(
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '点击右上角选择录音文件后，可在此回放与转写',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
              hintText: '点「语音转写」朗读，或手动输入',
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
              OutlinedButton.icon(
                onPressed: _cleaned.isNotEmpty ? null : _deColloquial,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('去口语化'),
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
