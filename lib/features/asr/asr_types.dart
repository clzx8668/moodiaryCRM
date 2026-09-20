import 'dart:typed_data';

/// 端侧转写引擎的运行状态。
enum AsrEngineState {
  /// 未初始化（还没调用 init）
  idle,

  /// 模型/运行库缺失或加载失败
  unavailable,

  /// 就绪，可接收音频
  ready,

  /// 正在识别
  running,

  /// 运行期错误（可重试）
  failed,
}

/// 端侧转写的一段结果。
class AsrResult {
  /// 识别文本（可能为空：VAD 判定为纯静音段时的空返回）
  final String text;

  /// 是否为该句的最终结果（端侧为"整句返回"模式，恒为 true；
  /// 保留字段以便将来接流式模型时区分中间态）
  final bool isFinal;

  /// 句子序号（从 0 递增，便于 UI 拼接与去重）
  final int segmentIndex;

  /// 是否来自端侧（false = 云端兜底结果）
  final bool onDevice;

  const AsrResult({
    required this.text,
    this.isFinal = true,
    this.segmentIndex = 0,
    this.onDevice = true,
  });

  @override
  String toString() =>
      'AsrResult($segmentIndex, final=$isFinal, onDevice=$onDevice, "$text")';
}

/// 端侧转写引擎的统一接口。
///
/// 平台实现：
/// - Android：`MethodChannelAsrEngine`（sherpa-onnx Kotlin API：VAD + Paraformer int8）；
/// - Windows（后续）：`FfiAsrEngine`（sherpa-onnx C API）。
/// 两者对上层只暴露「喂 PCM 进、出文本」这一件事。
abstract class OnDeviceAsrEngine {
  AsrEngineState get state;

  /// 识别结果流（每句一次）；失败时抛出的异常由调用方兜底
  Stream<AsrResult> get results;

  /// 最近一次错误信息（用于 UI 提示）
  String? get lastError;

  /// 模型与运行库是否就绪（不触发加载）
  Future<bool> isReady();

  /// 加载模型（幂等）
  Future<void> init();

  /// 开始一次会话（清空内部缓冲）
  Future<void> start();

  /// 送入一段 PCM（16kHz / 单声道 / int16 小端）
  Future<void> acceptPcm(Uint8List pcm);

  /// 结束会话：把尾段吐出（VAD 未闭合的语音也会被识别）
  Future<void> stop();

  Future<void> dispose();
}
