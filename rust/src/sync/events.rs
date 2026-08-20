//! FFI 事件总线数据结构（架构文档 5.3）。
//!
//! 权威定义移至 crate::api::sync_events（保证 codegen 可见），
//! 此处 re-export 保持 sync 领域模块的既有引用路径不变。

pub use crate::api::sync_events::*;
