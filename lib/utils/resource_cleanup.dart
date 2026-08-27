import 'package:moodiary/utils/log_util.dart';

/// 统一资源清理管理器（应用退出前按注册逆序执行）。
///
/// 用于释放会阻塞 Flutter 引擎收尾的后台资源：
/// 关闭数据库（NativeDatabase 线程）、Rust 运行时、取消流订阅/定时器等。
class ResourceCleanupManager {
  ResourceCleanupManager._();

  static final ResourceCleanupManager instance = ResourceCleanupManager._();

  final List<({String name, Future<void> Function() clean})> _cleanups = [];

  /// 注册清理任务（LIFO 执行）
  void register(String name, Future<void> Function() clean) {
    _cleanups.add((name: name, clean: clean));
  }

  /// 依次执行（逆序），单项失败不阻断后续，单项带超时。
  Future<void> cleanupAll({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    for (var i = _cleanups.length - 1; i >= 0; i--) {
      final c = _cleanups[i];
      try {
        logger.i('🧹 清理：${c.name}');
        await c.clean().timeout(timeout);
        logger.i('✅ 清理完成：${c.name}');
      } catch (e) {
        logger.e('❌ 清理失败：${c.name}', error: e);
      }
    }
  }
}
