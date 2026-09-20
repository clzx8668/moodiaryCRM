import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:moodiary/features/asr/asr_model_store.dart';
import 'package:moodiary/features/asr/asr_types.dart';
import 'package:moodiary/src/rust/api/asr_bridge.dart' as rust_asr;

/// Windows 端侧转写引擎：走 Rust（sherpa-onnx C API，运行时动态加载 DLL）。
///
/// 与 Android 的 [MethodChannelAsrEngine] 完全同构：PCM 进、文本出。
/// 差异只在"谁来跑模型"：Android = Kotlin/JNI，Windows = Rust/FFI。
///
/// 送入的 PCM 会先在 Dart 侧攒成 ~100ms 的块再交给 Rust，
/// 避免每 32ms 一次跨语言调用（bridge 调用是同步的，块太小会拖慢 UI 线程）。
class FfiAsrEngine implements OnDeviceAsrEngine {
  /// 每次提交给 Rust 的块大小（采样数）：100ms @16k
  static const int chunkSamples = 1600;

  final StreamController<AsrResult> _results =
      StreamController<AsrResult>.broadcast();
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  AsrEngineState _state = AsrEngineState.idle;
  String? _lastError;
  BigInt? _handle;
  int _segmentIndex = 0;
  bool _available = false;

  @override
  AsrEngineState get state => _state;

  @override
  Stream<AsrResult> get results => _results.stream;

  @override
  String? get lastError => _lastError;

  @override
  Future<bool> isReady() async {
    if (!Platform.isWindows) {
      _state = AsrEngineState.unavailable;
      return false;
    }
    try {
      _available = await rust_asr.asrIsAvailable();
    } catch (e) {
      // Rust 库未就绪（例如单元测试环境）→ 直接判定不可用
      _lastError = '$e';
      _available = false;
    }
    if (!_available) {
      _state = AsrEngineState.unavailable;
      return false;
    }
    if (!AsrModelStore.isReady || !AsrModelStore.hasWindowsLibs) {
      _state = AsrEngineState.unavailable;
      return false;
    }
    _state = AsrEngineState.ready;
    return true;
  }

  @override
  Future<void> init() async {
    if (_handle != null) return;
    try {
      _handle = rust_asr.asrCreate(
        modelDir: AsrModelStore.baseDir(),
        libDir: AsrModelStore.windowsLibDir(),
        numThreads: 2,
      );
      _state = AsrEngineState.ready;
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
      _state = AsrEngineState.failed;
      rethrow;
    }
  }

  @override
  Future<void> start() async {
    final handle = _handle;
    if (handle == null) throw StateError('引擎未初始化');
    _buffer.clear();
    _segmentIndex = 0;
    rust_asr.asrStart(handle: handle);
    _state = AsrEngineState.running;
  }

  @override
  Future<void> acceptPcm(Uint8List pcm) async {
    final handle = _handle;
    if (handle == null || _state != AsrEngineState.running || pcm.isEmpty) {
      return;
    }
    _buffer.add(pcm);
    final pending = _buffer.length;
    if (pending < chunkSamples * 2) return;
    final bytes = _buffer.takeBytes();
    rust_asr.asrAcceptPcm16(handle: handle, pcm: bytes);
    _emit(rust_asr.asrTakeText(handle: handle));
  }

  @override
  Future<void> stop() async {
    final handle = _handle;
    if (handle == null) return;
    try {
      if (_buffer.length >= 2) {
        final bytes = _buffer.takeBytes();
        rust_asr.asrAcceptPcm16(handle: handle, pcm: bytes);
      }
      rust_asr.asrFlush(handle: handle);
      _emit(rust_asr.asrTakeText(handle: handle));
    } catch (e) {
      _lastError = '$e';
    } finally {
      _state = AsrEngineState.ready;
    }
  }

  void _emit(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _results.add(
      AsrResult(text: t, isFinal: true, segmentIndex: _segmentIndex++),
    );
  }

  @override
  Future<void> dispose() async {
    final handle = _handle;
    _handle = null;
    if (handle != null) {
      try {
        rust_asr.asrDestroy(handle: handle);
      } catch (e) {
        if (kDebugMode) debugPrint('释放端侧引擎失败：$e');
      }
    }
    await _results.close();
    _state = AsrEngineState.idle;
  }
}
