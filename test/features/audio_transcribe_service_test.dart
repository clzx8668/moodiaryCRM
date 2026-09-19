import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/features/ai/voice/audio_transcribe_service.dart';

/// 假适配器：记录请求，返回预置响应（不发真实网络请求）。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

AiProviderConfig _provider({
  String id = 'p1',
  String name = '阿里云百炼',
  String baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  String apiKey = 'sk-test',
  String voiceModel = '',
  bool enabled = true,
}) {
  return AiProviderConfig()
    ..id = id
    ..name = name
    ..baseUrl = baseUrl
    ..apiKey = apiKey
    ..voiceModel = voiceModel
    ..enabled = enabled;
}

AiCapabilitySet _caps({
  String providerId = '',
  String modelName = '',
  bool enabled = true,
}) {
  return AiCapabilitySet(
    voice: AiCapabilityConfig(
      id: 'voice',
      enabled: enabled,
      providerId: providerId,
      modelName: modelName,
    ),
  );
}

void main() {
  group('AudioTranscribeCodec 格式与形态', () {
    test('音频格式按扩展名归一，未知回退 wav', () {
      expect(AudioTranscribeCodec.formatFor('a/b/rec.wav'), 'wav');
      expect(AudioTranscribeCodec.formatFor('a/b/rec.M4A'), 'm4a');
      expect(AudioTranscribeCodec.formatFor('rec.mp3'), 'mp3');
      expect(AudioTranscribeCodec.formatFor('rec.unknown'), 'wav');
      expect(AudioTranscribeCodec.formatFor('rec'), 'wav');
    });

    test('mime 与格式一致', () {
      expect(AudioTranscribeCodec.mimeFor('rec.wav'), 'audio/wav');
      expect(AudioTranscribeCodec.mimeFor('rec.m4a'), 'audio/mp4');
      expect(AudioTranscribeCodec.mimeFor('rec.mp3'), 'audio/mpeg');
    });

    test('百炼/DashScope 走 audio_chat，其余走 multipart', () {
      expect(
        AudioTranscribeCodec.prefersAudioChat(
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
          'qwen3-asr-flash',
        ),
        isTrue,
      );
      expect(
        AudioTranscribeCodec.prefersAudioChat(
          'https://api.siliconflow.cn/v1',
          'Qwen3-ASR',
        ),
        isTrue,
      );
      expect(
        AudioTranscribeCodec.prefersAudioChat(
          'https://api.openai.com/v1',
          'whisper-1',
        ),
        isFalse,
      );
    });

    test('audio_chat 请求体为 input_audio + data URL', () {
      final body = AudioTranscribeCodec.buildAudioChatBody(
        model: 'qwen3-asr-flash',
        audioDataUrl: AudioTranscribeCodec.audioDataUrl('rec.wav', 'QUJD'),
        format: AudioTranscribeCodec.formatFor('rec.wav'),
      );
      expect(body['model'], 'qwen3-asr-flash');
      final messages = body['messages'] as List;
      final content = (messages.first as Map)['content'] as List;
      final part = content.first as Map;
      expect(part['type'], 'input_audio');
      final audio = part['input_audio'] as Map;
      expect(audio['data'], 'data:audio/wav;base64,QUJD');
      expect(audio['format'], 'wav');
    });

    test('解析 choices[0].message.content（字符串 / parts 数组）', () {
      expect(
        AudioTranscribeCodec.parseAudioChatText({
          'choices': [
            {
              'message': {'content': ' 你好，记一下 '},
            },
          ],
        }),
        '你好，记一下',
      );
      expect(
        AudioTranscribeCodec.parseAudioChatText({
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'text', 'text': '第一段'},
                  {'type': 'text', 'text': '，第二段'},
                ],
              },
            },
          ],
        }),
        '第一段，第二段',
      );
      expect(AudioTranscribeCodec.parseAudioChatText({'choices': []}), isNull);
      expect(
        AudioTranscribeCodec.parseAudioChatText({
          'choices': [
            {
              'message': {'content': '   '},
            },
          ],
        }),
        isNull,
      );
      expect(AudioTranscribeCodec.parseAudioChatText({}), isNull);
    });

    test('解析 /audio/transcriptions 的 text 字段', () {
      expect(
        AudioTranscribeCodec.parseTranscriptionText({'text': ' 转写结果 '}),
        '转写结果',
      );
      expect(AudioTranscribeCodec.parseTranscriptionText({'text': ''}), isNull);
      expect(
        AudioTranscribeCodec.parseTranscriptionText({'error': 'x'}),
        isNull,
      );
    });

    test('sizeLabel 保留一位小数', () {
      expect(AudioTranscribeCodec.sizeLabel(0), '0.0MB');
      expect(AudioTranscribeCodec.sizeLabel(9 * 1024 * 1024), '9.0MB');
    });
  });

  group('AudioTranscribePlanner 端点选择', () {
    test('优先使用语音能力指定的服务商与模型', () {
      final a = _provider(id: 'a', name: 'A', voiceModel: 'whisper-1');
      final b = _provider(id: 'b', name: 'B', voiceModel: 'qwen3-asr-flash');
      final endpoint = AudioTranscribePlanner.plan(
        providers: [a, b],
        caps: _caps(providerId: 'b', modelName: 'qwen3-asr-flash'),
      );
      expect(endpoint?.config.id, 'b');
      expect(endpoint?.model, 'qwen3-asr-flash');
    });

    test('能力未指定服务商时回退到首个配置了语音模型的服务商', () {
      final a = _provider(id: 'a', name: 'A', voiceModel: '');
      final b = _provider(id: 'b', name: 'B', voiceModel: 'qwen3-asr-flash');
      final endpoint = AudioTranscribePlanner.plan(
        providers: [a, b],
        caps: _caps(),
      );
      expect(endpoint?.config.id, 'b');
      expect(endpoint?.model, 'qwen3-asr-flash');
    });

    test('能力选了服务商但模型名为空时取该服务商的语音模型', () {
      final endpoint = AudioTranscribePlanner.plan(
        providers: [_provider(id: 'b', voiceModel: 'qwen3-asr-flash')],
        caps: _caps(providerId: 'b'),
      );
      expect(endpoint?.model, 'qwen3-asr-flash');
    });

    test('没有语音模型 / 服务商未配置 / 已禁用 → 返回 null', () {
      expect(
        AudioTranscribePlanner.plan(
          providers: [_provider(voiceModel: '')],
          caps: _caps(modelName: 'qwen3-asr-flash'),
        ),
        isNull,
      );
      expect(
        AudioTranscribePlanner.plan(
          providers: [_provider(apiKey: '', voiceModel: 'qwen3-asr-flash')],
          caps: _caps(),
        ),
        isNull,
      );
      expect(
        AudioTranscribePlanner.plan(
          providers: [_provider(enabled: false, voiceModel: 'qwen3-asr-flash')],
          caps: _caps(),
        ),
        isNull,
      );
    });

    test('能力指定的服务商若不可用则回退到其它可用的语音服务商', () {
      final endpoint = AudioTranscribePlanner.plan(
        providers: [
          _provider(id: 'a', name: 'A', voiceModel: 'qwen3-asr-flash'),
          _provider(
            id: 'b',
            name: 'B',
            voiceModel: 'whisper-1',
            enabled: false,
          ),
        ],
        caps: _caps(providerId: 'b', modelName: 'whisper-1'),
      );
      expect(endpoint?.config.id, 'a');
      expect(endpoint?.model, 'qwen3-asr-flash');
    });
  });

  group('transcribeFile 请求形态（假适配器）', () {
    late Directory tmp;
    late String audioPath;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('transcribe_test_');
      audioPath = '${tmp.path}/sample.wav';
      File(audioPath).writeAsBytesSync(List<int>.filled(64, 7));
    });

    tearDown(() {
      // Windows 下 MultipartFile 仍持有文件句柄，清理失败不影响断言
      try {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // ignore
      }
    });

    Dio dioWith(_FakeAdapter adapter) => Dio()..httpClientAdapter = adapter;

    test('非百炼服务商：优先 multipart /audio/transcriptions', () async {
      final adapter = _FakeAdapter((_) async => _json({'text': '  转写好了 '}));
      final result = await AudioTranscribeService.transcribeFile(
        audioPath,
        dio: dioWith(adapter),
        endpointOverride: VoiceEndpoint(
          config: _provider(
            baseUrl: 'https://api.example.com/v1',
            voiceModel: 'whisper-1',
          ),
          model: 'whisper-1',
        ),
      );

      expect(result.strategy, AudioTranscribeCodec.strategyMultipart);
      expect(result.text, '转写好了');
      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.com/v1/audio/transcriptions',
      );
      final form = adapter.requests.single.data as FormData;
      expect(
        form.fields.any((f) => f.key == 'model' && f.value == 'whisper-1'),
        isTrue,
      );
      expect(form.files.single.key, 'file');
    });

    test('百炼：优先 audio_chat，命中后不再走 multipart', () async {
      final adapter = _FakeAdapter(
        (_) async => _json({
          'choices': [
            {
              'message': {'content': '明天十点给李总回电'},
            },
          ],
        }),
      );
      final result = await AudioTranscribeService.transcribeFile(
        audioPath,
        dio: dioWith(adapter),
        endpointOverride: VoiceEndpoint(
          config: _provider(),
          model: 'qwen3-asr-flash',
        ),
      );

      expect(result.strategy, AudioTranscribeCodec.strategyAudioChat);
      expect(result.text, '明天十点给李总回电');
      expect(
        adapter.requests.single.uri.toString(),
        contains('/chat/completions'),
      );
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['model'], 'qwen3-asr-flash');
    });

    test('首选形态失败 → 回退另一种形态', () async {
      final calls = <String>[];
      final adapter = _FakeAdapter((options) async {
        calls.add(options.uri.path);
        if (options.uri.path.endsWith('/chat/completions')) {
          return _json({'error': 'model not found'}, status: 404);
        }
        return _json({'text': '回退成功'});
      });
      final result = await AudioTranscribeService.transcribeFile(
        audioPath,
        dio: dioWith(adapter),
        endpointOverride: VoiceEndpoint(
          config: _provider(),
          model: 'qwen3-asr-flash',
        ),
      );

      expect(result.strategy, AudioTranscribeCodec.strategyMultipart);
      expect(result.text, '回退成功');
      expect(calls, [
        '/compatible-mode/v1/chat/completions',
        '/compatible-mode/v1/audio/transcriptions',
      ]);
    });

    test('两种形态都失败 → 抛出可直接展示的错误', () async {
      final adapter = _FakeAdapter(
        (_) async => _json({'error': 'boom'}, status: 400),
      );
      await expectLater(
        AudioTranscribeService.transcribeFile(
          audioPath,
          dio: dioWith(adapter),
          endpointOverride: VoiceEndpoint(
            config: _provider(),
            model: 'qwen3-asr-flash',
          ),
        ),
        throwsA(
          isA<TranscribeException>().having(
            (e) => e.message,
            'message',
            allOf(contains('云端转写失败'), contains('400')),
          ),
        ),
      );
    });

    test('未配置语音模型时不发请求', () async {
      final adapter = _FakeAdapter((_) async => _json({'text': 'x'}));
      await expectLater(
        AudioTranscribeService.transcribeFile(audioPath, dio: dioWith(adapter)),
        throwsA(isA<TranscribeException>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('文件不存在 / 过大 → 提前拦截', () async {
      final adapter = _FakeAdapter((_) async => _json({'text': 'x'}));
      final dio = dioWith(adapter);
      await expectLater(
        AudioTranscribeService.transcribeFile(
          '${tmp.path}/missing.wav',
          dio: dio,
        ),
        throwsA(
          isA<TranscribeException>().having(
            (e) => e.message,
            'message',
            contains('不存在'),
          ),
        ),
      );

      final big = '${tmp.path}/big.wav';
      File(big).writeAsBytesSync(
        List<int>.filled(AudioTranscribeCodec.maxAudioBytes + 1, 1),
      );
      await expectLater(
        AudioTranscribeService.transcribeFile(big, dio: dio),
        throwsA(
          isA<TranscribeException>().having(
            (e) => e.message,
            'message',
            contains('音频过大'),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('serverErrorOf（HTTP 200 + 业务错误码）', () {
    test('真机返回体：code 2001 + message → 带错误码与模型名提示', () {
      final message = AudioTranscribeService.serverErrorOf({
        'code': 2001,
        'message': 'Model not supported, please check carefully.',
        'data': null,
      });
      expect(message, isNotNull);
      expect(message, contains('2001'));
      expect(message, contains('Model not supported'));
      expect(message, contains('语音识别模型'));
    });

    test('正常返回（text 非空）→ 不算错误', () {
      expect(AudioTranscribeService.serverErrorOf({'text': '今天开了个会'}), isNull);
      expect(
        AudioTranscribeService.serverErrorOf({
          'message': 'ok',
          'data': {'text': '正文'},
        }),
        isNull,
      );
    });

    test('无 message / 空结构 → 不算错误（交给原有解析逻辑）', () {
      expect(AudioTranscribeService.serverErrorOf(null), isNull);
      expect(AudioTranscribeService.serverErrorOf(const {}), isNull);
      expect(
        AudioTranscribeService.serverErrorOf(const {'code': 2001}),
        isNull,
      );
    });
  });
}
