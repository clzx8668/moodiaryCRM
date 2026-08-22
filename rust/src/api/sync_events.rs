//! FFI 事件总线数据结构（架构文档 5.3）——FFI 层的唯一权威定义。
//!
//! 放在 crate::api 而非 feature 门控的 sync 模块内，确保
//! flutter_rust_bridge_codegen 扫描 crate::api 时可见，自动生成
//! SseEncode 绑定（遗留项 3：同步引擎 FFI 事件流）。
//! sync/events.rs 从本文件 re-export，领域层与 FFI 层共用同一份定义。

use serde::{Deserialize, Serialize};

/// 同步进度阶段
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SyncProgressPhase {
    Started,
    Pulling,
    Pushing,
    Uploading,
    Done,
    Error,
}

/// 同步进度事件
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SyncProgressEvent {
    pub phase: SyncProgressPhase,
    pub progress: f32,
    pub message: String,
}

/// AI 流式输出事件
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AiStreamEvent {
    pub block_id: String,
    pub chunk: String,
    pub is_complete: bool,
}

/// 文件同步事件状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FileSyncEventStatus {
    Uploading,
    Downloaded,
    Error,
}

/// 文件同步事件
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FileSyncEvent {
    pub file_path: String,
    pub status: FileSyncEventStatus,
    pub progress: f32,
}
