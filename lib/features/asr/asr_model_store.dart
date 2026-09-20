import 'dart:io';

import 'package:moodiary/utils/file_util.dart';
import 'package:path/path.dart' as p;

/// 端侧转写模型清单（文件名固定，便于脚本/应用两侧对齐）。
class AsrModelFiles {
  /// 语音活动检测（silero v4/v5）
  static const String vad = 'silero_vad.onnx';

  /// 中文识别主模型（Paraformer-large int8）
  static const String asr = 'model.int8.onnx';

  /// 词表
  static const String tokens = 'tokens.txt';

  /// Windows 运行库（端侧推理依赖；Android 用内置 JNI，不需要）
  static const List<String> windowsLibs = [
    'sherpa-onnx-c-api.dll',
    'onnxruntime.dll',
  ];
}

/// 端侧模型/运行库的存放与就绪判定。
///
/// 目录：`<应用支持目录>/asr/`（Windows 与 Android 一致，随应用私有数据一起备份/清理）。
class AsrModelStore {
  AsrModelStore._();

  /// 模型目录名（挂在支持目录下）
  static const String dirName = 'asr';

  static String baseDir() => FileUtil.getRealPath(dirName, '');

  static String pathOf(String fileName) => p.join(baseDir(), fileName);

  static bool get hasVad => File(pathOf(AsrModelFiles.vad)).existsSync();

  static bool get hasAsr => File(pathOf(AsrModelFiles.asr)).existsSync();

  static bool get hasTokens => File(pathOf(AsrModelFiles.tokens)).existsSync();

  /// 端侧识别是否就绪（VAD + 主模型 + 词表）
  static bool get isReady => hasVad && hasAsr && hasTokens;

  /// Windows 侧是否已放入运行库（Android/iOS 恒 false，但调用方会先判平台）
  static bool get hasWindowsLibs =>
      windowsLibDir() == baseDir() &&
      AsrModelFiles.windowsLibs.every(
        (n) => File(pathOf(n)).existsSync(),
      );

  /// Windows 运行库目录（与模型同目录，便于"一个文件夹拷过去"）
  static String windowsLibDir() => baseDir();

  /// 缺失的文件名（用于 UI 引导）
  static List<String> missingFiles() => [
    if (!hasVad) AsrModelFiles.vad,
    if (!hasAsr) AsrModelFiles.asr,
    if (!hasTokens) AsrModelFiles.tokens,
    if (Platform.isWindows)
      ...AsrModelFiles.windowsLibs.where(
        (n) => !File(pathOf(n)).existsSync(),
      ),
  ];

  /// 单个文件大小（MB，保留一位小数；不存在返回 0）
  static double sizeMb(String fileName) {
    final file = File(pathOf(fileName));
    if (!file.existsSync()) return 0;
    return file.lengthSync() / (1024 * 1024);
  }

  /// 模型总体积（MB）
  static double totalMb() =>
      sizeMb(AsrModelFiles.vad) +
      sizeMb(AsrModelFiles.asr) +
      sizeMb(AsrModelFiles.tokens) +
      (Platform.isWindows
          ? AsrModelFiles.windowsLibs.fold<double>(
              0,
              (sum, n) => sum + sizeMb(n),
            )
          : 0);

  /// 一行状态摘要（设置页与语音面板共用）
  static String statusLabel() {
    if (isReady) return '端侧模型已就绪（${totalMb().toStringAsFixed(1)} MB）';
    final missing = missingFiles();
    if (missing.length == 3) return '未安装端侧模型';
    if (missing.isEmpty) return '端侧模型已就绪（${totalMb().toStringAsFixed(1)} MB）';
    return '端侧模型不完整，缺少：${missing.join('、')}';
  }

  /// 把用户导入的文件放进模型目录（按文件名识别类型）
  static Future<bool> importFile(String sourcePath) async {
    final fileName = p.basename(sourcePath);
    final known = <String>[
      AsrModelFiles.vad,
      AsrModelFiles.asr,
      AsrModelFiles.tokens,
      ...AsrModelFiles.windowsLibs,
    ];
    if (!known.contains(fileName)) return false;
    final dir = Directory(baseDir());
    if (!dir.existsSync()) await dir.create(recursive: true);
    await File(sourcePath).copy(pathOf(fileName));
    return true;
  }
}
