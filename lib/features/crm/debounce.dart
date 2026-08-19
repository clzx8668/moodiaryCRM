import 'dart:async';

/// 防抖器（架构文档 4.9：用户停止操作 2 秒后合并为一次批量推送）
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(seconds: 2)});

  /// 提交一次操作；若在 [delay] 内再次提交，则重置计时器。
  void schedule(Future<void> Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(action());
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isPending => _timer?.isActive ?? false;
}
