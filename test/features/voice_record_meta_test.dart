import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/voice/voice_record_meta.dart';

void main() {
  group('VoiceRecordMeta', () {
    test('写入/读取保留文件与转写文本，不丢其它 meta 键', () {
      final block = Block()..metaJson = '{"source":"initial"}';
      VoiceRecordMeta.write(
        block,
        const VoiceRecordMeta(
          file: 'audio-xxx.m4a',
          rawTranscript: '嗯那个明天开会',
          cleaned: '明天开会',
          durationMs: 5000,
        ),
      );
      expect(VoiceRecordMeta.has(block), isTrue);
      final meta = VoiceRecordMeta.read(block)!;
      expect(meta.file, 'audio-xxx.m4a');
      expect(meta.rawTranscript, '嗯那个明天开会');
      expect(meta.cleaned, '明天开会');
      expect(meta.durationMs, 5000);
      expect(block.metaJson, contains('"source":"initial"'));
    });

    test('脏 metaJson 容错为空', () {
      final block = Block()..metaJson = 'not-json';
      expect(VoiceRecordMeta.has(block), isFalse);
      expect(VoiceRecordMeta.read(block), isNull);
    });
  });
}
