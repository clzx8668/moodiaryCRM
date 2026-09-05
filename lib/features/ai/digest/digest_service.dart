import 'dart:async';

import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/digest/digest_prompts.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 日报/周报：跨记录周期回望，生成可归档的回望条目。
class DigestService {
  DigestService._();

  /// 周期标签（如「09-06」「2026年第36周」）。
  static String label(DigestPeriod period, DateTime now) {
    if (period == DigestPeriod.daily) {
      return '${now.month}-${now.day}';
    }
    final start = now.subtract(Duration(days: now.weekday - 1));
    return '${start.year} 第${_weekOfYear(start)}周';
  }

  static int _weekOfYear(DateTime d) {
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays;
    return (dayOfYear / 7).floor() + 1;
  }

  /// 周期起止（含边界）：每日=当天；每周=周一..周日。
  static ({DateTime start, DateTime end}) range(
    DigestPeriod period,
    DateTime now,
  ) {
    final day = DateTime(now.year, now.month, now.day);
    if (period == DigestPeriod.daily) {
      return (start: day, end: day.add(const Duration(days: 1)));
    }
    final start = day.subtract(Duration(days: day.weekday - 1));
    return (start: start, end: start.add(const Duration(days: 7)));
  }

  /// 收集周期内记录摘要。
  static Future<List<DigestItem>> collect(DigestPeriod period) async {
    final now = DateTime.now();
    final r = range(period, now);
    final all = await IsarUtil.getAllDiaries();
    final items = <DigestItem>[];
    for (final d in all) {
      final t = d.time;
      if (t.isBefore(r.start) || !t.isBefore(r.end)) continue;
      if (!d.show) continue;
      items.add(
        DigestItem(
          title: d.title.isEmpty ? '速记' : d.title,
          summary: d.summary.trim(),
          tags: d.tags,
        ),
      );
    }
    return items;
  }

  /// 生成回望文本；失败返回 null（UI 提示）。
  static Future<String?> generate(DigestPeriod period) async {
    final provider = await AiProviderFactory.loadLight();
    if (!provider.isConfigured) return null;
    final items = await collect(period);
    final dateLabel = label(period, DateTime.now());
    final completion = await provider.completeChat([
      const AiChatMessage(role: 'system', content: DigestPrompts.system),
      AiChatMessage(
        role: 'user',
        content: DigestPrompts.build(period, dateLabel, items),
      ),
    ]);
    final text = completion.content.trim();
    return text.isEmpty ? null : text;
  }

  /// 生成并落库为一条「周期回望」笔记（原样保留，供归档）。
  static Future<Diary?> generateAndSave(DigestPeriod period) async {
    final text = await generate(period);
    if (text == null) return null;
    final now = DateTime.now();
    final title = period == DigestPeriod.daily
        ? '每日回望 ${label(period, now)}'
        : '每周回望 ${label(period, now)}';
    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = title
      ..contentText = text
      ..content = text
      ..type = DiaryType.markdown.value
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5;
    await IsarUtil.insertADiary(diary);
    final block = Block()
      ..diaryId = diary.id
      ..blockType = BlockType.text
      ..content = text
      ..sortOrder = 0
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceInitial,
        captureType: 'digest',
      );
    await IsarUtil.insertBlock(block);
    return diary;
  }
}
