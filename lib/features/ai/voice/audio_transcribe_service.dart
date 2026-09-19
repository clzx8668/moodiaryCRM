import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:path/path.dart' as p;

/// 云端转写结果。
class TranscribeResult {
  const TranscribeResult({
    required this.text,
    required this.model,
    required this.strategy,
  });

  final String text;
  final String model;

  /// 实际生效的请求形态（`audio_chat` / `multipart`），便于排障。
  final String strategy;
}

/// 转写失败：message 面向用户，可直接 toast。
class TranscribeException implements Exception {
  const TranscribeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 转写端点（服务商 + 模型）。
class VoiceEndpoint {
  const VoiceEndpoint({required this.config, required this.model});

  final AiProviderConfig config;
  final String model;
}

/// 转写请求的纯函数部分（请求体/响应解析/形态选择），便于单测。
class AudioTranscribeCodec {
  AudioTranscribeCodec._();

  static const String strategyAudioChat = 'audio_chat';
  static const String strategyMultipart = 'multipart';

  /// 单次转写的音频上限（原始字节）：超过则提示缩短或改用压缩格式。
  static const int maxAudioBytes = 8 * 1024 * 1024;

  static const Set<String> _knownFormats = {
    'wav',
    'mp3',
    'm4a',
    'aac',
    'amr',
    'flac',
    'ogg',
    'opus',
    'webm',
  };

  /// 音频格式（`input_audio.format`）：按扩展名，未知按 wav。
  static String formatFor(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    return _knownFormats.contains(ext) ? ext : 'wav';
  }

  static String mimeFor(String path) {
    switch (formatFor(path)) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'amr':
        return 'audio/amr';
      case 'flac':
        return 'audio/flac';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      case 'webm':
        return 'audio/webm';
      default:
        return 'audio/wav';
    }
  }

  /// 阿里云百炼（DashScope）兼容模式没有 `/audio/transcriptions`（实测 404），
  /// 必须走 `chat/completions` + `input_audio`；其余 OpenAI 兼容服务商优先 multipart。
  static bool prefersAudioChat(String baseUrl, String model) {
    final base = baseUrl.toLowerCase();
    final name = model.toLowerCase();
    if (base.contains('dashscope') || base.contains('aliyuncs')) return true;
    if (name.contains('qwen') && name.contains('asr')) return true;
    return false;
  }

  static String audioDataUrl(String path, String base64Data) =>
      'data:${mimeFor(path)};base64,$base64Data';

  /// OpenAI 兼容的多模态消息体：`input_audio`（qwen3-asr-flash / gpt-4o-transcribe 等）。
  static Map<String, dynamic> buildAudioChatBody({
    required String model,
    required String audioDataUrl,
    required String format,
  }) => {
    'model': model,
    'messages': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'input_audio',
            'input_audio': {'data': audioDataUrl, 'format': format},
          },
        ],
      },
    ],
  };

  /// 解析 `choices[0].message.content`（字符串或 parts 数组）。
  static String? parseAudioChatText(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final message = first['message'];
    if (message is! Map) return null;
    final content = message['content'];
    if (content is String) return _clean(content);
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] != null) buffer.write(part['text']);
      }
      return _clean(buffer.toString());
    }
    return null;
  }

  /// 解析 `/audio/transcriptions` 的 `{"text": "..."}`。
  static String? parseTranscriptionText(Map<String, dynamic> json) {
    final text = json['text'];
    return text is String ? _clean(text) : null;
  }

  /// 字节数可读描述（错误提示用）。
  static String sizeLabel(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';

  static String? _clean(String raw) {
    final text = raw.trim();
    return text.isEmpty ? null : text;
  }
}

/// 语音识别端点的选择规则（纯函数）：能力配置优先，其次首个配置了语音模型的服务商。
class AudioTranscribePlanner {
  AudioTranscribePlanner._();

  static VoiceEndpoint? plan({
    required List<AiProviderConfig> providers,
    required AiCapabilitySet caps,
  }) {
    final enabled = AiProviderStore.enabledConfigured(providers);
    if (enabled.isEmpty) return null;

    final voice = caps.voice;
    var providerId = voice.providerId.trim();
    if (providerId.isEmpty) {
      providerId =
          enabled.firstWhereOrNull((c) => c.voiceModel.trim().isNotEmpty)?.id ??
          '';
    }

    AiProviderConfig? picked;
    final requestedProviderId = providerId;
    if (requestedProviderId.isNotEmpty) {
      picked = enabled.firstWhereOrNull(
        (c) => c.id == requestedProviderId && c.isConfigured,
      );
    }
    picked ??= enabled.firstWhereOrNull(
      (c) => c.voiceModel.trim().isNotEmpty && c.isConfigured,
    );
    if (picked == null) return null;

    // 能力配置里的模型名只对「它自己指定的服务商」有效；一旦回退到别的服务商，
    // 用该服务商自己的语音模型，避免把 A 家的模型名发给 B 家。
    final usesRequestedProvider =
        requestedProviderId.isNotEmpty && picked.id == requestedProviderId;
    final model = usesRequestedProvider && voice.modelName.trim().isNotEmpty
        ? voice.modelName.trim()
        : picked.voiceModel.trim().isNotEmpty
        ? picked.voiceModel.trim()
        : voice.modelName.trim();
    if (model.isEmpty) return null;
    return VoiceEndpoint(config: picked, model: model);
  }
}

/// 语音转写服务：本地音频文件 → 云端语音模型 → 文本。
///
/// 与「本机听写」（`SpeechService`，依赖系统语音）互补：不依赖设备语音服务，
/// MuMu 模拟器 / 桌面同样可用；密钥沿用「设置 → AI 设置 → 语音识别」的服务商。
class AudioTranscribeService {
  AudioTranscribeService._();

  static const String notConfiguredMessage =
      '未配置语音识别模型：请在「设置 → AI 设置 → 语音识别」选择服务商与模型'
      '（如 qwen3-asr-flash）';

  /// 当前是否已配置可用的转写端点。
  static Future<bool> isConfigured() async => await resolveEndpoint() != null;

  static Future<VoiceEndpoint?> resolveEndpoint() async {
    final providers = await AiProviderStore.loadAll();
    final caps = await AiCapabilityStore.load();
    return AudioTranscribePlanner.plan(providers: providers, caps: caps);
  }

  /// 转写本地音频文件；失败抛 [TranscribeException]（message 可直接展示）。
  static Future<TranscribeResult> transcribeFile(
    String audioPath, {
    Dio? dio,
    VoiceEndpoint? endpointOverride,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const TranscribeException('音频文件不存在');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const TranscribeException('音频文件为空');
    if (bytes.length > AudioTranscribeCodec.maxAudioBytes) {
      throw TranscribeException(
        '音频过大（${AudioTranscribeCodec.sizeLabel(bytes.length)}）：'
        '云端转写单次建议 5 分钟以内，或改用 m4a 等压缩格式',
      );
    }

    VoiceEndpoint? endpoint = endpointOverride;
    if (endpoint == null) {
      try {
        endpoint = await resolveEndpoint();
      } catch (e) {
        throw TranscribeException('读取语音识别配置失败：$e');
      }
    }
    if (endpoint == null) throw const TranscribeException(notConfiguredMessage);

    final client =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 180),
          ),
        );
    final base = endpoint.config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final authorization = 'Bearer ${endpoint.config.apiKey}';
    final order = AudioTranscribeCodec.prefersAudioChat(base, endpoint.model)
        ? const [
            AudioTranscribeCodec.strategyAudioChat,
            AudioTranscribeCodec.strategyMultipart,
          ]
        : const [
            AudioTranscribeCodec.strategyMultipart,
            AudioTranscribeCodec.strategyAudioChat,
          ];

    final errors = <String>[];
    for (final strategy in order) {
      try {
        final text = strategy == AudioTranscribeCodec.strategyAudioChat
            ? await _viaAudioChat(
                client,
                base: base,
                authorization: authorization,
                model: endpoint.model,
                audioPath: audioPath,
                bytes: bytes,
              )
            : await _viaMultipart(
                client,
                base: base,
                authorization: authorization,
                model: endpoint.model,
                audioPath: audioPath,
              );
        final trimmed = text?.trim() ?? '';
        if (trimmed.isEmpty) {
          errors.add('$strategy 返回空文本');
          continue;
        }
        return TranscribeResult(
          text: trimmed,
          model: endpoint.model,
          strategy: strategy,
        );
      } on TranscribeException catch (e) {
        errors.add(e.message);
      } catch (e) {
        errors.add(_shortError(e, strategy));
      }
    }
    throw TranscribeException('云端转写失败：${errors.join('；')}');
  }

  /// DashScope 形态：POST `/chat/completions`，content 为 `input_audio`。
  static Future<String?> _viaAudioChat(
    Dio client, {
    required String base,
    required String authorization,
    required String model,
    required String audioPath,
    required List<int> bytes,
  }) async {
    final body = AudioTranscribeCodec.buildAudioChatBody(
      model: model,
      audioDataUrl: AudioTranscribeCodec.audioDataUrl(
        audioPath,
        base64Encode(bytes),
      ),
      format: AudioTranscribeCodec.formatFor(audioPath),
    );
    final response = await client.post<Map<String, dynamic>>(
      '$base/chat/completions',
      options: Options(
        headers: {
          'Authorization': authorization,
          'Content-Type': 'application/json',
        },
      ),
      data: body,
    );
    final data = response.data;
    if (data == null) return null;
    final serverError = serverErrorOf(data);
    if (serverError != null) throw TranscribeException(serverError);
    return AudioTranscribeCodec.parseAudioChatText(data);
  }

  /// OpenAI 兼容形态：POST `/audio/transcriptions`（multipart）。
  static Future<String?> _viaMultipart(
    Dio client, {
    required String base,
    required String authorization,
    required String model,
    required String audioPath,
  }) async {
    final form = FormData.fromMap({
      'model': model,
      'file': await MultipartFile.fromFile(
        audioPath,
        filename: p.basename(audioPath),
        contentType: DioMediaType.parse(
          AudioTranscribeCodec.mimeFor(audioPath),
        ),
      ),
    });
    final response = await client.post<Map<String, dynamic>>(
      '$base/audio/transcriptions',
      options: Options(headers: {'Authorization': authorization}),
      data: form,
    );
    final data = response.data;
    if (data == null) return null;
    final serverError = serverErrorOf(data);
    if (serverError != null) throw TranscribeException(serverError);
    return AudioTranscribeCodec.parseTranscriptionText(data);
  }

  /// 服务端用「HTTP 200 + 业务错误码」返回时（如
  /// `{"code":2001,"message":"Model ... carefully.","data":null}`），
  /// 直接把服务端 message 抛出来——比「返回空文本」有用得多（真机踩到过）。
  static String? serverErrorOf(Map<String, dynamic>? data) {
    if (data == null) return null;
    final message = (data['message'] ?? '').toString().trim();
    if (message.isEmpty) return null;
    final hasText =
        (data['text'] ?? '').toString().trim().isNotEmpty ||
        data['data'] is String ||
        data['data'] is Map;
    if (hasText) return null;
    final code = data['code'];
    final lower = message.toLowerCase();
    final hint = lower.contains('model')
        ? '（请核对 设置 → AI 设置 → 语音识别模型 的模型名）'
        : '';
    return '转写服务返回错误${code == null ? '' : '（$code）'}：$message$hint';
  }

  static String _shortError(Object error, String strategy) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      final detail = error.response?.data?.toString() ?? error.message ?? '';
      final trimmed = detail.length > 160 ? detail.substring(0, 160) : detail;
      return '$strategy${code == null ? '' : ' HTTP $code'}：$trimmed';
    }
    return '$strategy：$error';
  }
}
