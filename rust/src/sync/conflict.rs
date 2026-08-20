//! LWW（Last Write Wins）冲突解决器实现
//!
//! 策略（架构文档 4.5 / 十一）：
//! 1. 时间戳大者胜出；
//! 2. 时间戳相同时内容一致 → 取本地、不记冲突；
//! 3. 时间戳相同时内容不一致 → 按 id 字典序确定唯一胜者（确定性），
//!    并产生 ConflictLog 供用户后续审阅/手动合并。

use crate::sync::models::*;
use crate::sync::now_millis;
use crate::sync::traits::ConflictResolver;
use std::cmp::Ordering;

/// LWW 冲突解决器（无内部状态，可安全共享）
#[derive(Debug, Clone, Copy, Default)]
pub struct LwwConflictResolver;

impl LwwConflictResolver {
    pub fn new() -> Self {
        Self
    }

    fn conflict_log(
        diary_id: &str,
        block_id: &str,
        conflict_type: &str,
        local_value: String,
        remote_value: String,
        resolved_value: String,
    ) -> ConflictLog {
        ConflictLog {
            // 骨架阶段用 "cl-<diary>-<ts>" 保证唯一；后续接 uuid crate 生成真 UUID
            id: format!("cl-{}-{}", diary_id, now_millis()),
            diary_id: diary_id.to_string(),
            block_id: block_id.to_string(),
            conflict_type: conflict_type.to_string(),
            local_value,
            remote_value,
            resolved_value,
            resolved_at: now_millis(),
        }
    }
}

impl ConflictResolver for LwwConflictResolver {
    fn resolve_diary_conflict(&self, local: &DiaryDto, remote: &DiaryDto) -> ResolvedDiary {
        match local.last_modified.cmp(&remote.last_modified) {
            Ordering::Greater => ResolvedDiary {
                diary: local.clone(),
                conflict_log: None,
            },
            Ordering::Less => ResolvedDiary {
                diary: remote.clone(),
                conflict_log: None,
            },
            Ordering::Equal => {
                if local.title == remote.title
                    && local.content_preview == remote.content_preview
                    && local.blocks == remote.blocks
                {
                    // 内容一致：视为同一版本，取本地且不记冲突
                    ResolvedDiary {
                        diary: local.clone(),
                        conflict_log: None,
                    }
                } else {
                    let winner = if local.id >= remote.id { local } else { remote };
                    let log = Self::conflict_log(
                        &winner.id,
                        "",
                        "same_timestamp_diff_content",
                        local.content_preview.clone(),
                        remote.content_preview.clone(),
                        winner.content_preview.clone(),
                    );
                    ResolvedDiary {
                        diary: winner.clone(),
                        conflict_log: Some(log),
                    }
                }
            }
        }
    }

    fn resolve_block_conflict(&self, local: &BlockDto, remote: &BlockDto) -> ResolvedBlock {
        match local.updated_at.cmp(&remote.updated_at) {
            Ordering::Greater => ResolvedBlock {
                block: local.clone(),
                conflict_log: None,
            },
            Ordering::Less => ResolvedBlock {
                block: remote.clone(),
                conflict_log: None,
            },
            Ordering::Equal => {
                if local.content == remote.content && local.stream_buffer == remote.stream_buffer {
                    ResolvedBlock {
                        block: local.clone(),
                        conflict_log: None,
                    }
                } else {
                    let winner = if local.id >= remote.id { local } else { remote };
                    let log = Self::conflict_log(
                        &winner.diary_id,
                        &winner.id,
                        "same_timestamp_diff_content",
                        local.content.clone(),
                        remote.content.clone(),
                        winner.content.clone(),
                    );
                    ResolvedBlock {
                        block: winner.clone(),
                        conflict_log: Some(log),
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn diary(id: &str, modified: i64, content: &str) -> DiaryDto {
        DiaryDto {
            id: id.to_string(),
            title: "标题".to_string(),
            content_preview: content.to_string(),
            mood: None,
            tags: Vec::new(),
            twenty_id: None,
            sync_status: SyncStatus::Pending,
            last_modified: modified,
            last_sync_time: 0,
            blocks: "[]".to_string(),
            created_at: 0,
        }
    }

    fn block(id: &str, diary_id: &str, updated: i64, content: &str) -> BlockDto {
        BlockDto {
            id: id.to_string(),
            diary_id: diary_id.to_string(),
            block_type: BlockTypeDto::Text,
            content: content.to_string(),
            sort_order: 0,
            is_deleted: false,
            stream_buffer: String::new(),
            stream_complete: false,
            created_at: 0,
            updated_at: updated,
        }
    }

    #[test]
    fn diary_local_newer_wins() {
        let resolver = LwwConflictResolver::new();
        let local = diary("d1", 200, "local");
        let remote = diary("d1", 100, "remote");
        let result = resolver.resolve_diary_conflict(&local, &remote);
        assert_eq!(result.diary.content_preview, "local");
        assert!(result.conflict_log.is_none());
    }

    #[test]
    fn diary_remote_newer_wins() {
        let resolver = LwwConflictResolver::new();
        let local = diary("d1", 100, "local");
        let remote = diary("d1", 300, "remote");
        let result = resolver.resolve_diary_conflict(&local, &remote);
        assert_eq!(result.diary.content_preview, "remote");
        assert!(result.conflict_log.is_none());
    }

    #[test]
    fn diary_equal_timestamp_same_content_takes_local_without_log() {
        let resolver = LwwConflictResolver::new();
        let local = diary("d1", 100, "same");
        let remote = diary("d1", 100, "same");
        let result = resolver.resolve_diary_conflict(&local, &remote);
        assert_eq!(result.diary.id, "d1");
        assert_eq!(result.diary.content_preview, "same");
        assert!(result.conflict_log.is_none());
    }

    #[test]
    fn diary_equal_timestamp_diff_content_deterministic_winner() {
        let resolver = LwwConflictResolver::new();
        let local = diary("a", 100, "local-a");
        let remote = diary("b", 100, "remote-b");
        let result = resolver.resolve_diary_conflict(&local, &remote);
        // "b" > "a"：remote 胜出
        assert_eq!(result.diary.id, "b");
        assert_eq!(result.diary.content_preview, "remote-b");
        let log = result.conflict_log.expect("应产生冲突日志");
        assert_eq!(log.conflict_type, "same_timestamp_diff_content");
        assert_eq!(log.local_value, "local-a");
        assert_eq!(log.remote_value, "remote-b");
        assert_eq!(log.resolved_value, "remote-b");
        assert_eq!(log.diary_id, "b");
        assert_eq!(log.block_id, "");
    }

    #[test]
    fn diary_equal_timestamp_diff_content_local_id_wins() {
        let resolver = LwwConflictResolver::new();
        let local = diary("b", 100, "local-b");
        let remote = diary("a", 100, "remote-a");
        let result = resolver.resolve_diary_conflict(&local, &remote);
        assert_eq!(result.diary.id, "b");
        assert!(result.conflict_log.is_some());
    }

    #[test]
    fn block_local_newer_wins() {
        let resolver = LwwConflictResolver::new();
        let local = block("bl", "d1", 200, "local");
        let remote = block("bl", "d1", 100, "remote");
        let result = resolver.resolve_block_conflict(&local, &remote);
        assert_eq!(result.block.content, "local");
        assert!(result.conflict_log.is_none());
    }

    #[test]
    fn block_remote_newer_wins() {
        let resolver = LwwConflictResolver::new();
        let local = block("bl", "d1", 100, "local");
        let remote = block("bl", "d1", 300, "remote");
        let result = resolver.resolve_block_conflict(&local, &remote);
        assert_eq!(result.block.content, "remote");
        assert!(result.conflict_log.is_none());
    }

    #[test]
    fn block_equal_timestamp_same_content_takes_local_without_log() {
        let resolver = LwwConflictResolver::new();
        let local = block("bl", "d1", 100, "same");
        let remote = block("bl", "d1", 100, "same");
        let result = resolver.resolve_block_conflict(&local, &remote);
        assert_eq!(result.block.content, "same");
        assert!(result.conflict_log.is_none());
    }

    #[test]
    fn block_equal_timestamp_diff_content_logged_with_block_id() {
        let resolver = LwwConflictResolver::new();
        let local = block("a", "d1", 100, "local-a");
        let remote = block("b", "d1", 100, "remote-b");
        let result = resolver.resolve_block_conflict(&local, &remote);
        assert_eq!(result.block.id, "b");
        let log = result.conflict_log.expect("应产生冲突日志");
        assert_eq!(log.block_id, "b");
        assert_eq!(log.diary_id, "d1");
        assert_eq!(log.local_value, "local-a");
        assert_eq!(log.remote_value, "remote-b");
        assert_eq!(log.resolved_value, "remote-b");
    }

    #[test]
    fn conflict_log_id_and_timestamp_are_sane() {
        let resolver = LwwConflictResolver::new();
        let local = diary("d1", 100, "local");
        let remote = diary("d1", 100, "remote");
        let result = resolver.resolve_diary_conflict(&local, &remote);
        let log = result.conflict_log.unwrap();
        assert!(!log.id.is_empty());
        assert!(log.id.starts_with("cl-"));
        assert!(log.resolved_at > 0);
    }
}
