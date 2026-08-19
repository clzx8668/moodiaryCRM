//! 同步引擎核心 Trait（架构文档第四节）
//!
//! 契约要点：
//! - 输入输出均为扁平 DTO（models.rs），Rust 不直接持有 Isar 数据库；
//! - 使用原生 async Trait（Rust 1.96 / edition 2024），Mock 与真实实现可并行推进；
//! - 冲突解决统一收敛到 `ConflictResolver`（架构文档 4.2 中的 resolve_pull_conflict
//!   与 4.5 重复，以 4.5 为准，避免双实现漂移）；
//! - AI 流式解析（parse_ai_stream_response）的状态机放 Phase 2/3 的 AiParser 模块，
//!   本期只预留 AiProcessor 其余接口。

// 骨架阶段使用原生 async fn 保持契约简洁；如需 dyn 分发或显式 Send 约束，
// 后续可统一 desugar 为 `fn(...) -> impl Future + Send` 或接入 async-trait。
#![allow(async_fn_in_trait)]

use crate::sync::models::*;
use anyhow::Result;
use std::path::{Path, PathBuf};

/// 同步引擎总入口（架构文档 4.1）
pub trait SyncEngine {
    /// 初始化同步引擎，加载 SyncState
    async fn initialize(&self) -> Result<()>;

    /// 触发全量同步（用户手动）
    async fn full_sync(&self) -> Result<()>;

    /// 自动检测是否需要增量同步
    async fn auto_sync_if_needed(&self) -> Result<()>;

    /// 返回当前同步状态
    async fn get_sync_status(&self) -> Result<SyncStateStatus>;

    /// 取消正在进行的同步
    async fn cancel_sync(&self) -> Result<()>;
}

/// 增量拉取引擎（架构文档 4.2）
pub trait PullEngine {
    /// 拉取 Diary 变更
    async fn pull_diary_changes(&self, since_timestamp: i64) -> Result<Vec<DiaryChange>>;

    /// 拉取指定日记下所有变更的 Block
    async fn pull_block_changes(
        &self,
        diary_uuid: String,
        since_timestamp: i64,
    ) -> Result<Vec<BlockChange>>;

    /// 拉取 CRM 实体完整/增量数据
    async fn pull_crm_entities(&self) -> Result<Vec<CrmEntity>>;
}

/// 增量推送引擎（架构文档 4.3）
pub trait PushEngine {
    /// 推送待同步的日记
    async fn push_pending_diaries(&self) -> Result<PushResult>;

    /// 推送指定日记下所有 pending 状态的 Block
    async fn push_pending_blocks(&self, diary_uuid: String) -> Result<PushResult>;

    /// 推送本地 CRM 缓存修改
    async fn push_crm_cache_updates(&self) -> Result<PushResult>;
}

/// 文件同步引擎（架构文档 4.4，WebDAV/MinIO）
pub trait FileSyncEngine {
    /// 上传本地文件到 WebDAV
    async fn upload_file(&self, local_path: &Path) -> Result<UploadResult>;

    /// 从 WebDAV 下载文件到本地
    async fn download_file(&self, remote_path: &str, local_dir: &Path) -> Result<PathBuf>;

    /// 扫描并同步孤立文件
    async fn sync_orphaned_files(&self) -> Result<SyncOrphanedFilesResult>;

    /// 同步日记中附件元数据到 Twenty CRM
    async fn sync_file_references(&self, diary_uuid: String) -> Result<()>;
}

/// 冲突解决（架构文档 4.5，LWW）
pub trait ConflictResolver {
    /// 解决日记冲突
    fn resolve_diary_conflict(&self, local: &DiaryDto, remote: &DiaryDto) -> ResolvedDiary;

    /// 解决 Block 冲突
    fn resolve_block_conflict(&self, local: &BlockDto, remote: &BlockDto) -> ResolvedBlock;
}

/// AI 处理引擎（架构文档 4.6）
pub trait AiProcessor {
    /// 使用模板处理笔记
    async fn process_note_with_template(
        &self,
        note_id: String,
        template: AiTemplate,
    ) -> Result<Vec<BlockDto>>;

    /// 生成文本 Embedding
    async fn generate_embedding(&self, text: &str) -> Result<Vec<f32>>;

    /// 构建 RAG 上下文
    async fn build_rag_context(
        &self,
        query: &str,
        knowledge_base_id: Option<String>,
        top_k: usize,
    ) -> Result<RagContext>;
}

/// 向量索引引擎（架构文档 4.7；Phase 1/2 为 Mock，Phase 3 启用 vector-db Feature）
pub trait VectorIndex {
    /// 索引 Block
    async fn index_block(&self, block: &BlockDto) -> Result<()>;

    /// 重新索引 Block
    async fn reindex_block(&self, block: &BlockDto) -> Result<()>;

    /// 移除 Block 索引
    async fn remove_block_index(&self, block_id: &str) -> Result<()>;

    /// 执行向量搜索
    async fn search(
        &self,
        query: &str,
        top_k: usize,
        knowledge_base_id: Option<String>,
    ) -> Result<Vec<SearchResult>>;
}
