import 'package:get/get.dart';

/// StreamingState：AI 流式输出（架构文档 6.2）。
///
/// 独立于 BlockListState，流式期间只刷新流式卡片区域。
class StreamingState {
  /// 正在流式的 Block id（空 = 无流式）
  final RxString streamingBlockId = ''.obs;

  /// 是否正在流式
  final RxBool streaming = false.obs;

  /// 当前累积文本（节流渲染用）
  final RxString buffer = ''.obs;

  /// 距上次持久化的字符数（每 ~50 token 落盘一次 streamBuffer）
  int sincePersist = 0;

  /// 是否正在处理指定卡片
  bool isStreaming(String blockId) => streaming.value && streamingBlockId.value == blockId;

  void start(String blockId) {
    streamingBlockId.value = blockId;
    buffer.value = '';
    sincePersist = 0;
    streaming.value = true;
  }

  void append(String chunk) {
    buffer.value = buffer.value + chunk;
    sincePersist += chunk.length;
  }

  void resetPersistCounter() {
    sincePersist = 0;
  }

  void stop() {
    streaming.value = false;
    streamingBlockId.value = '';
    sincePersist = 0;
  }
}
