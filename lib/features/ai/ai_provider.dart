import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'ai_config.dart';
import 'prompts.dart';

/// AI 处理结果分块
class AiChunk {
  final String text;
  final bool done;
  final String? error;

  const AiChunk({this.text = '', this.done = false, this.error});

  factory AiChunk.error(String message) => AiChunk(error: message);
}

/// AI Provider 抽象：模板处理 / 语音转录 / Embedding 的统一入口。
///
/// 首期实现 OpenAI 兼容的 [OpenAiCompatibleProvider]（DeepSeek 等）；
/// 后续语音（P2.7.6）与向量化（P3.x）复用同一抽象。
abstract class AiProvider {
  bool get isConfigured;

  /// 按模板流式处理内容
  Stream<AiChunk> streamTemplate({
    required String content,
    required String template,
  });
}

/// OpenAI 兼容实现（`/chat/completions` + SSE 流式）。
class OpenAiCompatibleProvider implements AiProvider {
  final AiConfig config;
  final Dio dio;

  OpenAiCompatibleProvider({
    required this.config,
    Dio? dio,
  }) : dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: Duration(seconds: config.timeoutSeconds),
              ),
            );

  @override
  bool get isConfigured => config.isConfigured;

  @override
  Stream<AiChunk> streamTemplate({
    required String content,
    required String template,
  }) async* {
    if (!isConfigured) {
      yield AiChunk.error('AI 未配置：请先在设置中填写 API Key');
      return;
    }
    try {
      final response = await dio.post<ResponseBody>(
        config.chatCompletionsUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
        data: {
          'model': config.model,
          'messages': [
            {
              'role': 'user',
              'content': AiTemplates.build(template, content),
            },
          ],
          'stream': true,
        },
      );
      final body = response.data;
      if (body == null) {
        yield AiChunk.error('AI 响应为空');
        return;
      }
      await for (final chunk in _decodeSse(body.stream)) {
        yield chunk;
      }
    } on DioException catch (e) {
      final detail = e.response?.statusCode == 401
          ? 'API Key 无效（401）'
          : e.response?.statusCode == 429
          ? '请求过于频繁（429）'
          : '网络错误：${e.message}';
      yield AiChunk.error(detail);
    } catch (e) {
      yield AiChunk.error('AI 处理失败：$e');
    }
  }

  /// 解析 SSE 字节流：`data: {"choices":[{"delta":{"content":"..."}}]}`
  Stream<AiChunk> _decodeSse(Stream<Uint8List> bytes) async* {
    var buffer = '';
    await for (final chunk in utf8.decoder.bind(bytes)) {
      buffer += chunk;
      var newline = buffer.indexOf('\n');
      while (newline >= 0) {
        final line = buffer.substring(0, newline).trim();
        buffer = buffer.substring(newline + 1);
        if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (data == '[DONE]') {
            yield const AiChunk(done: true);
            return;
          }
          final delta = _extractDelta(data);
          if (delta != null && delta.isNotEmpty) {
            yield AiChunk(text: delta);
          }
        }
        newline = buffer.indexOf('\n');
      }
    }
    // 流结束兜底
    if (buffer.trim().isNotEmpty && buffer.trim().startsWith('data:')) {
      final data = buffer.substring(5).trim();
      if (data != '[DONE]') {
        final delta = _extractDelta(data);
        if (delta != null && delta.isNotEmpty) {
          yield AiChunk(text: delta);
        }
      }
    }
    yield const AiChunk(done: true);
  }

  String? _extractDelta(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final delta = (choices.first as Map<String, dynamic>)['delta'];
      if (delta is Map<String, dynamic>) {
        final content = delta['content'];
        if (content is String) return content;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
