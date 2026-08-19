import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 附件元数据条目
class AttachmentMeta {
  final String relativePath;
  final String? diaryId;
  final String? blockId;
  final DateTime createdAt;

  const AttachmentMeta({
    required this.relativePath,
    this.diaryId,
    this.blockId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'relativePath': relativePath,
      if (diaryId != null) 'diaryId': diaryId,
      if (blockId != null) 'blockId': blockId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) {
    return AttachmentMeta(
      relativePath: json['relativePath'] as String,
      diaryId: json['diaryId'] as String?,
      blockId: json['blockId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 附件管理（架构文档"三、3.3 文件存储目录结构"，Obsidian 模式）：
///
/// ```
/// /Attachments/
/// ├── Images/YYYY/MM/{uuid}.jpg
/// ├── Documents/YYYY/MM/{uuid}.pdf
/// └── metadata.json   （相对路径 → diaryId/blockId 索引）
/// ```
/// 提供孤立文件扫描与清理（架构文档"五、设置模块-数据健康度检查"）。
class AttachmentManager {
  static const String metadataFileName = 'metadata.json';

  static String? _testBaseDir;

  /// 测试注入基目录
  @visibleForTesting
  static void setBaseDirForTest(String dir) {
    _testBaseDir = dir;
  }

  @visibleForTesting
  static void resetBaseDirForTest() {
    _testBaseDir = null;
  }

  static String baseDir() {
    if (_testBaseDir != null) return _testBaseDir!;
    return FileUtil.getRealPath('Attachments', '');
  }

  /// 保存附件到 Attachments/[category]/YYYY/MM/，返回相对路径（正斜杠）
  static Future<String> saveFile({
    required String sourcePath,
    required String category,
  }) async {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final dir = p.join(
      baseDir(),
      _capitalize(category),
      now.year.toString(),
      month,
    );
    await Directory(dir).create(recursive: true);
    final ext = p.extension(sourcePath).isEmpty ? '' : p.extension(sourcePath);
    final name = '${const Uuid().v7()}$ext';
    final target = p.join(dir, name);
    await File(sourcePath).copy(target);
    return _normalize(p.relative(target, from: baseDir()));
  }

  /// 为附件登记 diaryId/blockId 引用
  static Future<void> addReference(
    String relativePath, {
    String? diaryId,
    String? blockId,
  }) async {
    final metas = await loadMetadata();
    final idx = metas.indexWhere(
      (m) => m.relativePath == _normalize(relativePath),
    );
    if (idx >= 0) {
      metas[idx] = AttachmentMeta(
        relativePath: metas[idx].relativePath,
        diaryId: diaryId ?? metas[idx].diaryId,
        blockId: blockId ?? metas[idx].blockId,
        createdAt: metas[idx].createdAt,
      );
    } else {
      metas.add(
        AttachmentMeta(
          relativePath: _normalize(relativePath),
          diaryId: diaryId,
          blockId: blockId,
          createdAt: DateTime.now(),
        ),
      );
    }
    await saveMetadata(metas);
  }

  static Future<List<AttachmentMeta>> loadMetadata() async {
    final file = File(p.join(baseDir(), metadataFileName));
    if (!file.existsSync()) return [];
    try {
      final json = jsonDecode(await file.readAsString()) as List<dynamic>;
      return json
          .map(
            (e) => AttachmentMeta.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMetadata(List<AttachmentMeta> metas) async {
    final file = File(p.join(baseDir(), metadataFileName));
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      jsonEncode(metas.map((m) => m.toJson()).toList()),
    );
  }

  /// 扫描孤立文件：Attachments 目录中存在但未被 metadata.json 登记的文件
  static Future<List<String>> scanOrphans() async {
    final dir = Directory(baseDir());
    if (!dir.existsSync()) return [];
    final known = (await loadMetadata())
        .map((m) => _resolve(m.relativePath).toLowerCase())
        .toSet();
    final orphans = <String>[];
    await for (final entity in dir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && p.basename(entity.path) != metadataFileName) {
        if (!known.contains(entity.path.toLowerCase())) {
          orphans.add(entity.path);
        }
      }
    }
    return orphans;
  }

  /// 删除全部孤立文件，返回删除数量
  static Future<int> cleanOrphans() async {
    final orphans = await scanOrphans();
    for (final path in orphans) {
      try {
        await File(path).delete();
      } catch (_) {
        // 忽略单个删除失败
      }
    }
    return orphans.length;
  }

  static String _resolve(String relativePath) {
    return p.joinAll([baseDir(), ...p.split(relativePath)]);
  }

  static String _normalize(String path) => path.replaceAll('\\', '/');

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
