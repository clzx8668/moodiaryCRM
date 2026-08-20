//! Rust 同步引擎（Phase 1 骨架）
//!
//! 目录职责（对齐 docs/二次开发计划.md P1.3/P1.4 与架构文档第四/五节）：
//! - `models.rs`：同步 DTO（bincode/JSON 双序列化，扁平结构）
//! - `events.rs`：FFI 事件总线数据结构
//! - `traits.rs`：SyncEngine / PullEngine / PushEngine / FileSyncEngine /
//!   ConflictResolver / AiProcessor / VectorIndex 核心接口
//! - `conflict.rs`：LWW 冲突解决（ConflictResolver 实现）
//! - `serializer.rs`：Block 序列化 + bincode/JSON 编解码
//! - `logger.rs`：结构化 JSON 同步日志
//! - `backoff.rs`：指数退避（P1.8 限流预置）
//! - `mock.rs`：Phase 1 空实现占位
//!
//! 适配决策：Isar 以 Flutter 端为唯一真相层，Rust 只收发扁平 DTO，不直接持有数据库。

pub mod backoff;
pub mod conflict;
pub mod events;
pub mod logger;
pub mod mock;
pub mod models;
pub mod serializer;
pub mod traits;

#[cfg(feature = "vector-db")]
pub mod local_vector_index;

use std::time::{SystemTime, UNIX_EPOCH};

/// 当前 Unix 毫秒时间戳（日志/冲突记录/事件统一时钟）
pub(crate) fn now_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}
