//! FFI 契约（P1.3）——Rust 与 Flutter 的通信"合同"
//!
//! 规范（架构文档 5.2）：
//! - 版本化：破坏性变更时 `FFI_API_VERSION` +1，Dart 端按版本路由；
//! - 扁平化：跨 FFI 只传扁平 DTO / 事件，嵌套对象拆成 ID 关联；
//! - bincode 优先：大对象走 bincode 序列化（sync/serializer.rs）；
//! - EventStream：同步进度 / AI 流式输出经 StreamSink 推送（5.3），
//!   待重新生成 frb 绑定后接入（见下方 TODO）。
//!
//! 变更后重新生成绑定：
//! ```powershell
//! flutter_rust_bridge_codegen generate   # 读取 flutter_rust_bridge.yaml
//! ```

use anyhow::Result;

use crate::api::event_bus;
use crate::api::sync_events::{FileSyncEvent, FileSyncEventStatus, SyncProgressEvent, SyncProgressPhase};
use crate::frb_generated::StreamSink;

/// FFI 契约版本（v1：同步引擎骨架）
pub const FFI_API_VERSION: u32 = 1;

/// 返回当前 FFI 契约版本，Dart 端据此路由
pub fn api_version() -> u32 {
    FFI_API_VERSION
}

/// 查询同步引擎当前状态（骨架占位：返回 Idle；真实实现接入 sync 引擎后替换）
pub async fn get_sync_status() -> Result<String> {
    Ok("Idle".to_string())
}

/// 触发一次全量同步（骨架：Mock 空实现）
pub async fn trigger_full_sync() -> Result<()> {
    Ok(())
}

/// 查询指定时间戳之后的同步进度事件（轮询版占位）。
///
/// TODO(EventStream)：运行 `flutter_rust_bridge_codegen generate` 生成
/// `SseEncode` 绑定后，增加 `sync_progress_stream(sink: StreamSink<SyncProgressEvent>)`
/// 版本（架构文档 5.3 事件总线），并把 `SyncProgressEvent` 纳入 `rust_input: crate::api`
/// 的可见范围内；届时 Dart 侧用 `Stream` 订阅，无需轮询。
pub async fn sync_progress_events_since(_since_timestamp: i64) -> Result<Vec<String>> {
    Ok(Vec::new())
}

/// 订阅同步进度事件流（架构文档 5.3 EventStream）。
///
/// Dart 端调用后返回 `Stream<SyncProgressEvent>`；Rust 同步引擎通过
/// `event_bus::emit_sync_progress` 发布事件。Dart 侧取消订阅时 sink 发送失败，
/// 循环自动退出。
pub async fn sync_progress_stream(sink: StreamSink<SyncProgressEvent>) -> Result<()> {
    let mut rx = event_bus::subscribe_sync();
    flutter_rust_bridge::spawn(async move {
        while let Ok(event) = rx.recv().await {
            if sink.add(event).is_err() {
                break;
            }
        }
    });
    Ok(())
}

/// 订阅 AI 流式事件流（AiStreamEvent）。
pub async fn ai_stream_stream(sink: StreamSink<crate::api::sync_events::AiStreamEvent>) -> Result<()> {
    let mut rx = event_bus::subscribe_ai();
    flutter_rust_bridge::spawn(async move {
        while let Ok(event) = rx.recv().await {
            if sink.add(event).is_err() {
                break;
            }
        }
    });
    Ok(())
}

/// 订阅文件同步事件流（FileSyncEvent）。
pub async fn file_sync_stream(sink: StreamSink<FileSyncEvent>) -> Result<()> {
    let mut rx = event_bus::subscribe_file();
    flutter_rust_bridge::spawn(async move {
        while let Ok(event) = rx.recv().await {
            if sink.add(event).is_err() {
                break;
            }
        }
    });
    Ok(())
}

/// 演示事件流（联调/冒烟用）：发布一轮 started→pulling→pushing→done。
///
/// 真实同步引擎接入后，由 PullEngine/PushEngine 在各阶段调用
/// `event_bus::emit_sync_progress`，此函数仅用于验证 FFI 链路。
pub async fn emit_demo_sync_events() -> Result<()> {
    event_bus::emit_sync_progress(SyncProgressPhase::Started, 0.0, "同步开始".to_string());
    event_bus::emit_sync_progress(SyncProgressPhase::Pulling, 0.3, "拉取变更".to_string());
    event_bus::emit_sync_progress(SyncProgressPhase::Pushing, 0.7, "推送本地变更".to_string());
    event_bus::emit_sync_progress(SyncProgressPhase::Done, 1.0, "同步完成".to_string());
    event_bus::emit_file_sync(
        "Attachments/Images/2026/08/demo.jpg".to_string(),
        FileSyncEventStatus::Uploading,
        0.5,
    );
    Ok(())
}
