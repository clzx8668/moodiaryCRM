import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:path/path.dart' as p;

/// 记忆/画像的**文件清单**（批次 119）。
///
/// 设计取向：把原来存在 PrefUtil 里的 JSON 画像，升级成**用户可直接读写的
/// Markdown 文件**。好处：
/// - 人可以看得懂、改得动（用 App 自带编辑器即可，不必做成表单）；
/// - 可以整体导出/备份/迁移；
/// - 与"自写技能手册"共用同一套存储，形成 Hermes 式的分层记忆。
///
/// 目录布局（都在应用支持目录下，属于**应用自留地**，不碰用户笔记）：
/// ```
/// <support>/ai-memory/
///   ├─ profile.md      用户画像（Tier 1，常驻上下文）
///   ├─ memory.md       稳定事实与偏好（Tier 1，常驻上下文）
///   ├─ skills/         自写技能手册（按需加载，Tier 2/3 之间）
///   │    └─ <slug>.md
///   └─ snapshots/      写入前快照（回滚用）
///        └─ <name>.<时间戳>.md
/// ```
class MemoryFiles {
  MemoryFiles._();

  /// 根目录名
  static const String rootName = 'ai-memory';

  /// 用户画像文件名
  static const String profileName = 'profile.md';

  /// 稳定事实/偏好文件名
  static const String memoryName = 'memory.md';

  /// 自写技能目录名
  static const String skillsDirName = 'skills';

  /// 快照目录名
  static const String snapshotsDirName = 'snapshots';

  /// 单个文件注入上下文的上限（字符）。超过就截断，避免把上下文挤爆。
  static const int maxInjectedCharsPerFile = 6000;

  /// 所有常驻文件合计上限（字符）
  static const int maxInjectedCharsTotal = 12000;

  /// 目录覆盖（仅供测试注入：单测里没有真实的 supportPath）
  @visibleForTesting
  static String? rootDirOverride;

  static String rootDir() =>
      rootDirOverride ?? FileUtil.getRealPath(rootName, '');

  static String profilePath() => p.join(rootDir(), profileName);

  static String memoryPath() => p.join(rootDir(), memoryName);

  static String skillsDir() => p.join(rootDir(), skillsDirName);

  static String snapshotsDir() => p.join(rootDir(), snapshotsDirName);

  /// 确保目录存在（首次使用时调用）
  static Future<void> ensureDirs() async {
    await Directory(rootDir()).create(recursive: true);
    await Directory(skillsDir()).create(recursive: true);
    await Directory(snapshotsDir()).create(recursive: true);
  }

  /// 列出全部技能手册文件（按文件名排序，稳定输出）
  static List<File> listSkillFiles() {
    final dir = Directory(skillsDir());
    if (!dir.existsSync()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.md'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// 把任意标题转成安全的文件名（slug）：去标点、空白换短横线
  static String slugify(String title) {
    final cleaned = title
        .trim()
        // 保留：中英文、数字、连字符；其余（含标点与空白）一律转成短横线
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final safe = cleaned.isEmpty ? 'skill' : cleaned;
    // 中文保留可读性，只限制长度（过长的文件名在某些系统上会出问题）
    return safe.length <= 40 ? safe : safe.substring(0, 40);
  }
}
