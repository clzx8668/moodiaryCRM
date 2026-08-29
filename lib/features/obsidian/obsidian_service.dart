import 'dart:io';

import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:path/path.dart' as p;

/// Obsidian Vault 文件（只读模型）
class ObsidianFile {
  /// 相对 Vault 路径，如 `日记/2026-08-30.md`
  final String relativePath;
  final String name;
  final String content;

  const ObsidianFile({
    required this.relativePath,
    required this.name,
    required this.content,
  });

  /// 双链匹配名（不含扩展名）
  String get linkName => name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
}

/// Obsidian 对接服务（只读）：递归扫描 Vault 的 .md 文件 + 内存缓存 +
/// 关键词搜索 + 双链解析。本期不做双向同步。
class ObsidianService {
  ObsidianService._();

  static final ObsidianService instance = ObsidianService._();

  List<ObsidianFile> _files = [];
  String _vaultPath = '';
  DateTime _lastScan = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isLoaded => _files.isNotEmpty;

  String get vaultPath => _vaultPath;

  List<ObsidianFile> get files => List.unmodifiable(_files);

  /// 扫描 Vault（幂等：5 秒内重复调用返回缓存；手动刷新可传 force）。
  Future<int> scan({String? vaultPath, bool force = false}) async {
    final path = (vaultPath ?? ObsidianConfig.vaultPath.value).trim();
    if (path.isEmpty) {
      _files = [];
      _vaultPath = '';
      return 0;
    }
    if (!force &&
        _vaultPath == path &&
        DateTime.now().difference(_lastScan).inSeconds < 5) {
      return _files.length;
    }
    final root = Directory(path);
    if (!await root.exists()) return 0;
    final collected = <ObsidianFile>[];
    await _walk(root, collected);
    collected.sort(
      (a, b) => a.relativePath.compareTo(b.relativePath),
    );
    _files = collected;
    _vaultPath = path;
    _lastScan = DateTime.now();
    return _files.length;
  }

  Future<void> _walk(Directory dir, List<ObsidianFile> out) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          await _walk(entity, out);
        } else if (entity is File &&
            entity.path.toLowerCase().endsWith('.md')) {
          final rel = p.relative(entity.path, from: _vaultPath);
          try {
            out.add(
              ObsidianFile(
                relativePath: rel,
                name: p.basename(entity.path),
                content: await entity.readAsString(),
              ),
            );
          } catch (_) {
            // 单文件读取失败跳过
          }
        }
      }
    } catch (_) {
      // 目录不可读跳过
    }
  }

  /// 按关键词搜索文件名/内容
  List<ObsidianFile> search(String keyword) {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    return _files
        .where(
          (f) => f.name.contains(k) || f.content.contains(k),
        )
        .toList();
  }

  /// 按双链名查找（`[[xxx]]` → 匹配 `xxx` / `xxx.md`）
  ObsidianFile? findByLink(String link) {
    final target = link.trim().replaceAll('.md', '');
    for (final f in _files) {
      if (f.linkName == target) return f;
    }
    return null;
  }

  /// 提取文本中的全部双链名
  List<String> extractLinks(String content) {
    final matches = RegExp(r'\[\[([^\[\]]+)\]\]').allMatches(content);
    return matches
        .map((m) => m.group(1)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }
}
