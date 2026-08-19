//! Block 序列化与 FFI 编解码（架构文档 5.2：bincode 优先；8.1：JSON 一致性）

use crate::sync::models::{BlockDto, BlockTypeDto};
use anyhow::{Result, anyhow};
use serde::{Serialize, de::DeserializeOwned};

/// bincode 编码（FFI 优先序列化）
pub fn encode_bincode<T: Serialize>(value: &T) -> Result<Vec<u8>> {
    bincode::serialize(value).map_err(|e| anyhow!("bincode 序列化失败: {e}"))
}

/// bincode 解码
pub fn decode_bincode<T: DeserializeOwned>(bytes: &[u8]) -> Result<T> {
    bincode::deserialize(bytes).map_err(|e| anyhow!("bincode 反序列化失败: {e}"))
}

/// JSON 编码
pub fn encode_json<T: Serialize>(value: &T) -> Result<String> {
    serde_json::to_string(value).map_err(|e| anyhow!("JSON 序列化失败: {e}"))
}

/// JSON 解码
pub fn decode_json<T: DeserializeOwned>(text: &str) -> Result<T> {
    serde_json::from_str(text).map_err(|e| anyhow!("JSON 反序列化失败: {e}"))
}

/// Block 序列化器（双模态协议：Markdown 文本 / 结构化 JSON）
pub struct BlockSerializer;

impl BlockSerializer {
    /// Block → JSON 字符串（持久化/迁移用）
    pub fn serialize_block(block: &BlockDto) -> Result<String> {
        encode_json(block)
    }

    /// JSON 字符串 → Block
    pub fn deserialize_block(text: &str) -> Result<BlockDto> {
        decode_json(text)
    }

    /// 是否为结构化块（内容为 JSON 而非 Markdown）
    pub fn is_structured(block: &BlockDto) -> bool {
        matches!(
            block.block_type,
            BlockTypeDto::Todo | BlockTypeDto::SmartEntity | BlockTypeDto::Chart
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sync::models::{DiaryDto, SyncStatus};

    fn text_block() -> BlockDto {
        BlockDto {
            id: "block-1".to_string(),
            diary_id: "diary-1".to_string(),
            block_type: BlockTypeDto::Text,
            content: "# 早安\n今天写了一点 **Rust** 与 🦀 的笔记。".to_string(),
            sort_order: 0,
            is_deleted: false,
            stream_buffer: String::new(),
            stream_complete: true,
            created_at: 1000,
            updated_at: 2000,
        }
    }

    fn todo_block() -> BlockDto {
        BlockDto {
            id: "block-2".to_string(),
            diary_id: "diary-1".to_string(),
            block_type: BlockTypeDto::Todo,
            content: r#"{"title":"同步 Phase 1","done":false}"#.to_string(),
            sort_order: 1,
            is_deleted: false,
            stream_buffer: String::new(),
            stream_complete: true,
            created_at: 1000,
            updated_at: 2000,
        }
    }

    fn diary_dto() -> DiaryDto {
        DiaryDto {
            id: "diary-1".to_string(),
            title: "测试日记".to_string(),
            content_preview: "预览".to_string(),
            mood: Some("happy".to_string()),
            tags: vec!["sync".to_string()],
            twenty_id: Some("t-1".to_string()),
            sync_status: SyncStatus::Pending,
            last_modified: 2000,
            last_sync_time: 1000,
            blocks: "[]".to_string(),
            created_at: 500,
        }
    }

    #[test]
    fn json_roundtrip_text_block_preserves_markdown_and_unicode() {
        let block = text_block();
        let json = BlockSerializer::serialize_block(&block).expect("序列化失败");
        let decoded = BlockSerializer::deserialize_block(&json).expect("反序列化失败");
        assert_eq!(decoded, block);
        assert!(json.contains("🦀"));
    }

    #[test]
    fn json_roundtrip_structured_block_keeps_todo_payload() {
        let block = todo_block();
        let json = BlockSerializer::serialize_block(&block).expect("序列化失败");
        let decoded = BlockSerializer::deserialize_block(&json).expect("反序列化失败");
        assert_eq!(decoded, block);
        // 内层 JSON 是字符串字段，引号会被转义；按 content 字段解析校验 payload 无损
        let parsed: serde_json::Value = serde_json::from_str(&json).expect("外层 JSON 非法");
        assert_eq!(
            parsed["content"],
            r#"{"title":"同步 Phase 1","done":false}"#
        );
    }

    #[test]
    fn bincode_roundtrip_block() {
        let block = text_block();
        let bytes = encode_bincode(&block).expect("bincode 序列化失败");
        let decoded: BlockDto = decode_bincode(&bytes).expect("bincode 反序列化失败");
        assert_eq!(decoded, block);
    }

    #[test]
    fn bincode_roundtrip_diary() {
        let diary = diary_dto();
        let bytes = encode_bincode(&diary).expect("bincode 序列化失败");
        let decoded: DiaryDto = decode_bincode(&bytes).expect("bincode 反序列化失败");
        assert_eq!(decoded, diary);
    }

    #[test]
    fn invalid_json_returns_error() {
        let err = BlockSerializer::deserialize_block("{not json");
        assert!(err.is_err());
    }

    #[test]
    fn structured_type_detection() {
        assert!(BlockSerializer::is_structured(&todo_block()));
        assert!(!BlockSerializer::is_structured(&text_block()));
        let ai = BlockDto {
            block_type: BlockTypeDto::AiStream,
            ..text_block()
        };
        assert!(!BlockSerializer::is_structured(&ai));
    }
}
