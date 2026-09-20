import 'dart:async';

import 'package:flutter/services.dart';
import 'package:moodiary/features/asr/asr_model_store.dart';
import 'package:moodiary/features/asr/asr_types.dart';

/// Android 端侧转写引擎：走 `asr_channel` → sherpa-onnx（silero VAD + Paraformer int8）。
///
/// 其它平台目前没有实现；[isReady] 会返回 false，上层自动退回云端转写。
class MethodChannelAsrEngine implements OnDeviceAsrEngine {
  MethodChannelAsrEngine({MethodChannel? channel, String? modelDir})
    : _channel = channel ?? const MethodChannel('asr_channel'),
      _modelDir = modelDir;

  final MethodChannel _channel;
  final String? _modelDir;

  final StreamController<AsrResult> _results =
      StreamController<AsrResult>.broadcast();
  AsrEngineState _state = AsrEngineState.idle;
  String? _lastError;
  bool _handlerBound = false;
  int _segmentCount = 0;

  @override
  AsrEngineState get state => _state;

  @override
  Stream<AsrResult> get results => _results.stream;

  @override
  String? get lastError => _lastError;

  String get modelDir => _modelDir ?? AsrModelStore.baseDir();

  void _bindHandler() {
    if (_handlerBound) return;
    _handlerBound = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onResult':
          final args = (call.arguments as Map?) ?? const {};
          final text = (args['text'] as String? ?? '').trim();
          if (text.isEmpty) return null;
          final index = (args['index'] as num?)?.toInt() ?? _segmentCount;
          _segmentCount = index + 1;
          _results.add(
            AsrResult(
              text: text,
              isFinal: args['final'] as bool? ?? true,
              segmentIndex: index,
            ),
          );
        case 'onError':
          _lastError = call.arguments as String?;
        default:
      }
      return null;
    });
  }

  @override
  Future<bool> isReady() async {
    // 文件就绪 + 平台侧能建引擎（status 不加载模型，仅查文件）
    if (!AsrModelStore.isReady) return false;
    try {
      final status = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'status',
      );
      final ready = status?['ready'] as bool? ?? false;
      _state = ready ? AsrEngineState.ready : AsrEngineState.unavailable;
      return ready;
    } on MissingPluginException {
      _state = AsrEngineState.unavailable;
      return false;
    } catch (e) {
      _lastError = '$e';
      _state = AsrEngineState.unavailable;
      return false;
    }
  }

  @override
  Future<void> init() async {
    _bindHandler();
    try {
      await _channel.invokeMethod<bool>('init', {'modelDir': modelDir});
      _state = AsrEngineState.ready;
      _lastError = null;
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
      _state = AsrEngineState.failed;
      rethrow;
    } catch (e) {
      _lastError = '$e';
      _state = AsrEngineState.failed;
      rethrow;
    }
  }

  @override
  Future<void> start() async {
    _bindHandler();
    _segmentCount = 0;
    _lastError = null;
    await _channel.invokeMethod<bool>('start');
    _state = AsrEngineState.running;
  }

  @override
  Future<void> acceptPcm(Uint8List pcm) async {
    if (_state != AsrEngineState.running || pcm.isEmpty) return;
    // 直接传 ByteArray（避免 List<int> 装箱开销）
    await _channel.invokeMethod<void>('acceptPcm', pcm);
  }

  @override
  Future<void> stop() async {
    if (_state != AsrEngineState.running) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } finally {
      _state = AsrEngineState.ready;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<bool>('release');
    } catch (_) {
      // 平台不支持时忽略
    }
    await _results.close();
    _state = AsrEngineState.idle;
  }
}
