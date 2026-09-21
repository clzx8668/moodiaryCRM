import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:share_plus/share_plus.dart';

/// 实验室逻辑：**只剩开发者维护工具**。
///
/// 批次 114 收敛：第三方 Key 的读写搬到各自的功能页
/// （和风/天地图 → 第三方服务页；腾讯云 → 模型管理页），
/// 加密测试与缩略图清理属于重复/开发项，已删除。
class LaboratoryLogic extends GetxController {
  Future<void> exportErrorLog() async {
    // 如果日志内容存在且内容不为空则导出
    if ((await File(FileUtil.getErrorLogPath()).readAsString()).isNotEmpty) {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(FileUtil.getErrorLogPath())]),
      );
      // 如果分享成功则清空本地日志
      if (result.status == ShareResultStatus.success) {
        await File(FileUtil.getErrorLogPath()).writeAsString('');
        toast.success(message: '日志导出成功，已删除本地日志');
      }
    } else {
      toast.info(message: '暂无日志');
    }
  }

  bool generateFTSAndKeyword() {
    try {
      IsarUtil.mergeToV2_7_4(FileUtil.getRealPath('database', ''));
      return true;
    } catch (e) {
      return false;
    }
  }
}
