import 'dart:async';

import 'package:moodiary/src/rust/api/ffi_api.dart' as ffi;
import 'package:moodiary/src/rust/api/sync_events.dart';

/// 同步/AI/文件事件流服务（遗留项 3：同步引擎 FFI 事件流）。
///
/// 订阅 Rust 侧 `sync_progress_stream` / `ai_stream_stream` / `file_sync_stream`
/// 生成的 Dart Stream，再以广播形式分发给各页面（SmartCanvasPage 的 SyncState 等）。
class SyncEventService {
  SyncEventService._();

  static final SyncEventService instance = SyncEventService._();

  StreamSubscription<SyncProgressEvent>? _syncSub;
  StreamSubscription<AiStreamEvent>? _aiSub;
  StreamSubscription<FileSyncEvent>? _fileSub;

  final StreamController<SyncProgressEvent> _syncController =
      StreamController.broadcast();
  final StreamController<AiStreamEvent> _aiController =
      StreamController.broadcast();
  final StreamController<FileSyncEvent> _fileController =
      StreamController.broadcast();

  /// 同步进度事件广播流
  Stream<SyncProgressEvent> get syncEvents => _syncController.stream;

  /// AI 流式事件广播流
  Stream<AiStreamEvent> get aiEvents => _aiController.stream;

  /// 文件同步事件广播流
  Stream<FileSyncEvent> get fileEvents => _fileController.stream;

  bool get isRunning => _syncSub != null;

  /// 启动订阅（幂等）。应用启动时调用一次即可。
  Future<void> start() async {
    if (_syncSub != null) return;
    _syncSub = ffi.syncProgressStream().listen(
      (e) => _syncController.add(e),
      onError: (_) {},
      cancelOnError: true,
    );
    _aiSub = ffi.aiStreamStream().listen(
      (e) => _aiController.add(e),
      onError: (_) {},
      cancelOnError: true,
    );
    _fileSub = ffi.fileSyncStream().listen(
      (e) => _fileController.add(e),
      onError: (_) {},
      cancelOnError: true,
    );
  }

  /// 停止订阅并释放
  void stop() {
    _syncSub?.cancel();
    _aiSub?.cancel();
    _fileSub?.cancel();
    _syncSub = null;
    _aiSub = null;
    _fileSub = null;
  }
}
