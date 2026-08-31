import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/block/markdown_projection.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/features/rag/models/block_embedding.dart';
import 'package:moodiary/features/rag/models/knowledge_base.dart';
import 'package:moodiary/persistence/isar.dart';

/// RAG 服务（P3.2/P3.3/P3.5）：
/// - 知识库 CRUD；
/// - 增量索引：Text/完成态 AI Block → Embedding → 本地向量表；
/// - 检索：query → Embedding → 余弦 topK → 拼装上下文。
///
/// 向量存储用 Drift 表（BlockEmbeddings），Rust 侧 `LocalVectorIndex`
/// 提供同构契约与单元测试，后续可平滑切换到 LanceDB（依赖倒置）。
class RagService {
  AiProvider? _provider;

  Future<AiProvider> _ensureProvider() async {
    return _provider ??= await AiProviderFactory.load();
  }

  @visibleForTesting
  void overrideProvider(AiProvider provider) {
    _provider = provider;
  }

  // ==================== 知识库 CRUD（P3.2） ====================

  Future<List<KnowledgeBase>> listKnowledgeBases() =>
      IsarUtil.getAllKnowledgeBases();

  Future<KnowledgeBase> createKnowledgeBase(
    String name, {
    String description = '',
  }) async {
    final kb = KnowledgeBase()
      ..name = name.trim()
      ..description = description.trim();
    if (kb.name.isEmpty) {
      throw ArgumentError('知识库名称不能为空');
    }
    await IsarUtil.upsertKnowledgeBase(kb);
    return kb;
  }

  Future<void> deleteKnowledgeBase(String id) =>
      IsarUtil.deleteKnowledgeBase(id);

  Future<int> countEmbeddings(String kbId) =>
      IsarUtil.countEmbeddingsByKnowledgeBase(kbId);

  /// 重建全部知识库向量索引（P4.3 数据健康度），返回 (知识库数, 成功索引块数)
  Future<ReindexAllResult> reindexAll() async {
    final knowledgeBases = await IsarUtil.getAllKnowledgeBases();
    var indexed = 0;
    var succeeded = 0;
    for (final kb in knowledgeBases) {
      try {
        indexed += await indexBlocks(knowledgeBaseId: kb.id);
        succeeded++;
      } catch (_) {
        // 单库失败（如 Embedding 模型未配置/网络错误）不中断其余库
      }
    }
    return ReindexAllResult(
      knowledgeBases: knowledgeBases.length,
      succeeded: succeeded,
      indexed: indexed,
    );
  }

  // ==================== 增量索引（P3.3） ====================

  /// 索引指定日记（或全部）的 Text / 完成态 AI Block。
  /// 返回成功索引的块数；embedding 失败（网络等）跳过。
  Future<int> indexBlocks({
    required String knowledgeBaseId,
    String? diaryId,
  }) async {
    final provider = await _ensureProvider();
    final List<Block> blocks;
    if (diaryId != null) {
      blocks = await IsarUtil.getBlocksByDiary(diaryId);
    } else {
      blocks = await IsarUtil.getAllVisibleBlocks();
    }
    var indexed = 0;
    for (final block in blocks) {
      if (!_indexable(block)) continue;
      final text = MarkdownProjection.blockToMarkdown(block);
      if (text.trim().isEmpty) continue;
      try {
        final vector = await provider.embed(text);
        await IsarUtil.upsertBlockEmbedding(
          BlockEmbedding()
            ..blockId = block.id
            ..diaryId = block.diaryId
            ..knowledgeBaseId = knowledgeBaseId
            ..text = text
            ..embedding = Float32List.fromList(vector),
        );
        indexed++;
      } catch (_) {
        // 单块失败不中断整体索引
      }
    }
    return indexed;
  }

  /// 单块重索引（Block 修改后调用）
  Future<void> reindexBlock({
    required String knowledgeBaseId,
    required Block block,
  }) async {
    await removeBlock(knowledgeBaseId: knowledgeBaseId, blockId: block.id);
    if (!_indexable(block)) return;
    final provider = await _ensureProvider();
    final text = MarkdownProjection.blockToMarkdown(block);
    if (text.trim().isEmpty) return;
    final vector = await provider.embed(text);
    await IsarUtil.upsertBlockEmbedding(
      BlockEmbedding()
        ..blockId = block.id
        ..diaryId = block.diaryId
        ..knowledgeBaseId = knowledgeBaseId
        ..text = text
        ..embedding = Float32List.fromList(vector),
    );
  }

  Future<void> removeBlock({
    required String knowledgeBaseId,
    required String blockId,
  }) =>
      IsarUtil.deleteBlockEmbedding(blockId, knowledgeBaseId);

  /// Obsidian Vault 向量化：把已扫描的 .md 文件索引进指定知识库
  /// （blockId 前缀 `obsidian:`，diaryId 固定 `obsidian`）；同时清理已删除文件的陈旧向量。
  Future<int> indexObsidian({required String knowledgeBaseId}) async {
    final provider = await _ensureProvider();
    final files = ObsidianService.instance.files;
    final seen = <String>{};
    var indexed = 0;
    for (final f in files) {
      final text = f.content.trim();
      if (text.isEmpty) continue;
      final blockId = 'obsidian:${f.relativePath}';
      seen.add(blockId);
      try {
        final vector = await provider.embed(text);
        await IsarUtil.upsertBlockEmbedding(
          BlockEmbedding()
            ..blockId = blockId
            ..diaryId = 'obsidian'
            ..knowledgeBaseId = knowledgeBaseId
            ..text = text
            ..embedding = Float32List.fromList(vector),
        );
        indexed++;
      } catch (_) {
        // 单文件失败不中断整体索引
      }
    }
    final entries =
        await IsarUtil.getEmbeddingsByKnowledgeBase(knowledgeBaseId);
    for (final e in entries) {
      if (e.blockId.startsWith('obsidian:') && !seen.contains(e.blockId)) {
        await IsarUtil.deleteBlockEmbedding(e.blockId, knowledgeBaseId);
      }
    }
    return indexed;
  }

  static bool _indexable(Block block) {
    switch (block.blockType) {
      case BlockType.text:
      case BlockType.todo:
      case BlockType.code:
        return true;
      case BlockType.aiStream:
        return block.streamComplete && block.content.trim().isNotEmpty;
      default:
        return false;
    }
  }

  // ==================== 检索与上下文（P3.5） ====================

  Future<List<RagHit>> search(
    String knowledgeBaseId,
    String query, {
    int topK = 5,
  }) async {
    final provider = await _ensureProvider();
    final queryVector = await provider.embed(query);
    final entries = await IsarUtil.getEmbeddingsByKnowledgeBase(
      knowledgeBaseId,
    );
    final scored = <({BlockEmbedding e, double s})>[];
    for (final e in entries) {
      if (e.embedding.length != queryVector.length) continue;
      scored.add(
        (
          e: e,
          s: RagService.cosine(
            Float32List.fromList(queryVector),
            e.embedding,
          ),
        ),
      );
    }
    scored.sort((a, b) => b.s.compareTo(a.s));
    return scored
        .take(topK)
        .map(
          (x) => RagHit(
            blockId: x.e.blockId,
            diaryId: x.e.diaryId,
            knowledgeBaseId: x.e.knowledgeBaseId,
            text: x.e.text,
            score: x.s,
          ),
        )
        .toList();
  }

  /// 检索 topK 并拼装 RAG 上下文
  Future<RagContextResult> buildContext(
    String knowledgeBaseId,
    String query, {
    int topK = 5,
  }) async {
    final hits = await search(knowledgeBaseId, query, topK: topK);
    final buffer = StringBuffer();
    if (hits.isEmpty) {
      buffer.writeln('（知识库中未检索到相关内容）');
      buffer.writeln();
      buffer.write('问题：$query');
    } else {
      buffer.writeln('## 参考内容');
      buffer.writeln();
      for (var i = 0; i < hits.length; i++) {
        buffer.writeln('[${i + 1}] ${hits[i].text}');
        buffer.writeln();
      }
      buffer.write('## 问题');
      buffer.write('\n$query');
    }
    return RagContextResult(
      query: query,
      context: buffer.toString(),
      hits: hits,
    );
  }

  /// 余弦相似度（零向量返回 0）
  static double cosine(Float32List a, Float32List b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }
}

/// 检索命中
class RagHit {
  final String blockId;
  final String diaryId;
  final String knowledgeBaseId;
  final String text;
  final double score;

  const RagHit({
    required this.blockId,
    required this.diaryId,
    required this.knowledgeBaseId,
    required this.text,
    required this.score,
  });
}

/// RAG 上下文结果
class RagContextResult {
  final String query;
  final String context;
  final List<RagHit> hits;

  const RagContextResult({
    required this.query,
    required this.context,
    required this.hits,
  });
}

/// 全量重建向量索引结果（P4.3 数据健康度）
class ReindexAllResult {
  final int knowledgeBases;
  final int succeeded;
  final int indexed;

  const ReindexAllResult({
    required this.knowledgeBases,
    required this.succeeded,
    required this.indexed,
  });
}
