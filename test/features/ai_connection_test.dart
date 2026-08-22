import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/ai_config.dart';
import 'package:moodiary/features/ai/ai_provider.dart';

/// 按路径返回不同响应的假适配器
class _FakeAdapter implements HttpClientAdapter {
  final int modelsStatus;
  final Map<String, dynamic> modelsBody;
  final int chatStatus;

  _FakeAdapter({
    this.modelsStatus = 200,
    this.modelsBody = const {'data': [{'id': 'deepseek-chat'}]},
    this.chatStatus = 200,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isModels = options.path.contains('/models');
    final status = isModels ? modelsStatus : chatStatus;
    final body = isModels ? modelsBody : <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AiConfig _config() => const AiConfig(
  baseUrl: 'https://example.com/v1',
  apiKey: 'test-key',
  model: 'deepseek-chat',
);

void main() {
  test('/models 200 返回模型列表', () async {
    final dio = Dio()..httpClientAdapter = _FakeAdapter();
    final result = await AiConnectionTester.test(_config(), dio: dio);
    expect(result.ok, isTrue);
    expect(result.message, contains('deepseek-chat'));
  });

  test('401 报告 API Key 无效', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(modelsStatus: 401, modelsBody: {});
    final result = await AiConnectionTester.test(_config(), dio: dio);
    expect(result.ok, isFalse);
    expect(result.message, contains('401'));
  });

  test('/models 404 回退 chat 接口并成功', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(modelsStatus: 404, modelsBody: {});
    final result = await AiConnectionTester.test(_config(), dio: dio);
    expect(result.ok, isTrue);
    expect(result.message, contains('chat 接口可用'));
  });

  test('/models 400 同样回退 chat 接口并成功', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(modelsStatus: 400, modelsBody: {});
    final result = await AiConnectionTester.test(_config(), dio: dio);
    expect(result.ok, isTrue);
    expect(result.message, contains('chat 接口可用'));
  });

  test('500 返回失败信息', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(
        modelsStatus: 500,
        modelsBody: {},
        chatStatus: 500,
      );
    final result = await AiConnectionTester.test(_config(), dio: dio);
    expect(result.ok, isFalse);
  });

  group('AiModelsFetcher', () {
    test('解析 /models 官方模型列表', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          modelsBody: {
            'data': [
              {'id': 'deepseek-chat'},
              {'id': 'deepseek-reasoner'},
            ],
          },
        );
      final models = await AiModelsFetcher.fetchModels(_config(), dio: dio);
      expect(models, ['deepseek-chat', 'deepseek-reasoner']);
    });

    test('空列表返回空', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(modelsBody: {'data': []});
      final models = await AiModelsFetcher.fetchModels(_config(), dio: dio);
      expect(models, isEmpty);
    });
  });

  group('OpenAiCompatibleProvider 错误详情', () {
    test('serverMessage 提取服务端错误信息', () {
      expect(
        OpenAiCompatibleProvider.serverMessage({
          'error': {'message': 'Model Not Exist'},
        }),
        'Model Not Exist',
      );
      expect(
        OpenAiCompatibleProvider.serverMessage({'error': 'bad key'}),
        'bad key',
      );
      expect(
        OpenAiCompatibleProvider.serverMessage({'message': '限流'}),
        '限流',
      );
      expect(OpenAiCompatibleProvider.serverMessage(null), isNull);
      expect(
        OpenAiCompatibleProvider.serverMessage({'data': []}),
        isNull,
      );
    });

    test('dioErrorDetail 带服务端原因', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/chat/completions'),
        response: Response(
          requestOptions: RequestOptions(path: '/chat/completions'),
          statusCode: 400,
          data: {
            'error': {'message': 'Invalid model: xxx'},
          },
        ),
      );
      final detail = OpenAiCompatibleProvider.dioErrorDetail(e);
      expect(detail, contains('400'));
      expect(detail, contains('Invalid model: xxx'));
    });
  });
}
