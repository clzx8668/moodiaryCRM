//! FFI 契约（P1.3）——Rust 与 Flutter 的通信"合同"
//!
//! 规范（架构文档 5.2）：
//! - 版本化：破坏性变更时 `FFI_API_VERSION` +1，Dart 端按版本路由；
//! - 扁平化：跨 FFI 只传扁平 DTO / 事件，嵌套对象拆成 ID 关联；
//! - bincode 优先：大对象走 `encode_bincode`/`decode_bincode`（sync/serializer.rs）；
//! - EventStream：同步进度 / AI 流式输出经 StreamSink 推送（5.3），
//!   待重新生成 frb 绑定后接入（见下方 TODO）。
//!
//! 变更后重新生成绑定：
//! ```powershell
//! flutter_rust_bridge_codegen generate   # 读取 flutter_rust_bridge.yaml
//! ```

use crate::sync::events::*;
use crate::sync::mock::MockSyncEngine;
use crate::sync::models::SyncStateStatus;
use crate::sync::traits::SyncEngine;
use anyhow::Result;

/// FFI 契约版本（v1：同步引擎骨架）
pub const FFI_API_VERSION: u32 = 1;

/// 返回当前 FFI 契约版本，Dart 端据此路由
pub fn api_version() -> u32 {
    FFI_API_VERSION
}

/// 查询同步引擎当前状态（骨架：Mock 返回 Idle）
pub async fn get_sync_status() -> Result<SyncStateStatus> {
    MockSyncEngine.get_sync_status().await
}

/// 触发一次全量同步（骨架：Mock 空实现）
pub async fn trigger_full_sync() -> Result<()> {
    MockSyncEngine.full_sync().await
}

/// 查询指定时间戳之后的同步进度事件（轮询版占位）。
///
/// TODO(EventStream)：运行 `flutter_rust_bridge_codegen generate` 生成
/// `SseEncode` 绑定后，增加 `sync_progress_stream(sink: StreamSink<SyncProgressEvent>)`
/// 版本（架构文档 5.3 事件总线），并把 `SyncProgressEvent` 纳入 `rust_input: crate::api`
/// 的可见范围内；届时 Dart 侧用 `Stream` 订阅，无需轮询。
pub async fn sync_progress_events_since(_since_timestamp: i64) -> Result<Vec<SyncProgressEvent>> {
    Ok(Vec::new())
}
