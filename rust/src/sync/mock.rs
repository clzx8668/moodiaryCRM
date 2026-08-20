//! Phase 1 同步引擎空实现（Mock）占位
//!
//! 按架构文档 7.1：VectorIndex 先用 Mock 返回空结果；Phase 3 启用 `vector-db`
//! Cargo Feature 后替换为 LanceDB 真实实现，调用方无需改动（依赖倒置）。

use crate::sync::models::*;
use crate::sync::traits::*;
use anyhow::Result;
use std::path::{Path, PathBuf};

/// SyncEngine 骨架实现（返回 Idle / Ok，占位）
#[derive(Debug, Clone, Copy, Default)]
pub struct MockSyncEngine;

impl SyncEngine for MockSyncEngine {
    async fn initialize(&self) -> Result<()> {
        Ok(())
    }

    async fn full_sync(&self) -> Result<()> {
        Ok(())
    }

    async fn auto_sync_if_needed(&self) -> Result<()> {
        Ok(())
    }

    async fn get_sync_status(&self) -> Result<SyncStateStatus> {
        Ok(SyncStateStatus::Idle)
    }

    async fn cancel_sync(&self) -> Result<()> {
        Ok(())
    }
}

/// PullEngine 骨架实现（返回空变更集，占位）
#[derive(Debug, Clone, Copy, Default)]
pub struct MockPullEngine;

impl PullEngine for MockPullEngine {
    async fn pull_diary_changes(&self, _since_timestamp: i64) -> Result<Vec<DiaryChange>> {
        Ok(Vec::new())
    }

    async fn pull_block_changes(
        &self,
        _diary_uuid: String,
        _since_timestamp: i64,
    ) -> Result<Vec<BlockChange>> {
        Ok(Vec::new())
    }

    async fn pull_crm_entities(&self) -> Result<Vec<CrmEntity>> {
        Ok(Vec::new())
    }
}

/// PushEngine 骨架实现（空结果，占位）
#[derive(Debug, Clone, Copy, Default)]
pub struct MockPushEngine;

impl PushEngine for MockPushEngine {
    async fn push_pending_diaries(&self) -> Result<PushResult> {
        Ok(PushResult::default())
    }

    async fn push_pending_blocks(&self, _diary_uuid: String) -> Result<PushResult> {
        Ok(PushResult::default())
    }

    async fn push_crm_cache_updates(&self) -> Result<PushResult> {
        Ok(PushResult::default())
    }
}

/// FileSyncEngine 骨架实现（占位：上传成功标记、路径拼接）
#[derive(Debug, Clone, Copy, Default)]
pub struct MockFileSyncEngine;

impl FileSyncEngine for MockFileSyncEngine {
    async fn upload_file(&self, local_path: &Path) -> Result<UploadResult> {
        Ok(UploadResult {
            file_path: local_path.to_string_lossy().into_owned(),
            success: true,
            ..UploadResult::default()
        })
    }

    async fn download_file(&self, remote_path: &str, local_dir: &Path) -> Result<PathBuf> {
        Ok(local_dir.join(remote_path.trim_start_matches('/')))
    }

    async fn sync_orphaned_files(&self) -> Result<SyncOrphanedFilesResult> {
        Ok(SyncOrphanedFilesResult::default())
    }

    async fn sync_file_references(&self, _diary_uuid: String) -> Result<()> {
        Ok(())
    }
}

/// AiProcessor 骨架实现（空向量/空结果，占位）
#[derive(Debug, Clone, Copy, Default)]
pub struct MockAiProcessor;

impl AiProcessor for MockAiProcessor {
    async fn process_note_with_template(
        &self,
        _note_id: String,
        _template: AiTemplate,
    ) -> Result<Vec<BlockDto>> {
        Ok(Vec::new())
    }

    async fn generate_embedding(&self, _text: &str) -> Result<Vec<f32>> {
        Ok(Vec::new())
    }

    async fn build_rag_context(
        &self,
        _query: &str,
        _knowledge_base_id: Option<String>,
        _top_k: usize,
    ) -> Result<RagContext> {
        Ok(RagContext::default())
    }
}

/// VectorIndex 骨架实现（Mock 占位，Phase 3 替换为 LanceDB）
#[derive(Debug, Clone, Copy, Default)]
pub struct MockVectorIndex;

impl VectorIndex for MockVectorIndex {
    async fn index_block(&self, _block: &BlockDto) -> Result<()> {
        Ok(())
    }

    async fn reindex_block(&self, _block: &BlockDto) -> Result<()> {
        Ok(())
    }

    async fn remove_block_index(&self, _block_id: &str) -> Result<()> {
        Ok(())
    }

    async fn search(
        &self,
        _query: &str,
        _top_k: usize,
        _knowledge_base_id: Option<String>,
    ) -> Result<Vec<SearchResult>> {
        Ok(Vec::new())
    }
}
