import 'dart:async';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

/// flutter test 全局配置：自动初始化 Isar 原生库（Windows）。
///
/// isar.dll 位于 pub 缓存 git 依赖的 isar_flutter_libs 包内，
/// 此处动态扫描 pub 缓存，避免硬编码具体 commit 路径。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null) {
    final gitCacheDir = Directory(
      p.join(localAppData, 'Pub', 'Cache', 'git'),
    );
    if (gitCacheDir.existsSync()) {
      final isarDll = gitCacheDir
          .listSync(followLinks: true)
          .whereType<Directory>()
          .map(
            (dir) => File(
              p.join(
                dir.path,
                'packages',
                'isar_flutter_libs',
                'windows',
                'isar.dll',
              ),
            ),
          )
          .where((file) => file.existsSync())
          .firstOrNull;
      if (isarDll != null) {
        await Isar.initialize(isarDll.path);
      }
    }
  }
  await testMain();
}
