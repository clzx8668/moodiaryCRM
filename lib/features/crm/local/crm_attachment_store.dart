import 'dart:io';

import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 附件沙盒：把源文件复制到应用文档目录 `Attachments/CRM/<类型>/<id>/`，
/// 数据库只记录路径（对齐设计文档附件沙盒原则）。
class CrmAttachmentStore {
  static Future<LocalAttachment> storeAndAttach({
    required String sourcePath,
    required String relatedType,
    required String relatedId,
    String? fileName,
    CrmLocalRepository? repo,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final safeType = relatedType.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeId = relatedId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dir = Directory(
      p.join(docs.path, 'Attachments', 'CRM', safeType, safeId),
    );
    await dir.create(recursive: true);
    final name = fileName ?? p.basename(sourcePath);
    final target = p.join(dir.path, name);
    await File(sourcePath).copy(target);
    final size = await File(target).length();
    return (repo ?? CrmLocalRepository()).addAttachment(
      LocalAttachment(
        id: '',
        relatedType: relatedType,
        relatedId: relatedId,
        fileName: name,
        filePath: target,
        fileSize: size,
      ),
    );
  }

  /// 删除附件记录与文件（文件删除失败不阻断）。
  static Future<void> delete(
    LocalAttachment attachment, {
    CrmLocalRepository? repo,
  }) async {
    await (repo ?? CrmLocalRepository()).deleteAttachment(attachment.id);
    try {
      final file = File(attachment.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
