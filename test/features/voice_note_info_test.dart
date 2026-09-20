import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/colloquial/de_colloquial_meta.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/voice/voice_note_info.dart';
import 'package:moodiary/features/voice/voice_record_meta.dart';

Diary _voiceDiary({String file = 'voice-a.m4a'}) {
  final diary = Diary();
  diary.audioName = [file];
  return diary;
}

Block _voiceBlock(String content) => Block()
  ..diaryId = 'd1'
  ..blockType = BlockType.text
  ..content = content
  ..meta = BlockMeta(source: BlockMeta.sourceInitial, captureType: 'voice');

Block _transcribeCard(String content) => Block()
  ..diaryId = 'd1'
  ..blockType = BlockType.text
  ..content = content
  ..meta = BlockMeta(
    source: BlockMeta.sourceAi,
    aiTemplate: VoiceNoteInfo.transcribeTemplate,
  );

void main() {
  group('识别与状态', () {
    test('非语音笔记 → null（普通详情页不受影响）', () {
      final diary = Diary()..contentText = '普通笔记';
      expect(VoiceNoteInfo.from(diary: diary, blocks: const []), isNull);
    });

    test('占位卡为 ⏳ → 转写中', () {
      final info = VoiceNoteInfo.from(
        diary: _voiceDiary(),
        blocks: [_voiceBlock(''), _transcribeCard('⏳ 正在转写录音，稍后自动写入正文…')],
      );
      expect(info!.status, VoiceNoteStatus.transcribing);
    });

    test('占位卡为 ⚠️ → 失败并解析出原因', () {
      final info = VoiceNoteInfo.from(
        diary: _voiceDiary(),
        blocks: [
          _voiceBlock(''),
          _transcribeCard('⚠️ 处理未完成：未配置语音识别模型\n（原始内容已保留，可稍后重试）'),
        ],
      );
      expect(info!.status, VoiceNoteStatus.failed);
      expect(info.failureReason, '未配置语音识别模型');
    });

    test('端侧完成卡（🎙️）→ onDeviceDone，不是失败', () {
      final diary = _voiceDiary()..contentText = '今天和客户对了报价，下周给方案。';
      final voice = _voiceBlock('');
      VoiceRecordMeta.write(
        voice,
        const VoiceRecordMeta(
          file: 'voice-a.m4a',
          source: VoiceNoteInfo.onDeviceSource,
        ),
      );
      final info = VoiceNoteInfo.from(
        diary: diary,
        blocks: [
          voice,
          _transcribeCard('🎙️ 已用端侧模型转写（本地完成，未联网）\n正文即为识别结果；如需…'),
        ],
      );
      expect(info!.status, VoiceNoteStatus.onDeviceDone);
      // 关键：不该被当作转写失败（这正是用户反馈的"每条都报转写失败"）
      expect(info.status, isNot(VoiceNoteStatus.failed));
      expect(info.onDevice, isTrue);
      expect(info.canRefineOnCloud, isTrue);
      // 正文仍能读出来（来自 diary.contentText，而不是状态卡）
      expect(info.noteText, contains('报价'));
    });

    test('历史数据自愈：⚠️ 卡但正文已有内容 → 按端侧完成呈现', () {
      final diary = _voiceDiary()..contentText = '对我做了介绍啊，那么我想说的是呢。';
      final info = VoiceNoteInfo.from(
        diary: diary,
        blocks: [
          _voiceBlock(''),
          _transcribeCard('⚠️ 处理未完成：未配置语音识别模型\n（原始内容已保留，可稍后重试）'),
        ],
      );
      // 正文没丢，就不该继续报"转写失败"
      expect(info!.status, VoiceNoteStatus.onDeviceDone);
      expect(info.noteText, contains('对我做了介绍'));
    });

    test('转写完成 → done，正文取转写结果（源块为空也不为空壳）', () {
      final info = VoiceNoteInfo.from(
        diary: _voiceDiary(),
        blocks: [_voiceBlock(''), _transcribeCard('今天和客户对了报价，下周给方案')],
      );
      expect(info!.status, VoiceNoteStatus.done);
      expect(info.noteText, '今天和客户对了报价，下周给方案');
      expect(info.rawText, '今天和客户对了报价，下周给方案');
      // 原文与正文一致 → 不显示两个 Tab
      expect(info.hasDistinctRaw, isFalse);
      expect(info.hasText, isTrue);
    });
  });

  group('录音原文 / 笔记内容', () {
    test('去口语化后：原文 = original，正文 = 清洗稿，两者不同 → 显示 Tab', () {
      final block = _voiceBlock('嗯那个就是明天上午十点给李总回复菲律宾项目的进展');
      DeColoquialMeta.write(
        block,
        const DeColoquialMeta(
          original: '嗯那个就是明天上午十点给李总回复菲律宾项目的进展',
          cleaned: '明天上午十点给李总回复菲律宾项目进展。',
        ),
      );
      final info = VoiceNoteInfo.from(diary: _voiceDiary(), blocks: [block]);
      expect(info!.rawText, '嗯那个就是明天上午十点给李总回复菲律宾项目的进展');
      expect(info.noteText, '明天上午十点给李总回复菲律宾项目进展。');
      expect(info.hasDistinctRaw, isTrue);
    });

    test('VoiceRecordMeta.rawTranscript 作为原文来源（独立语音记录页产物）', () {
      final block = _voiceBlock('整理后的正文');
      VoiceRecordMeta.write(
        block,
        const VoiceRecordMeta(
          file: 'voice-a.m4a',
          rawTranscript: '原始转写：呃这个这个是原始稿',
          cleaned: '整理后的正文',
          durationMs: 11000,
        ),
      );
      final info = VoiceNoteInfo.from(diary: _voiceDiary(), blocks: [block]);
      expect(info!.rawText, '原始转写：呃这个这个是原始稿');
      expect(info.noteText, '整理后的正文');
      expect(info.hasDistinctRaw, isTrue);
    });

    test('已删除的卡片不参与判定（软删后仍能取到正文）', () {
      final voice = _voiceBlock('正文');
      final deleted = _transcribeCard('⏳ 正在转写…')..isDeleted = true;
      final info = VoiceNoteInfo.from(
        diary: _voiceDiary(),
        blocks: [voice, deleted],
      );
      expect(info!.status, VoiceNoteStatus.done);
      expect(info.noteText, '正文');
    });
  });
}
