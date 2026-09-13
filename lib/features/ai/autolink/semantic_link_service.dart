import 'package:flutter/foundation.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/autolink/auto_link_service.dart';
import 'package:moodiary/features/rag/models/block_embedding.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/persistence/isar.dart';

/// 语义关联服务：日记 → Embedding → 余弦相似 Top-K（对标得到大脑「自动关联」）。
///
/// - 向量复用 Drift `BlockEmbeddings`，专用知识库 id `__autolink__`，
///   blockId 形如 `diary:<id>`，text 保存快照用于判断是否需重算；
/// - AI/嵌入未配置或调用失败时返回空，由调用方回退到标签/标题关联；
/// - `rankByVectors` 为纯函数，便于单测。
class SemanticLinkService {
  SemanticLinkService._();

  static const String kbId = '__autolink__';
  static const double minScore = 0.70;

  /// 候选（最小字段集）。
  static Future<List<RelatedNote>> suggest({
    required String diaryId,
    required String targetText,
    required List<({String id, String title, String text})> candidates,
    int topK = 4,
    int maxCandidates = 60,
  }) async {
    try {
      final provider = await AiProviderFactory.load();
      final existing = await IsarUtil.getEmbeddingsByKnowledgeBase(kbId);
      final cached = {for (final e in existing) e.blockId: e};

      Future<Float32List?> vectorOf(String id, String text) async {
        final t = text.trim();
        if (t.isEmpty) return null;
        final hit = cached['diary:$id'];
        if (hit != null && hit.text == t && hit.embedding.isNotEmpty) {
          return hit.embedding;
        }
        try {
          final v = await provider.embed(t);
          final fv = Float32List.fromList(v);
          await IsarUtil.upsertBlockEmbedding(
            BlockEmbedding()
              ..blockId = 'diary:$id'
              ..diaryId = id
              ..knowledgeBaseId = kbId
              ..text = t
              ..embedding = fv,
          );
          return fv;
        } catch (_) {
          return null;
        }
      }

      final target = await vectorOf(diaryId, targetText);
      if (target == null) return const [];

      final vectors = <String, Float32List>{};
      final titles = <String, String>{};
      for (final c in candidates.take(maxCandidates)) {
        if (c.id == diaryId) continue;
        final v = await vectorOf(c.id, c.text);
        if (v == null) continue;
        vectors[c.id] = v;
        titles[c.id] = c.title;
      }
      final ranked = rankByVectors(target, vectors);
      return ranked
          .take(topK)
          .map(
            (e) => RelatedNote(
              diaryId: e.id,
              title: titles[e.id] ?? '',
              sharedTags: 0,
              titleOverlap: 0,
              similarity: e.score,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 纯函数：给定目标向量与候选向量，返回按相似度降序（≥ 阈值）的结果。
  static List<({String id, double score})> rankByVectors(
    Float32List target,
    Map<String, Float32List> vectors, {
    double threshold = minScore,
    int? topK,
  }) {
    final scored = <({String id, double score})>[];
    for (final entry in vectors.entries) {
      final v = entry.value;
      if (v.length != target.length || v.isEmpty) continue;
      final s = RagService.cosine(target, v);
      if (s.isNaN || s < threshold) continue;
      scored.add((id: entry.key, score: s));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    if (topK != null) return scored.take(topK).toList();
    return scored;
  }

  /// 便捷：把标题 + 正文拼成用于嵌入的文本。
  static String embedText(String title, String body) {
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty) return b;
    if (b.isEmpty) return t;
    return '$t\n$b';
  }
}
