@Tags(['asr_cloud'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/features/ai/voice/audio_transcribe_service.dart';

/// 真实云端转写联调（默认跳过）。
///
/// 运行方式（密钥只从环境变量读，不落盘、不入库）：
/// ```powershell
/// $env:MOODIARY_ASR_API_KEY = '<百炼 API Key>'
/// $env:MOODIARY_ASR_SAMPLE   = 'C:\path\to\样本.wav'
/// flutter test --tags asr_cloud --run-skipped `
///   test/integration/audio_transcribe_integration_test.dart
/// ```
/// 可选 `MOODIARY_ASR_BASE_URL`（默认百炼 compatible-mode）、
/// `MOODIARY_ASR_MODEL`（默认 qwen3-asr-flash）。
void main() {
  test('百炼 qwen3-asr-flash：真实音频 → 文本（audio_chat 形态）', () async {
    final apiKey = Platform.environment['MOODIARY_ASR_API_KEY'] ?? '';
    final samplePath = Platform.environment['MOODIARY_ASR_SAMPLE'] ?? '';
    if (apiKey.trim().isEmpty || samplePath.trim().isEmpty) {
      markTestSkipped('未提供 MOODIARY_ASR_API_KEY / MOODIARY_ASR_SAMPLE');
      return;
    }
    if (!File(samplePath).existsSync()) {
      fail('样本音频不存在：$samplePath');
    }

    final config = AiProviderConfig()
      ..name = '百炼探针'
      ..baseUrl =
          Platform.environment['MOODIARY_ASR_BASE_URL'] ??
          'https://dashscope.aliyuncs.com/compatible-mode/v1'
      ..apiKey = apiKey
      ..voiceModel =
          Platform.environment['MOODIARY_ASR_MODEL'] ?? 'qwen3-asr-flash';

    final result = await AudioTranscribeService.transcribeFile(
      samplePath,
      endpointOverride: VoiceEndpoint(
        config: config,
        model: config.voiceModel,
      ),
    );

    expect(result.strategy, AudioTranscribeCodec.strategyAudioChat);
    expect(result.model, config.voiceModel);
    expect(result.text.trim(), isNotEmpty);
    // 探针音频固定内容（见 docs/开发进度.md 批次 69）：只校验关键实体，避免朗读差异
    expect(result.text.contains('李总'), isTrue, reason: result.text);
    expect(result.text.contains('菲律宾'), isTrue, reason: result.text);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
