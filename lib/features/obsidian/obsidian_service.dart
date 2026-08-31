import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:path/path.dart' as p;

/// Obsidian Vault 文件（只读模型）
class ObsidianFile {
  /// 相对 Vault 路径，如 `日记/2026-08-30.md`
  final String relativePath;
  final String name;
  final String content;

  /// 磁盘绝对路径（调试/日志用）
  final String absolutePath;

  const ObsidianFile({
    required this.relativePath,
    required this.name,
    required this.content,
    required this.absolutePath,
  });

  /// 双链匹配名（不含扩展名）
  String get linkName =>
      name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
}

/// Obsidian 对接服务（只读）：递归扫描 Vault 的 .md 文件 + 内存缓存 +
/// 关键词搜索 + 双链解析。本期不做双向同步。
class ObsidianService {
  ObsidianService._();

  static final ObsidianService instance = ObsidianService._();

  /// 文件集变化信号：自动监听（轮询）发现增删/内容变化后自增，供树/页跟随刷新。
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<ObsidianFile> _files = [];
  String _vaultPath = '';
  DateTime _lastScan = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watcher;

  bool get isLoaded => _files.isNotEmpty;

  String get vaultPath => _vaultPath;

  List<ObsidianFile> get files => List.unmodifiable(_files);

  /// 启动自动监听（30 秒轮询重扫，文件集变化时 bump [revision]）。
  void startWatcher() {
    _watcher ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_watchTick()),
    );
  }

  void stopWatcher() {
    _watcher?.cancel();
    _watcher = null;
  }

  Future<void> _watchTick() async {
    if (!ObsidianConfig.enabled.value ||
        ObsidianConfig.vaultPath.value.trim().isEmpty) {
      return;
    }
    final before = _signature();
    await scan(force: true);
    if (_signature() != before) {
      revision.value++;
    }
  }

  String _signature() =>
      _files.map((f) => '${f.relativePath}:${f.content.length}').join('|');

  /// 扫描 Vault（幂等：5 秒内重复调用返回缓存；手动刷新可传 force）。
  Future<int> scan({String? vaultPath, bool force = false}) async {
    final path = (vaultPath ?? ObsidianConfig.vaultPath.value).trim();
    if (kDebugMode) {
      debugPrintSynchronously(
        '[ObsidianService.scan] path=${path.isEmpty ? '(空)' : path} '
        'enabled=${ObsidianConfig.enabled.value} force=$force cached=${_files.length}',
      );
    }
    if (path.isEmpty) {
      _files = [];
      _vaultPath = '';
      return 0;
    }
    if (!force &&
        _vaultPath == path &&
        DateTime.now().difference(_lastScan).inSeconds < 5) {
      if (kDebugMode) {
        debugPrintSynchronously(
          '[ObsidianService.scan] ✅ 命中 5s 缓存，共 ${_files.length} 篇笔记',
        );
      }
      return _files.length;
    }
    // 先登记 vault 路径再遍历，_walk 里 p.relative 才能得到正确相对路径
    _vaultPath = path;
    final root = Directory(path);
    if (!await root.exists()) {
      if (kDebugMode) {
        debugPrintSynchronously('[ObsidianService.scan] ❌ Vault 目录不存在');
      }
      return 0;
    }
    final collected = <ObsidianFile>[];
    try {
      await _walk(root, collected).timeout(const Duration(seconds: 30));
    } catch (e) {
      if (kDebugMode) {
        debugPrintSynchronously('[ObsidianService.scan] ⚠️ _walk 超时/异常: $e');
      }
    }
    collected.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    _files = collected;
    _lastScan = DateTime.now();
    if (_files.isNotEmpty) {
      startWatcher();
    }
    if (kDebugMode) {
      debugPrintSynchronously(
        '[ObsidianService.scan] ✅ 扫描完成：共 ${_files.length} 篇笔记',
      );
    }
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
                content: await entity.readAsString().timeout(
                  const Duration(seconds: 5),
                ),
                absolutePath: entity.path,
              ),
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrintSynchronously(
                '[ObsidianService._walk] 跳过文件 $rel: 读取失败 $e',
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrintSynchronously('[ObsidianService._walk] 目录跳过 ${dir.path}: $e');
      }
    }
  }

  /// 按关键词搜索文件名/内容
  List<ObsidianFile> search(String keyword) {
    final k = keyword.trim();
    if (k.isEmpty) return const [];
    return _files
        .where((f) => f.name.contains(k) || f.content.contains(k))
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
