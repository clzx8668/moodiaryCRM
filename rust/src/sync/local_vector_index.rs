//! 本地向量索引（P3.1：vector-db Feature 的真实 VectorIndex 实现）。
//!
//! 纯 Rust 内存实现 + 余弦相似度，作为 LanceDB 的轻量替代：
//! - `VectorIndex` trait 保持不变，调用方无需改动（依赖倒置，架构文档 7.1）；
//! - Embedding 由可注入的 embedder 提供（真实场景接 FFI/Dart 端 embedding API）；
//! - `build_rag_context` 完成 query → topK → 拼装上下文（P3.5）。
//!
//! 后续接入 LanceDB 时，仅替换本模块内部存储，trait 与调用方不变。

use std::collections::HashMap;
use std::sync::Mutex;

use anyhow::Result;

use crate::sync::models::{BlockDto, RagContext, SearchResult};
use crate::sync::traits::VectorIndex;

type Embedder = Box<dyn Fn(&str) -> Vec<f32> + Send + Sync>;

/// 本地向量索引（线程安全：内部 Mutex）
pub struct LocalVectorIndex {
    inner: Mutex<IndexInner>,
    embed: Embedder,
}

struct IndexInner {
    dimension: usize,
    entries: HashMap<String, IndexedEntry>,
}

struct IndexedEntry {
    diary_id: String,
    text: String,
    embedding: Vec<f32>,
    knowledge_base_id: Option<String>,
}

impl LocalVectorIndex {
    /// 以指定维度创建（默认零向量 embedder，需配合 with_embedder 才有检索能力）
    pub fn new(dimension: usize) -> Self {
        Self::with_embedder(dimension, move |_| vec![0.0; dimension])
    }

    /// 注入真实 Embedding 函数
    pub fn with_embedder<F>(dimension: usize, embed: F) -> Self
    where
        F: Fn(&str) -> Vec<f32> + Send + Sync + 'static,
    {
        Self {
            inner: Mutex::new(IndexInner {
                dimension,
                entries: HashMap::new(),
            }),
            embed: Box::new(embed),
        }
    }

    /// 插入/更新向量（幂等）
    pub fn upsert(
        &self,
        block_id: &str,
        diary_id: &str,
        text: &str,
        embedding: Vec<f32>,
        knowledge_base_id: Option<String>,
    ) {
        let mut inner = self.inner.lock().unwrap();
        if embedding.len() != inner.dimension {
            return; // 维度不匹配直接忽略，保证索引一致性
        }
        inner.entries.insert(
            block_id.to_string(),
            IndexedEntry {
                diary_id: diary_id.to_string(),
                text: text.to_string(),
                embedding,
                knowledge_base_id,
            },
        );
    }

    /// 移除索引
    pub fn remove(&self, block_id: &str) {
        self.inner.lock().unwrap().entries.remove(block_id);
    }

    /// 索引条目数
    pub fn len(&self) -> usize {
        self.inner.lock().unwrap().entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// 取条目文本（RAG 上下文拼装用）
    pub fn text_of(&self, block_id: &str) -> Option<String> {
        self.inner
            .lock()
            .unwrap()
            .entries
            .get(block_id)
            .map(|e| e.text.clone())
    }

    /// 余弦相似度（零向量返回 0）
    pub fn cosine(a: &[f32], b: &[f32]) -> f32 {
        if a.len() != b.len() || a.is_empty() {
            return 0.0;
        }
        let mut dot = 0.0f64;
        let mut na = 0.0f64;
        let mut nb = 0.0f64;
        for (x, y) in a.iter().zip(b.iter()) {
            dot += (*x as f64) * (*y as f64);
            na += (*x as f64) * (*x as f64);
            nb += (*y as f64) * (*y as f64);
        }
        if na == 0.0 || nb == 0.0 {
            0.0
        } else {
            (dot / (na.sqrt() * nb.sqrt())) as f32
        }
    }

    /// 向量检索（按知识库过滤 + topK）
    pub fn search_by_embedding(
        &self,
        query_embedding: &[f32],
        top_k: usize,
        knowledge_base_id: Option<&str>,
    ) -> Vec<SearchResult> {
        let inner = self.inner.lock().unwrap();
        let mut scored: Vec<(&String, &IndexedEntry, f32)> = inner
            .entries
            .iter()
            .filter(|e| match knowledge_base_id {
                Some(kb) => e.1.knowledge_base_id.as_deref() == Some(kb),
                None => true,
            })
            .map(|(id, e)| {
                let score = Self::cosine(query_embedding, &e.embedding);
                (id, e, score)
            })
            .collect();
        scored.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap_or(std::cmp::Ordering::Equal));
        scored
            .into_iter()
            .take(top_k)
            .map(|(id, e, score)| SearchResult {
                block_id: id.clone(),
                score,
                snippet: e.text.chars().take(120).collect(),
                knowledge_base_id: e.knowledge_base_id.clone(),
            })
            .collect()
    }

    /// P3.5：query → 检索 topK → 拼装 RAG 上下文
    pub fn build_rag_context(
        &self,
        query: &str,
        top_k: usize,
        knowledge_base_id: Option<&str>,
    ) -> RagContext {
        let query_embedding = (self.embed)(query);
        let sources = self.search_by_embedding(&query_embedding, top_k, knowledge_base_id);
        let context = if sources.is_empty() {
            format!("（知识库中未检索到相关内容）\n\n问题：{query}")
        } else {
            let mut buf = String::from("## 参考内容\n\n");
            for (i, hit) in sources.iter().enumerate() {
                let text = self
                    .text_of(&hit.block_id)
                    .unwrap_or_else(|| hit.snippet.clone());
                buf.push_str(&format!("[{i}] {text}\n\n"));
            }
            buf.push_str(&format!("## 问题\n{query}"));
            buf
        };
        RagContext {
            query: query.to_string(),
            context,
            sources,
            generated_at: crate::sync::now_millis(),
        }
    }
}

impl VectorIndex for LocalVectorIndex {
    async fn index_block(&self, block: &BlockDto) -> Result<()> {
        let embedding = (self.embed)(&block.content);
        self.upsert(&block.id, &block.diary_id, &block.content, embedding, None);
        Ok(())
    }

    async fn reindex_block(&self, block: &BlockDto) -> Result<()> {
        self.index_block(block).await
    }

    async fn remove_block_index(&self, block_id: &str) -> Result<()> {
        self.remove(block_id);
        Ok(())
    }

    async fn search(
        &self,
        query: &str,
        top_k: usize,
        knowledge_base_id: Option<String>,
    ) -> Result<Vec<SearchResult>> {
        let query_embedding = (self.embed)(query);
        Ok(self.search_by_embedding(
            &query_embedding,
            top_k,
            knowledge_base_id.as_deref(),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 确定性 embedder：字符桶计数（相似文本产生相似向量）
    fn char_bag(dimension: usize) -> impl Fn(&str) -> Vec<f32> {
        move |s: &str| {
            let mut v = vec![0.0f32; dimension];
            for c in s.chars() {
                let idx = (c as usize) % dimension;
                v[idx] += 1.0;
            }
            v
        }
    }

    fn block(id: &str, diary: &str, content: &str) -> BlockDto {
        BlockDto {
            id: id.to_string(),
            diary_id: diary.to_string(),
            block_type: crate::sync::models::BlockTypeDto::Text,
            content: content.to_string(),
            sort_order: 0,
            is_deleted: false,
            stream_buffer: String::new(),
            stream_complete: true,
            created_at: 0,
            updated_at: 0,
        }
    }

    fn run<F: std::future::Future>(future: F) -> F::Output {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime")
            .block_on(future)
    }

    #[test]
    fn cosine_similarity_basics() {
        assert_eq!(LocalVectorIndex::cosine(&[1.0, 0.0], &[1.0, 0.0]), 1.0);
        assert_eq!(LocalVectorIndex::cosine(&[1.0, 0.0], &[0.0, 1.0]), 0.0);
        assert_eq!(LocalVectorIndex::cosine(&[0.0, 0.0], &[1.0, 1.0]), 0.0);
        assert_eq!(LocalVectorIndex::cosine(&[], &[]), 0.0);
    }

    #[test]
    fn upsert_and_search_returns_top_hit() {
        let index = LocalVectorIndex::new(3);
        index.upsert("b1", "d1", "苹果 香蕉 会议", vec![1.0, 0.0, 0.0], None);
        index.upsert("b2", "d1", "合同 回款 发票", vec![0.0, 1.0, 0.0], None);

        let hits = index.search_by_embedding(&[1.0, 0.0, 0.0], 3, None);
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].snippet, "苹果 香蕉 会议");
        assert!(hits[0].score >= hits[1].score);
    }

    #[test]
    fn search_filters_by_knowledge_base() {
        let index = LocalVectorIndex::new(1);
        index.upsert("b1", "d1", "客户 张三", vec![1.0], Some("kb1".into()));
        index.upsert("b2", "d1", "客户 张三", vec![1.0], Some("kb2".into()));

        let hits = index.search_by_embedding(&[1.0], 10, Some("kb1"));
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].knowledge_base_id.as_deref(), Some("kb1"));
    }

    #[test]
    fn remove_drops_entry() {
        let index = LocalVectorIndex::new(1);
        index.upsert("b1", "d1", "内容", vec![1.0], None);
        assert_eq!(index.len(), 1);
        index.remove("b1");
        assert!(index.is_empty());
    }

    #[test]
    fn vector_index_trait_roundtrip() {
        let index = LocalVectorIndex::with_embedder(64, char_bag(64));
        let b = block("blk-1", "d-1", "深度学习 神经网络");
        run(async {
            index.index_block(&b).await.expect("index ok");
            index.reindex_block(&b).await.expect("reindex ok");
            let hits = index.search("神经网络", 5, None).await.expect("search ok");
            assert_eq!(hits.len(), 1);
            assert_eq!(hits[0].snippet, "深度学习 神经网络");
            index.remove_block_index("blk-1").await.expect("remove ok");
            assert!(index.is_empty());
        });
    }

    #[test]
    fn build_rag_context_assembles_sources() {
        let index = LocalVectorIndex::with_embedder(
            2,
            |s: &str| {
                if s.contains("张三") {
                    vec![1.0, 0.0]
                } else {
                    vec![0.0, 1.0]
                }
            },
        );
        index.upsert("b1", "d1", "明天下午三点与张三开会", vec![1.0, 0.0], None);
        index.upsert("b2", "d1", "寄送样品给李四", vec![0.0, 1.0], None);

        let ctx = index.build_rag_context("张三 会议", 2, None);
        assert!(ctx.context.contains("## 参考内容"));
        assert!(ctx.context.contains("明天下午三点与张三开会"));
        assert!(ctx.context.contains("## 问题"));
        assert!(ctx.context.contains("张三 会议"));
        assert_eq!(ctx.sources.len(), 2);
        assert!(ctx.generated_at > 0);
    }

    #[test]
    fn build_rag_context_empty_kb() {
        let index = LocalVectorIndex::with_embedder(8, char_bag(8));
        let ctx = index.build_rag_context("没有内容", 5, None);
        assert!(ctx.sources.is_empty());
        assert!(ctx.context.contains("未检索到相关内容"));
    }
}
