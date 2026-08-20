import 'dart:async';

/// flutter test 全局配置。
///
/// Drift/SQLite 在 Windows 桌面测试中通过 sqlite3_flutter_libs 提供原生库，
/// 无需额外初始化；若出现 sqlite3.dll 缺失，在此补充动态库定位逻辑。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
