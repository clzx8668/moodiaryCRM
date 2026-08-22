import 'package:get/get.dart';

/// SyncState：同步状态（架构文档 6.2；P2.7.7 订阅 Rust 事件流后填充）。
class SyncState {
  /// 是否有同步在进行
  final RxBool syncing = false.obs;

  /// 最近一次事件阶段：idle/started/pulling/pushing/uploading/done/error
  final RxString phase = 'idle'.obs;

  /// 最近错误信息
  final RxString error = ''.obs;

  /// 进度 0~1
  final RxDouble progress = 0.0.obs;

  void onEvent({required String phase, double progress = 0, String error = ''}) {
    this.phase.value = phase;
    this.progress.value = progress;
    this.error.value = error;
    syncing.value = phase == 'started' ||
        phase == 'pulling' ||
        phase == 'pushing' ||
        phase == 'uploading';
  }

  void reset() {
    phase.value = 'idle';
    progress.value = 0;
    error.value = '';
    syncing.value = false;
  }
}
