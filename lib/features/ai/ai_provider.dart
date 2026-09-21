import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:moodiary/utils/log_util.dart';

import 'ai_config.dart';
import 'ai_composite_provider.dart';
import 'ai_capability_store.dart';
import 'ai_provider_store.dart';
import 'model_name_fix.dart';
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

  /// 非流式补全（Function Calling 工具协商）
  Future<AiChatCompletion> completeChat(
    List<AiChatMessage> messages, {
    List<AiToolDef>? tools,
  });

  /// 生成文本向量（P3.3）
  Future<List<double>> embed(String text);

}

/// 读取"当前生效的服务商/模型"展示名（如「DeepSeek · deepseek-chat」）。
///
/// 做成**顶层帮助函数**而不是接口方法：`AiProvider` 的实现有多个
/// （含测试里的 fake），往接口加方法会迫使所有实现补一遍；
/// 这里只关心"能拿到就用"，拿不到返回空串，不影响任何既有实现。
String describeProvider(AiProvider provider) {
  if (provider is AiCompositeProviderLike) {
    final like = provider as AiCompositeProviderLike;
    return like.chatLabel?.trim() ?? '';
  }
  return '';
}

/// 能描述自己模型来源的 Provider 的最小契约。
abstract class AiCompositeProviderLike {
  String? get chatLabel;
}

/// 对话消息
class AiChatMessage {
  final String role; // system / user / assistant
  final String content;

  /// 多模态图片（data URL 或公网 URL）；非空时 content 序列化为 parts 数组。
  final List<String> images;

  const AiChatMessage({
    required this.role,
    required this.content,
    this.images = const [],
  });

  bool get hasImages => images.isNotEmpty;

  Map<String, dynamic> toJson() {
    if (images.isEmpty) return {'role': role, 'content': content};
    return {
      'role': role,
      'content': [
        if (content.trim().isNotEmpty) {'type': 'text', 'text': content},
        for (final url in images)
          {
            'type': 'image_url',
            'image_url': {'url': url},
          },
      ],
    };
  }
}

/// 工具定义（Function Calling）
class AiToolDef {
  final String name;
  final String description;
  final Map<String, dynamic> parameters; // JSON Schema

  const AiToolDef({
    required this.name,
    required this.description,
    this.parameters = const {},
  });

  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

/// 模型请求的工具调用
class AiToolCall {
  final String id;
  final String name;
  final String arguments; // JSON 字符串

  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

/// 非流式补全结果（Function Calling 工具协商）
class AiChatCompletion {
  final String content;
  final List<AiToolCall> toolCalls;

  const AiChatCompletion({
    this.content = '',
    this.toolCalls = const [],
  });
}

/// 按安全存储配置创建真实 Provider
class AiProviderFactory {
  AiProviderFactory._();

  static AiProvider? _cached;

  static Future<AiProvider> load() async {
    return _cached ??= await AiCompositeProvider.fromStore();
  }

  /// 轻量模型 Provider（后台/小任务专用）：优先 light 能力指定的服务商+模型，
  /// 未指定时回退 chat 主服务商。保证能跑起来（用同一个 key），用户可换更省模型。
  static Future<AiProvider> loadLight() async {
    final providers = await AiProviderStore.loadAll();
    final caps = await AiCapabilityStore.load();
    final enabled = AiProviderStore.enabledConfigured(providers);
    if (enabled.isEmpty) return AiCompositeProvider.fromStore();

    final light = caps.light;
    var pid = light.providerId;
    if (pid.isEmpty) pid = caps.chat.providerId;

    for (final c in enabled) {
      if (c.id == pid && c.isConfigured) {
        return OpenAiCompatibleProvider(
          config: c.toAiConfig(modelOverride: light.modelName),
        );
      }
    }
    // 回退：首个启用且已配置的服务商
    for (final c in enabled) {
      if (c.isConfigured) {
        return OpenAiCompatibleProvider(
          config: c.toAiConfig(modelOverride: light.modelName),
        );
      }
    }
    return AiCompositeProvider.fromStore();
  }

  /// 视觉模型 Provider（图片理解 / OCR / 拍书）：优先 vision 能力指定的服务商+模型，
  /// 未指定时回退第一个配置了 visionModel 的服务商。
  static Future<AiProvider> loadVision() async {
    final providers = await AiProviderStore.loadAll();
    final caps = await AiCapabilityStore.load();
    final enabled = AiProviderStore.enabledConfigured(providers);
    if (enabled.isEmpty) return AiCompositeProvider.fromStore();

    final vision = caps.vision;
    var pid = vision.providerId;
    if (pid.isEmpty) {
      for (final c in enabled) {
        if (c.visionModel.isNotEmpty) {
          pid = c.id;
          break;
        }
      }
    }
    for (final c in enabled) {
      if (c.id == pid && c.isConfigured) {
        return OpenAiCompatibleProvider(
          config: c.toAiConfig(
            modelOverride: vision.modelName.isNotEmpty
                ? vision.modelName
                : c.visionModel,
          ),
        );
      }
    }
    // 回退：首个启用了视觉模型的服务商
    for (final c in enabled) {
      if (c.visionModel.isNotEmpty && c.isConfigured) {
        return OpenAiCompatibleProvider(
          config: c.toAiConfig(modelOverride: c.visionModel),
        );
      }
    }
    return AiCompositeProvider.fromStore();
  }

  /// 配置变更后失效缓存（下次 load 重新构建，复用连接优化性能）
  static void invalidate() {
    _cached = null;
  }
}

/// AI 连接测试结果
class AiConnectionResult {
  final bool ok;
  final String message;

  const AiConnectionResult({required this.ok, required this.message});
}

/// 拉取服务商官方模型列表（OpenAI 兼容 `/models` 接口）。
class AiModelsFetcher {
  AiModelsFetcher._();

  static Future<List<String>> fetchModels(
    AiConfig config, {
    Dio? dio,
  }) async {
    final client =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
    final resp = await client.get<Map<String, dynamic>>(
      '${config.baseUrl.replaceAll(RegExp(r'/+$'), '')}/models',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
    );
    final data = resp.data;
    final list = data?['data'] as List?;
    if (list == null) return [];
    return list
        .map((m) => m is Map ? m['id']?.toString() : null)
        .whereType<String>()
        .toList();
  }
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

  /// 模型名容错：服务端返回「supported API model names are …」时，
  /// 用规范名重试一次（真机实测：配置里的展示名与接口 slug 大小写不符会 400）。
  Future<Response<T>> _postWithModelFix<T>({
    required String url,
    required Map<String, dynamic> data,
    required Options options,
    required String model,
    String modelKey = 'model',
  }) async {
    Future<Response<T>> send(String name) =>
        dio.post<T>(url, options: options, data: {...data, modelKey: name});
    try {
      return await send(model);
    } on DioException catch (e) {
      final corrected = ModelNameFix.fromError(
        requested: model,
        message: serverMessage(e.response?.data),
      );
      if (corrected == null) rethrow;
      logger.i('[ai] 模型名自动纠正：$model → $corrected');
      return send(corrected);
    }
  }

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
      final response = await _postWithModelFix<ResponseBody>(
        url: config.chatCompletionsUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
        data: {
          'messages': [
            {
              'role': 'user',
              'content': AiTemplates.build(template, content),
            },
          ],
          'stream': true,
        },
        model: config.model,
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
      yield AiChunk.error(dioErrorDetail(e));
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
      final response = await _postWithModelFix<ResponseBody>(
        url: config.chatCompletionsUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
        data: {
          'messages': messages.map((m) => m.toJson()).toList(),
          'stream': true,
        },
        model: config.model,
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
      yield AiChunk.error(dioErrorDetail(e));
    } catch (e) {
      yield AiChunk.error('AI 对话失败：$e');
    }
  }

  @override
  Future<AiChatCompletion> completeChat(
    List<AiChatMessage> messages, {
    List<AiToolDef>? tools,
  }) async {
    if (!isConfigured) {
      throw StateError('AI 未配置：请先在设置中填写 API Key');
    }
    try {
      final resp = await _postWithModelFix<Map<String, dynamic>>(
        url: config.chatCompletionsUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'messages': messages.map((m) => m.toJson()).toList(),
          if (tools != null && tools.isNotEmpty)
            'tools': tools.map((t) => t.toJson()).toList(),
          'stream': false,
        },
        model: config.model,
      );
      final data = resp.data;
      final choices = data?['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return const AiChatCompletion();
      }
      final message = (choices.first as Map<String, dynamic>)['message'];
      if (message is! Map<String, dynamic>) {
        return const AiChatCompletion();
      }
      final content = message['content']?.toString() ?? '';
      final toolCalls = <AiToolCall>[];
      final rawCalls = message['tool_calls'] as List?;
      if (rawCalls != null) {
        for (final c in rawCalls.whereType<Map>()) {
          final fn = c['function'];
          if (fn is Map) {
            toolCalls.add(
              AiToolCall(
                id: c['id']?.toString() ?? '',
                name: fn['name']?.toString() ?? '',
                arguments: fn['arguments']?.toString() ?? '',
              ),
            );
          }
        }
      }
      return AiChatCompletion(content: content, toolCalls: toolCalls);
    } on DioException catch (e) {
      throw StateError(dioErrorDetail(e));
    } catch (e) {
      throw StateError('AI 调用失败：$e');
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    if (!isConfigured) {
      throw StateError('AI 未配置：请先在设置中填写 API Key');
    }
    try {
      final response = await _postWithModelFix<Map<String, dynamic>>(
        url: config.embeddingsUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
        ),
        data: {'input': text},
        model: config.effectiveEmbeddingModel,
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
      final server = serverMessage(e.response?.data);
      throw StateError(
        'Embedding 接口调用失败${code != null ? '（$code）' : ''}：'
        '请确认服务商支持 embeddings 且模型名正确（如 text-embedding-3-small）。'
        '注意：DeepSeek 暂未提供 embeddings 接口，知识库检索需使用支持 embeddings 的 OpenAI 兼容服务。'
        '${server != null ? ' 服务端提示：$server' : ''}',
      );
    }
  }

  /// 把 dio 异常转成可读错误：优先带服务端返回的具体原因
  static String dioErrorDetail(DioException e) {
    final code = e.response?.statusCode;
    final server = serverMessage(e.response?.data);
    final base = switch (code) {
      401 => 'API Key 无效（401）',
      429 => '请求过于频繁（429）',
      _ => '接口错误${code != null ? '（$code）' : ''}',
    };
    return server != null && server.isNotEmpty ? '$base：$server' : base;
  }

  /// 从响应体中提取服务端错误信息（error.message / error / message）
  static String? serverMessage(dynamic data) {
    if (data is! Map) return null;
    final error = data['error'];
    if (error is Map) {
      return error['message']?.toString() ?? error['type']?.toString();
    }
    if (error is String && error.isNotEmpty) return error;
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    return null;
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
