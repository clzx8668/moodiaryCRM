import 'package:moodiary/common/models/isar/diary.dart';

/// 日历活跃度计算（架构文档"二、2. 日历热力图"）。
///
/// 综合每日记录字数、Block 数量与心情指数，归一化到 0~1：
/// - 字数：单日累计字数，封顶 2000 字后视为满分，权重 0.5；
/// - Block：单日累计 Block 数，封顶 20 个视为满分，权重 0.3；
/// - 心情：单日平均心情指数 0~1，权重 0.2。
/// 最后按当月中最高分归一化到 0~1，便于热力图着色。
class CalendarActivity {
  static const double maxWordsPerDay = 2000;
  static const int maxBlocksPerDay = 20;

  /// [diaries] 当前加载的日记；[blockCounts] diaryId -> 非删除 Block 数量。
  /// 返回 date(年月日) -> 活跃度分数(0~1)。
  static Map<DateTime, double> calculate(
    List<Diary> diaries,
    Map<String, int> blockCounts,
  ) {
    final raw = <DateTime, double>{};
    final wordCount = <DateTime, int>{};
    final blockCount = <DateTime, int>{};
    final moodSum = <DateTime, double>{};
    final moodCount = <DateTime, int>{};

    for (final diary in diaries) {
      final day = DateTime(diary.time.year, diary.time.month, diary.time.day);
      wordCount[day] = (wordCount[day] ?? 0) + diary.contentText.length;
      blockCount[day] =
          (blockCount[day] ?? 0) + (blockCounts[diary.id] ?? 0);
      moodSum[day] = (moodSum[day] ?? 0) + diary.mood;
      moodCount[day] = (moodCount[day] ?? 0) + 1;
    }

    wordCount.forEach((day, words) {
      final blocks = blockCount[day] ?? 0;
      final mood = moodCount[day] == null || moodCount[day] == 0
          ? 0.5
          : (moodSum[day]! / moodCount[day]!).clamp(0.0, 1.0);
      final score =
          (words / maxWordsPerDay).clamp(0.0, 1.0) * 0.5 +
          (blocks / maxBlocksPerDay).clamp(0.0, 1.0) * 0.3 +
          mood * 0.2;
      raw[day] = score;
    });

    if (raw.isEmpty) return {};
    final maxScore = raw.values.reduce((a, b) => a > b ? a : b);
    if (maxScore <= 0) return raw.map((k, v) => MapEntry(k, 0.0));
    return raw.map((k, v) => MapEntry(k, (v / maxScore).clamp(0.0, 1.0)));
  }
}
