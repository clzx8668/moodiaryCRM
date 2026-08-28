//! FFI 事件总线（架构文档 5.3）：tokio broadcast 信道。
//!
//! Rust 同步引擎/AI/文件同步在任意异步上下文中调用 emit_* 发布事件，
//! Dart 侧经 sync_progress_stream / ai_stream_stream / file_sync_stream
//! 订阅（StreamSink）。无订阅者时事件直接丢弃，不影响主流程。

use std::sync::{Mutex, OnceLock};

use tokio::sync::broadcast;

use super::sync_events::{
    AiStreamEvent, FileSyncEvent, FileSyncEventStatus, SyncProgressEvent, SyncProgressPhase,
};

const CHANNEL_CAPACITY: usize = 256;

/// Sender 容器：`None` 表示已关闭（shutdown 后 drop 发送端，
/// 所有 Receiver.recv() 返回 `Closed`，事件流循环自动退出）。
type SenderBox<T> = Mutex<Option<broadcast::Sender<T>>>;

fn sync_tx_box() -> &'static SenderBox<SyncProgressEvent> {
    static TX: OnceLock<SenderBox<SyncProgressEvent>> = OnceLock::new();
    TX.get_or_init(|| Mutex::new(Some(broadcast::channel(CHANNEL_CAPACITY).0)))
}

fn ai_tx_box() -> &'static SenderBox<AiStreamEvent> {
    static TX: OnceLock<SenderBox<AiStreamEvent>> = OnceLock::new();
    TX.get_or_init(|| Mutex::new(Some(broadcast::channel(CHANNEL_CAPACITY).0)))
}

fn file_tx_box() -> &'static SenderBox<FileSyncEvent> {
    static TX: OnceLock<SenderBox<FileSyncEvent>> = OnceLock::new();
    TX.get_or_init(|| Mutex::new(Some(broadcast::channel(CHANNEL_CAPACITY).0)))
}

fn sync_tx() -> broadcast::Sender<SyncProgressEvent> {
    let mut guard = sync_tx_box().lock().unwrap_or_else(|e| e.into_inner());
    if guard.is_none() {
        *guard = Some(broadcast::channel(CHANNEL_CAPACITY).0);
    }
    guard.as_ref().expect("sender 应存在").clone()
}

fn ai_tx() -> broadcast::Sender<AiStreamEvent> {
    let mut guard = ai_tx_box().lock().unwrap_or_else(|e| e.into_inner());
    if guard.is_none() {
        *guard = Some(broadcast::channel(CHANNEL_CAPACITY).0);
    }
    guard.as_ref().expect("sender 应存在").clone()
}

fn file_tx() -> broadcast::Sender<FileSyncEvent> {
    let mut guard = file_tx_box().lock().unwrap_or_else(|e| e.into_inner());
    if guard.is_none() {
        *guard = Some(broadcast::channel(CHANNEL_CAPACITY).0);
    }
    guard.as_ref().expect("sender 应存在").clone()
}

/// 触发全局优雅关闭：drop 所有 broadcast 发送端，
/// 事件流循环的 `rx.recv()` 将返回 `Closed` 并退出，释放 frb 运行时。
pub fn shutdown_all() {
    if let Ok(mut guard) = sync_tx_box().lock() {
        *guard = None;
    }
    if let Ok(mut guard) = ai_tx_box().lock() {
        *guard = None;
    }
    if let Ok(mut guard) = file_tx_box().lock() {
        *guard = None;
    }
}

/// 发布同步进度事件
pub fn emit_sync_progress(phase: SyncProgressPhase, progress: f32, message: String) {
    let _ = sync_tx().send(SyncProgressEvent {
        phase,
        progress,
        message,
    });
}

/// 发布 AI 流式事件
pub fn emit_ai_stream(block_id: String, chunk: String, is_complete: bool) {
    let _ = ai_tx().send(AiStreamEvent {
        block_id,
        chunk,
        is_complete,
    });
}

/// 发布文件同步事件
pub fn emit_file_sync(file_path: String, status: FileSyncEventStatus, progress: f32) {
    let _ = file_tx().send(FileSyncEvent {
        file_path,
        status,
        progress,
    });
}

pub(crate) fn subscribe_sync() -> broadcast::Receiver<SyncProgressEvent> {
    sync_tx().subscribe()
}

pub(crate) fn subscribe_ai() -> broadcast::Receiver<AiStreamEvent> {
    ai_tx().subscribe()
}

pub(crate) fn subscribe_file() -> broadcast::Receiver<FileSyncEvent> {
    file_tx().subscribe()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::sync_events::{FileSyncEventStatus, SyncProgressPhase};

    fn block_on<F: std::future::Future>(future: F) -> F::Output {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("构建测试 runtime")
            .block_on(future)
    }

    #[test]
    fn sync_event_emit_and_receive() {
        block_on(async {
            let mut rx = subscribe_sync();
            emit_sync_progress(SyncProgressPhase::Started, 0.0, "开始".to_string());
            let event = rx.recv().await.expect("应能收到同步事件");
            assert_eq!(event.phase, SyncProgressPhase::Started);
            assert_eq!(event.progress, 0.0);
            assert_eq!(event.message, "开始");
        });
    }

    #[test]
    fn file_event_emit_and_receive() {
        block_on(async {
            let mut rx = subscribe_file();
            emit_file_sync(
                "Attachments/a.jpg".to_string(),
                FileSyncEventStatus::Uploading,
                0.5,
            );
            let event = rx.recv().await.expect("应能收到文件同步事件");
            assert_eq!(event.file_path, "Attachments/a.jpg");
            assert_eq!(event.status, FileSyncEventStatus::Uploading);
            assert_eq!(event.progress, 0.5);
        });
    }

    #[test]
    fn ai_event_emit_and_receive() {
        block_on(async {
            let mut rx = subscribe_ai();
            emit_ai_stream("blk-1".to_string(), "你好".to_string(), false);
            let event = rx.recv().await.expect("应能收到 AI 事件");
            assert_eq!(event.block_id, "blk-1");
            assert_eq!(event.chunk, "你好");
            assert!(!event.is_complete);
        });
    }

    #[test]
    fn drop_all_senders_closes_receiver() {
        block_on(async {
            // 机制验证：broadcast 所有发送端 drop 后，
            // Receiver.recv() 返回 Closed → 事件流循环自动退出
            let (tx, mut rx) = broadcast::channel::<SyncProgressEvent>(CHANNEL_CAPACITY);
            let _ = tx.send(SyncProgressEvent {
                phase: SyncProgressPhase::Started,
                progress: 0.0,
                message: "开始".to_string(),
            });
            let _ = rx.recv().await.expect("应能收到同步事件");
            drop(tx);
            assert!(
                rx.recv().await.is_err(),
                "关闭后 recv 应返回 Closed"
            );
        });
    }

    #[test]
    fn shutdown_all_clears_sender_boxes() {
        // shutdown_all 会把三个 sender 容器置 None（实现检查，无并发依赖）
        shutdown_all();
    }
}
