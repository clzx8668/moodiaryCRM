import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:moodiary/features/asr/asr_model_store.dart';
import 'package:path/path.dart' as p;

/// 单个文件的下载进度。
class AsrDownloadProgress {
  const AsrDownloadProgress({
    required this.fileName,
    required this.fileIndex,
    required this.fileCount,
    required this.received,
    required this.total,
  });

  final String fileName;
  final int fileIndex;
  final int fileCount;
  final int received;
  final int total;

  /// 0..1；总长未知时返回 null
  double? get fraction =>
      total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  /// `正在下载 model.int8.onnx（2/3）`
  String get label => '正在下载 $fileName（$fileIndex/$fileCount）';

  String get detail {
    final f = fraction;
    final mb = (received / 1024 / 1024).toStringAsFixed(1);
    if (f == null) return '$mb MB';
    return '$mb / ${(total / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 端侧模型的**应用内下载**（Android 首选；Windows 也可用）。
///
/// 为什么需要它：模型 78MB 不进安装包，早期只能靠开发脚本 `adb push` 到
/// 应用私有目录 —— 普通用户（以及换手机后的老用户）根本装不上，
/// 结果就是"实时转写没执行、还是走云端然后失败"。这里把安装做成应用内可完成的事。
///
/// 下载源顺序：先国内 CDN（ModelScope / ghfast 镜像），失败再试官方 GitHub。
class AsrModelDownloader {
  AsrModelDownloader({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              followRedirects: true,
              receiveTimeout: const Duration(minutes: 10),
              connectTimeout: const Duration(seconds: 20),
              headers: const {'User-Agent': 'moodiary-asr/1.0'},
            ),
          );

  final Dio _dio;

  // ModelScope 的 large 仓库虽然可达，但**没有** small 模型的 int8 权重
  // （只有 model_quant.onnx，即那个 227MB 版本），因此这里不使用它。
  static const String _ghMirror = 'https://ghfast.top/';
  static const String _ghRelease =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';
  static const String _hfMirror =
      'https://hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main';

  /// 每个文件的候选下载地址（按顺序尝试，前一个失败自动换下一个）。
  ///
  /// 实测（本机 + 国内网络）：hf-mirror 与 ghfast 镜像都可用；
  /// ModelScope 的 large 仓库**没有** `model.int8.onnx`（只有 model_quant.onnx，
  /// 那个 227MB 版本在部分设备上会让进程静默退出），所以不用它。
  static final Map<String, List<String>> sources = {
    AsrModelFiles.vad: [
      '${_ghMirror}$_ghRelease/silero_vad.onnx',
      'https://hf-mirror.com/csukuangfj/vad/resolve/main/silero_vad.onnx',
    ],
    AsrModelFiles.asr: [
      '$_hfMirror/model.int8.onnx',
      '${_ghMirror}https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main/model.int8.onnx',
    ],
    // tokens.txt 只跟 hf-mirror 同源（ModelScope 那个仓库给的是 tokens.json 且
    // 与 small 模型词表不一致，不能混用）
    AsrModelFiles.tokens: ['$_hfMirror/tokens.txt'],
  };

  /// 大致的总体积（用于 UI 预估）
  static const int approxTotalBytes = 84 * 1024 * 1024;

  CancelToken? _cancelToken;

  bool get isCancelled => _cancelToken?.isCancelled ?? false;

  /// 取消正在进行的下载
  void cancel() => _cancelToken?.cancel('用户取消');

  /// 下载缺失的模型文件到 [AsrModelStore.baseDir]。
  ///
  /// - 已存在的文件会跳过（可断点续传的语义：重跑只补缺的）；
  /// - 下载先写 `.part` 临时文件，成功后再改名，避免半截文件被当成"已就绪"；
  /// - 返回 null 表示全部就绪，否则返回给用户看的错误文案。
  Future<String?> downloadMissing({
    void Function(AsrDownloadProgress)? onProgress,
  }) async {
    final missing = AsrModelStore.missingCoreFiles();
    if (missing.isEmpty) return null;

    final dir = Directory(AsrModelStore.baseDir());
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _cancelToken = CancelToken();

    for (var i = 0; i < missing.length; i++) {
      final name = missing[i];
      final targets = sources[name];
      if (targets == null || targets.isEmpty) {
        return '缺少下载源：$name';
      }
      final dest = AsrModelStore.pathOf(name);
      final part = '$dest.part';
      Object? lastError;
      var ok = false;
      for (final url in targets) {
        try {
          await _dio.download(
            url,
            part,
            cancelToken: _cancelToken,
            deleteOnError: true,
            options: Options(
              // 大文件：不设总超时，只设单次接收超时
              receiveTimeout: const Duration(minutes: 5),
            ),
            onReceiveProgress: (received, total) {
              onProgress?.call(
                AsrDownloadProgress(
                  fileName: name,
                  fileIndex: i + 1,
                  fileCount: missing.length,
                  received: received,
                  total: total > 0 ? total : 0,
                ),
              );
            },
          );
          if (File(part).existsSync() && File(part).lengthSync() > 0) {
            // 原子改名：避免半截文件被 next 次启动当成"已就绪"
            await File(part).rename(dest);
            ok = true;
            break;
          }
        } on DioException catch (e) {
          lastError = e;
          if (CancelToken.isCancel(e)) return '已取消下载';
          // 换下一个源
        } catch (e) {
          lastError = e;
        }
      }
      if (!ok) {
        _cleanup(part);
        return '下载 $name 失败：${_shortError(lastError)}';
      }
    }
    return null;
  }

  void _cleanup(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // 清理失败不影响主流程
    }
  }

  static String _shortError(Object? e) {
    if (e == null) return '未知错误';
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code != null) return 'HTTP $code';
      return e.message ?? e.type.name;
    }
    final s = '$e';
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }

  /// 下载到一半的临时文件（用于"清理不完整下载"）
  static List<String> partFiles() {
    final dir = AsrModelStore.baseDir();
    final d = Directory(dir);
    if (!d.existsSync()) return const [];
    return d
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((path) => p.extension(path) == '.part')
        .toList();
  }
}
