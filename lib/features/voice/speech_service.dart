import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音识别服务（Android 系统语音识别 / Windows SAPI）。
///
/// 全局单例：惰性初始化，识别结果以「最终结果」回调给调用方。
/// 通过 [status] / [error] 暴露实时状态，供 UI 展示「识别中」等反馈。
class SpeechService {
  SpeechService._();

  static final SpeechService instance = SpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _available = false;

  /// 最近一次识别状态：`idle` / `listening` / `notListening` / `done` / `error`。
  final ValueNotifier<String> status = ValueNotifier<String>('idle');

  /// 最近一次识别错误信息（无错误时为 null）。
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  bool get isAvailable => _available;

  bool get isListening => _speech.isListening;

  /// 初始化（幂等）；返回当前设备是否支持语音识别。
  Future<bool> ensureAvailable() async {
    if (_initialized) return _available;
    _initialized = true;
    _available = await _speech.initialize(
      onStatus: (s) => status.value = s,
      onError: (e) {
        error.value = e.errorMsg;
        status.value = 'error';
      },
    );
    return _available;
  }

  /// 开始监听（中文）。识别出最终结果后回调 [onResult]。
  Future<bool> startListening(void Function(String text) onResult) async {
    final ok = await ensureAvailable();
    if (!ok) return false;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'zh_CN',
      ),
    );
    return true;
  }

  /// 停止监听（手动结束）。
  Future<void> stopListening() => _speech.stop();
}
