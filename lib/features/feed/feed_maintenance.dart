import 'package:moodiary/persistence/isar.dart';

/// 订阅条目引用（维护用，纯数据便于单测）。
class FeedEntryRef {
  final String diaryId;
  final String sourceUrl;
  final String title;
  final String content;
  final DateTime time;
  final List<String> tags;

  const FeedEntryRef({
    required this.diaryId,
    required this.sourceUrl,
    required this.title,
    this.content = '',
    required this.time,
    this.tags = const [],
  });
}

/// 清理计划：重复条目（保留最新）与标签规范化。
class FeedCleanupPlan {
  final List<String> recycleDiaryIds;
  final int duplicateGroups;

  /// diaryId → 规范化后的标签
  final Map<String, List<String>> tagUpdates;

  const FeedCleanupPlan({
    this.recycleDiaryIds = const [],
    this.duplicateGroups = 0,
    this.tagUpdates = const {},
  });

  int get total => recycleDiaryIds.length + tagUpdates.length;
}

/// 内容源维护：清理重复订阅条目（软删除进回收站）+ 来源标签规范化。
class FeedMaintenance {
  FeedMaintenance._();

  /// 归一化后的分组键：来源链接 + 正文指纹（前 200 字）。
  ///
  /// 同一篇文章可能被源以不同标题重复发布，因此指纹**剔除标题/来源/链接行**，
  /// 只保留正文；正文为空时回退标题。
  static String groupKey(FeedEntryRef e) {
    final body = e.content
        .split('\n')
        .where((line) {
          final t = line.trimLeft();
          return !t.startsWith('#') && !t.startsWith('>') && !t.startsWith('🔗');
        })
        .join('\n')
        .replaceAll(RegExp(r'\s+'), '');
    final base = body.isNotEmpty
        ? body.substring(0, body.length > 200 ? 200 : body.length)
        : e.title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return '${e.sourceUrl.trim()}|$base';
  }

  /// 标签规范化：把 URL 形态的标签换成主机名。
  static List<String> normalizeTags(List<String> tags) {
    final out = <String>[];
    final seen = <String>{};
    for (final tag in tags) {
      var t = tag.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('http://') || t.startsWith('https://')) {
        try {
          final host = Uri.parse(t).host;
          if (host.isNotEmpty) t = host;
        } catch (_) {
          // 无法解析则保留原值
        }
      }
      if (seen.add(t)) out.add(t);
    }
    return out;
  }

  /// 纯函数：生成清理计划（同组保留时间最新的一条，其余回收）。
  static FeedCleanupPlan plan(List<FeedEntryRef> entries) {
    final groups = <String, List<FeedEntryRef>>{};
    for (final e in entries) {
      groups.putIfAbsent(groupKey(e), () => []).add(e);
    }
    final recycle = <String>[];
    var duplicateGroups = 0;
    for (final group in groups.values) {
      if (group.length <= 1) continue;
      duplicateGroups++;
      final sorted = List<FeedEntryRef>.from(group)
        ..sort((a, b) => b.time.compareTo(a.time));
      recycle.addAll(sorted.skip(1).map((e) => e.diaryId));
    }
    final tagUpdates = <String, List<String>>{};
    for (final e in entries) {
      final normalized = normalizeTags(e.tags);
      if (!_sameTags(normalized, e.tags)) {
        tagUpdates[e.diaryId] = normalized;
      }
    }
    return FeedCleanupPlan(
      recycleDiaryIds: recycle,
      duplicateGroups: duplicateGroups,
      tagUpdates: tagUpdates,
    );
  }

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 扫描已入库订阅条目并生成计划。
  static Future<FeedCleanupPlan> preview() async {
    try {
      final blocks = await IsarUtil.getAllVisibleBlocks();
      final entries = <FeedEntryRef>[];
      for (final block in blocks) {
        final meta = block.meta;
        if (meta.captureType != 'feed') continue;
        final diary = await IsarUtil.getDiaryById(block.diaryId);
        if (diary == null || !diary.show) continue;
        entries.add(
          FeedEntryRef(
            diaryId: diary.id,
            sourceUrl: meta.sourceUrl,
            title: diary.title,
            content: diary.contentText,
            time: diary.time,
            tags: diary.tags,
          ),
        );
      }
      return plan(entries);
    } catch (_) {
      return const FeedCleanupPlan();
    }
  }

  /// 执行计划：回收重复条目 + 更新来源标签；返回回收条数。
  static Future<int> apply(FeedCleanupPlan plan) async {
    var recycled = 0;
    for (final id in plan.recycleDiaryIds) {
      try {
        final diary = await IsarUtil.getDiaryById(id);
        if (diary == null) continue;
        await IsarUtil.moveDiaryToRecycle(diary.isarId);
        recycled++;
      } catch (_) {
        // 单条失败不中断
      }
    }
    for (final entry in plan.tagUpdates.entries) {
      try {
        final diary = await IsarUtil.getDiaryById(entry.key);
        if (diary == null) continue;
        final updated = diary.clone()..tags = entry.value;
        await IsarUtil.updateADiary(oldDiary: diary, newDiary: updated);
      } catch (_) {
        // 单条失败不中断
      }
    }
    return recycled;
  }
}
