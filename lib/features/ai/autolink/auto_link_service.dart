/// 智能关联（建议制）：按「标签重叠 + 标题相似」轻量推荐相关笔记。
///
/// 纯函数、可单测；后续可平滑替换为向量相似（复用 RagService）。
class RelatedNote {
  final String diaryId;
  final String title;
  final int sharedTags;
  final int titleOverlap;

  const RelatedNote({
    required this.diaryId,
    required this.title,
    required this.sharedTags,
    required this.titleOverlap,
  });

  int get score => sharedTags * 10 + titleOverlap;
}

/// 参与关联建议的最小数据（避免依赖 Diary/DB 领域模型，便于测试）。
class NoteSummary {
  final String id;
  final String title;
  final List<String> tags;

  const NoteSummary({
    required this.id,
    required this.title,
    required this.tags,
  });
}

class AutoLinkService {
  AutoLinkService._();

  static List<String> _tokens(String s) =>
      s.split(RegExp(r'[\s,，。、；;：:/]+'))
          .map((e) => e.trim())
          .where((e) => e.length >= 2)
          .toList();

  /// 为 [target] 推荐最相关的前 [topK] 条（排除自身）。
  static List<RelatedNote> suggest({
    required NoteSummary target,
    required List<NoteSummary> all,
    int topK = 5,
  }) {
    final targetTitle = _tokens(target.title.toLowerCase());
    final results = <RelatedNote>[];
    final excluded = <String>{target.id};
    for (final note in all) {
      if (excluded.contains(note.id)) continue;
      final shared = target.tags.where(note.tags.contains).toSet().length;
      final noteTitle = _tokens(note.title.toLowerCase());
      final titleOverlap =
          targetTitle.where(noteTitle.contains).length;
      if (shared > 0 || titleOverlap > 0) {
        results.add(
          RelatedNote(
            diaryId: note.id,
            title: note.title,
            sharedTags: shared,
            titleOverlap: titleOverlap,
          ),
        );
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }
}
