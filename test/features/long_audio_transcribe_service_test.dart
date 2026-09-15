import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/features/ai/voice/audio_transcribe_service.dart';
import 'package:moodiary/features/ai/voice/long_audio_transcribe_service.dart';
import 'package:moodiary/features/ai/voice/wav_splitter.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, int index) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options, requests.length - 1);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _text(String value, {int status = 200}) => ResponseBody.fromString(
  jsonEncode({
    'choices': [
      {
        'message': {'content': value},
      },
    ],
  }),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

List<int> _wav(int seconds, {int sampleRate = 8000}) {
  final samples = sampleRate * seconds;
  final payload = <int>[];
  for (var i = 0; i < samples; i++) {
    payload
      ..add(4000 & 0xFF)
      ..add((4000 >> 8) & 0xFF);
  }
  return WavSplitter.buildWav(
    payload,
    WavFormat(
      audioFormat: 1,
      channels: 1,
      sampleRate: sampleRate,
      bitsPerSample: 16,
      dataOffset: 0,
      dataSize: 0,
    ),
  );
}

VoiceEndpoint _endpoint() => VoiceEndpoint(
  config: AiProviderConfig()
    ..name = '百炼'
    ..baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1'
    ..apiKey = 'sk-test'
    ..voiceModel = 'qwen3-asr-flash',
  model: 'qwen3-asr-flash',
);

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('long_asr_test_');
  });

  tearDown(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // 句柄未释放时忽略（Windows）
    }
  });

  test('短录音：不切片，单发一次', () async {
    final path = '${tmp.path}/short.wav';
    File(path).writeAsBytesSync(_wav(2));
    final adapter = _FakeAdapter((_, __) async => _text('短录音内容'));
    final result = await LongAudioTranscribeService.transcribe(
      path,
      dio: Dio()..httpClientAdapter = adapter,
      endpointOverride: _endpoint(),
    );

    expect(result.chunked, isFalse);
    expect(result.chunkCount, 1);
    expect(result.text, '短录音内容');
    expect(adapter.requests, hasLength(1));
  });

  test('长录音：切片逐段识别并合并，进度逐段回调', () async {
    final path = '${tmp.path}/long.wav';
    File(path).writeAsBytesSync(_wav(10)); // 10 秒
    final adapter = _FakeAdapter(
      (_, index) async => _text('第${index + 1}段'),
    );
    final progress = <String>[];
    final result = await LongAudioTranscribeService.transcribe(
      path,
      dio: Dio()..httpClientAdapter = adapter,
      endpointOverride: _endpoint(),
      chunkBytes: 16000 * 2, // 2 秒/片 → 5 片
      tempDir: tmp,
      onProgress: (p) => progress.add(p.label),
    );

    expect(result.chunked, isTrue);
    expect(result.chunkCount, 5);
    expect(result.parts, ['第1段', '第2段', '第3段', '第4段', '第5段']);
    expect(result.text, '第1段\n第2段\n第3段\n第4段\n第5段');
    expect(progress, [
      '转写中 1/5',
      '转写中 2/5',
      '转写中 3/5',
      '转写中 4/5',
      '转写中 5/5',
    ]);
    expect(adapter.requests, hasLength(5));
    // 每片都按 WAV 形态发 audio_chat，且带正确格式
    for (final request in adapter.requests) {
      final body = request.data as Map<String, dynamic>;
      final content = ((body['messages'] as List).first as Map)['content'] as List;
      final audio = (content.first as Map)['input_audio'] as Map;
      expect(audio['format'], 'wav');
      expect((audio['data'] as String).startsWith('data:audio/wav;base64,'), isTrue);
    }
    // 切片临时文件用完即删（源文件本身除外）
    expect(
      tmp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('chunk_')),
      isEmpty,
    );
  });

  test('片数超上限 → 明确提示过长的录音', () async {
    final path = '${tmp.path}/huge.wav';
    File(path).writeAsBytesSync(_wav(20));
    final adapter = _FakeAdapter((_, __) async => _text('x'));
    await expectLater(
      LongAudioTranscribeService.transcribe(
        path,
        dio: Dio()..httpClientAdapter = adapter,
        endpointOverride: _endpoint(),
        chunkBytes: 16000,
        maxChunkCount: 3,
      ),
      throwsA(
        isA<TranscribeException>().having(
          (e) => e.message,
          'message',
          allOf(contains('录音过长'), contains('20 秒')),
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('非 WAV（如 m4a）不切片，直接单发', () async {
    final path = '${tmp.path}/voice.m4a';
    File(path).writeAsBytesSync(List<int>.filled(200000, 9));
    final adapter = _FakeAdapter((_, __) async => _text('m4a 内容'));
    final result = await LongAudioTranscribeService.transcribe(
      path,
      dio: Dio()..httpClientAdapter = adapter,
      endpointOverride: _endpoint(),
      chunkBytes: 1000,
    );
    expect(result.chunked, isFalse);
    expect(result.text, 'm4a 内容');
    expect(adapter.requests, hasLength(1));
  });

  test('文件不存在 → 同单发的错误语义', () async {
    await expectLater(
      LongAudioTranscribeService.transcribe('${tmp.path}/none.wav'),
      throwsA(isA<TranscribeException>()),
    );
  });

  group('TranscriptMerger', () {
    test('去空白、丢空段、合并连续重复段', () {
      expect(
        TranscriptMerger.merge([' 你好 ', '', '世界', '世界', '   ']),
        '你好\n世界',
      );
      expect(TranscriptMerger.merge([]), '');
      expect(TranscriptMerger.merge(['  ']), '');
    });
  });
}
