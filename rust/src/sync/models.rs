//! 同步领域 DTO（扁平化，供 FFI/同步引擎/测试共用）
//!
//! 对应架构文档"三、Rust 层数据库模型设计"与"四、同步引擎接口设计"，
//! 但遵循项目适配决策：Isar 真相层在 Flutter 端，此处结构仅作为跨层同步 DTO。
//! 序列化优先 bincode（FFI），JSON 用于迁移/日志/调试。

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Block 类型（Phase 1 需与 Flutter 端 Isar `BlockType` 联调对齐）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BlockTypeDto {
    Text,
    SmartEntity,
    Todo,
    Chart,
    AiStream,
    Image,
    Code,
}

/// 记录级同步状态（Isar 对应字段）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SyncStatus {
    Synced,
    Pending,
    Conflict,
}

/// 引擎级同步状态（SyncState 表）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SyncStateStatus {
    Idle,
    Syncing,
    Error,
}

/// 变更类型（拉/推增量）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ChangeType {
    Upsert,
    Delete,
}

/// 日记 DTO
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiaryDto {
    pub id: String,
    pub title: String,
    pub content_preview: String,
    pub mood: Option<String>,
    pub tags: Vec<String>,
    pub twenty_id: Option<String>,
    pub sync_status: SyncStatus,
    pub last_modified: i64,
    pub last_sync_time: i64,
    /// JSON 数组字符串（Block 列表，双模态协议）
    pub blocks: String,
    pub created_at: i64,
}

/// Block DTO
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BlockDto {
    pub id: String,
    pub diary_id: String,
    pub block_type: BlockTypeDto,
    /// Markdown 文本或结构化 JSON 字符串
    pub content: String,
    pub sort_order: i32,
    pub is_deleted: bool,
    /// AI 流式输出缓冲（断点恢复，架构文档 6.4）
    pub stream_buffer: String,
    pub stream_complete: bool,
    pub created_at: i64,
    pub updated_at: i64,
}

/// CRM 本地缓存 DTO
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrmContactCacheDto {
    pub id: String,
    pub contact_name: String,
    pub company_name: Option<String>,
    pub twenty_id: String,
    pub last_fetched: i64,
    pub local_version: i32,
}

/// 同步状态 DTO
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SyncStateDto {
    pub key: String,
    pub last_sync_time: i64,
    pub status: SyncStateStatus,
    pub error_message: Option<String>,
    pub pending_push_count: i32,
    pub pending_pull_count: i32,
}

/// CRM 实体（Twenty Companies / People / Opportunities 统一映射）
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrmEntity {
    pub id: String,
    pub object_type: String,
    pub name: String,
    pub fields: HashMap<String, String>,
    pub last_modified: i64,
}

/// 日记增量变更
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiaryChange {
    pub change_type: ChangeType,
    pub diary: DiaryDto,
}

/// Block 增量变更
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BlockChange {
    pub change_type: ChangeType,
    pub diary_uuid: String,
    pub block: BlockDto,
}

/// 冲突日志（架构文档 4.5；同步成功后持久化供用户审阅）
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ConflictLog {
    pub id: String,
    pub diary_id: String,
    pub block_id: String,
    pub conflict_type: String,
    pub local_value: String,
    pub remote_value: String,
    pub resolved_value: String,
    pub resolved_at: i64,
}

/// 日记冲突解决结果
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResolvedDiary {
    pub diary: DiaryDto,
    pub conflict_log: Option<ConflictLog>,
}

/// Block 冲突解决结果
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResolvedBlock {
    pub block: BlockDto,
    pub conflict_log: Option<ConflictLog>,
}

/// 推送结果
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct PushResult {
    pub total: u32,
    pub pushed: u32,
    pub failed: u32,
    pub errors: Vec<String>,
}

/// 上传结果
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct UploadResult {
    pub file_path: String,
    pub bytes_uploaded: u64,
    pub success: bool,
    pub error: Option<String>,
}

/// 孤立文件同步结果
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct SyncOrphanedFilesResult {
    pub orphaned: Vec<String>,
    pub cleaned: u32,
}

/// 向量搜索结果
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SearchResult {
    pub block_id: String,
    pub score: f32,
    pub snippet: String,
    pub knowledge_base_id: Option<String>,
}

/// RAG 上下文
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct RagContext {
    pub query: String,
    pub context: String,
    pub sources: Vec<SearchResult>,
    pub generated_at: i64,
}

/// AI 模板
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiTemplate {
    pub id: String,
    pub name: String,
    pub content: String,
}

/// 知识库元数据 DTO
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KnowledgeBaseDto {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub vector_store_path: String,
    pub created_at: i64,
    pub updated_at: i64,
}
