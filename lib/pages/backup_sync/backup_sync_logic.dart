import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/backup/backup_service.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:share_plus/share_plus.dart';

class BackupSyncLogic extends GetxController {
  Future<void> exportFile() async {
    toast.info(message: '正在处理中');
    final dataPath = FileUtil.getRealPath('', '');
    final zipPath = FileUtil.getCachePath('');
    final isolateParams = {'zipPath': zipPath, 'dataPath': dataPath};
    final path = await FileUtil.zipFileUseRust(isolateParams);
    final res = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)]),
    );
    if (res.status == ShareResultStatus.success) {
      await File(path).delete();
    }
  }

  //导入
  Future<void> import() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['zip'],
      type: FileType.custom,
    );
    if (result != null) {
      toast.info(message: '数据导入中，请不要离开页面');
      await FileUtil.extractFile(result.files.single.path!);
      toast.success(message: '导入成功，请重启应用');
    } else {
      toast.info(message: '取消文件选择');
    }
  }

  /// P4.4 导出结构化备份（Markdown + JSON），桌面选目录，移动端分享
  Future<void> exportStructured() async {
    String? directory;
    try {
      directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择备份保存目录',
      );
    } catch (_) {
      // 移动端不支持目录选择，走系统分享
    }
    toast.info(message: '正在导出…');
    try {
      final file = await BackupService.export(targetDirectory: directory);
      if (directory == null) {
        final res = await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)]),
        );
        if (res.status == ShareResultStatus.success) {
          await file.delete();
        }
      } else {
        toast.success(message: '备份已导出：${file.path}');
      }
    } catch (e) {
      toast.error(message: '导出失败：$e');
    }
  }

  /// P4.4 导入结构化备份（按 id 幂等合并）
  Future<void> importStructured() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['zip'],
      type: FileType.custom,
    );
    if (result == null) {
      toast.info(message: '取消文件选择');
      return;
    }
    toast.info(message: '数据导入中，请不要离开页面');
    try {
      final res = await BackupService.importFromFile(
        result.files.single.path!,
      );
      toast.success(message: '导入完成：${res.summary}');
    } catch (e) {
      toast.error(message: '导入失败：$e');
    }
  }
}
