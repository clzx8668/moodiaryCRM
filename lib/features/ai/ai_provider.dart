import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'ai_config.dart';
import 'ai_composite_provider.dart';
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

  /// 多轮对话（RAG 工作台，P3.4）
  Stream<AiChunk> streamChat(List<AiChatMessage> messages);

  /// 生成文本向量（P3.3）
  Future<List<double>> embed(String text);
}

/// 对话消息
class AiChatMessage {
  final String role; // system / user / assistant
  final String content;

  const AiChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// 按安全存储配置创建真实 Provider
class AiProviderFactory {
  AiProviderFactory._();

  static Future<AiProvider> load() async {
    return AiCompositeProvider.fromStore();
  }
}

/// AI 连接测试结果
class AiConnectionResult {
  final bool ok;
  final String message;

  const AiConnectionResult({required this.ok, required this.message});
}

/// 连接测试：优先探测 `/models` 接口，不支持时回退最小 chat 请求。
class AiConnectionTester {
  AiConnectionTester._();

  static Future<AiConnectionResult> test(
    AiConfig config, {
    Dio? dio,
  }) async {
    final client =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
    final headers = {
      'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
    };

    // 1) /models 探测（OpenAI 兼容标准）
    try {
      final resp = await client.get<Map<String, dynamic>>(
        '${config.baseUrl.replaceAll(RegExp(r'/+$'), '')}/models',
        options: Options(headers: headers),
      );
      final data = resp.data;
      final models = data?['data'] as List?;
      if (models != null) {
        final names = models
            .map((m) => (m as Map<String, dynamic>)['id']?.toString())
            .whereType<String>()
            .take(5)
            .join(', ');
        return AiConnectionResult(
          ok: true,
          message: '连接成功，模型列表：${names.isEmpty ? '（空）' : names}',
        );
      }
      return const AiConnectionResult(ok: true, message: '连接成功');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return const AiConnectionResult(ok: false, message: 'API Key 无效（401）');
      }
      if (e.response?.statusCode == 404 || e.response?.statusCode == 400) {
        // 部分服务商不支持 /models，回退最小 chat 请求
        return _pingChat(client, config, headers);
      }
      final code = e.response?.statusCode;
      if (code != null) {
        return AiConnectionResult(
          ok: false,
          message: '接口返回 $code：${e.message}',
        );
      }
      return AiConnectionResult(ok: false, message: '网络错误：${e.message}');
    }
  }

  static Future<AiConnectionResult> _pingChat(
    Dio client,
    AiConfig config,
    Map<String, String> headers,
  ) async {
    try {
      await client.post<Map<String, dynamic>>(
        config.chatCompletionsUrl,
        options: Options(headers: headers),
        data: {
          'model': config.model,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 1,
          'stream': false,
        },
      );
      return const AiConnectionResult(ok: true, message: '连接成功（chat 接口可用）');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final detail = code == 401
          ? 'API Key 无效（401）'
          : code == 404
          ? '接口路径不存在（404），请检查 Base URL'
          : '${e.message}';
      return AiConnectionResult(ok: false, message: '连接失败：$detail');
    }
  }
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

  @override
  Stream<AiChunk> streamChat(List<AiChatMessage> messages) async* {
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
          'messages': messages.map((m) => m.toJson()).toList(),
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
      yield AiChunk.error('AI 对话失败：$e');
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    if (!isConfigured) {
      throw StateError('AI 未配置：请先在设置中填写 API Key');
    }
    try {
      final response = await dio.post<Map<String, dynamic>>(
        config.embeddingsUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': config.effectiveEmbeddingModel,
          'input': text,
        },
      );
      final data = response.data;
      final list = data?['data'] as List?;
      if (list == null || list.isEmpty) {
        throw StateError('Embedding 响应为空');
      }
      final embedding =
          (list.first as Map<String, dynamic>)['embedding'] as List;
      return embedding.cast<num>().map((e) => e.toDouble()).toList();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      throw StateError(
        'Embedding 接口调用失败${code != null ? '（$code）' : ''}：'
        '请确认服务商支持 embeddings 且模型名正确（如 text-embedding-3-small）。'
        '注意：DeepSeek 暂未提供 embeddings 接口，知识库检索需使用支持 embeddings 的 OpenAI 兼容服务。'
        '${e.response?.data is Map ? ' 服务端提示：${(e.response!.data as Map)["message"] ?? (e.response!.data as Map)["error"] ?? ""}' : ''}',
      );
    }
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
