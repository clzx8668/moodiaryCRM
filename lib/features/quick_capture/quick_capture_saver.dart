import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 快速收集保存器：写入 Diary + Block（Block 协议），并持久化图片附件。
class QuickCaptureSaver {
  static Future<Diary> save({
    required String text,
    required List<QuickAttachment> attachments,
  }) async {
    final now = DateTime.now();
    final content = _buildContent(text, attachments);

    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = _deriveTitle(text)
      ..content = content
      ..contentText = text
      ..type = DiaryType.text.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;

    // 图片附件走现有媒体管线（压缩保存到 image 目录）
    final images = attachments.where((a) => a.isImage).toList();
    if (images.isNotEmpty) {
      final imageNameMap = await MediaUtil.saveImages(
        imageFileList: images.map((a) => XFile(a.path)).toList(),
      );
      diary.imageName = imageNameMap.values.toList();
    }

    // 文档附件：复制到 document 目录（Obsidian 模式，P1.9 将接入统一附件管理）
    final documents = attachments.where((a) => !a.isImage).toList();
    if (documents.isNotEmpty) {
      final docDir = Directory(FileUtil.getRealPath('document', ''));
      if (!docDir.existsSync()) {
        await docDir.create(recursive: true);
      }
      for (final doc in documents) {
        final name = 'doc-${const Uuid().v7()}-${doc.name}';
        await File(doc.path).copy(FileUtil.getRealPath('document', name));
      }
    }

    await IsarUtil.insertADiary(diary);

    // Block 协议：每条速记生成一个 text Block（数据层 P1.1 提供）
    await IsarUtil.insertBlock(
      Block()
        ..diaryId = diary.id
        ..blockType = BlockType.text
        ..content = content
        ..sortOrder = 0
        ..createdAt = now
        ..updatedAt = now,
    );

    return diary;
  }

  static String _deriveTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '速记';
    if (trimmed.length <= 20) return trimmed;
    return '${trimmed.substring(0, 20)}…';
  }

  static String _buildContent(String text, List<QuickAttachment> attachments) {
    final buffer = StringBuffer(text.trim());
    for (final attachment in attachments) {
      if (buffer.isNotEmpty) buffer.writeln();
      if (attachment.isImage) {
        buffer.write('![](${p.basename(attachment.path)})');
      } else {
        buffer.write('- 📎 ${attachment.name}');
      }
    }
    return buffer.toString();
  }
}
