import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/persistence/isar.dart';

/// 跨模块搜索结果条目
class GlobalSearchResult {
  final String type; // diary / block / crm
  final String id;
  final String diaryId; // block 结果所属日记；diary 结果即自身 id
  final String title;
  final String snippet;
  final DateTime time;

  const GlobalSearchResult({
    required this.type,
    required this.id,
    required this.diaryId,
    required this.title,
    required this.snippet,
    required this.time,
  });
}

/// 全局搜索服务（架构文档"一、1. 全局搜索"：跨日记/Block/CRM 客户检索）
class GlobalSearchService {
  /// 跨模块搜索：日记标题/内容、Block 内容、CRM 实体名称
  static Future<List<GlobalSearchResult>> search(String keyword) async {
    final results = <GlobalSearchResult>[];
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return results;

    // 1. 日记（标题 + 纯文本）
    final diaries = await IsarUtil.searchDiariesByText(trimmed);
    results.addAll(
      diaries.map(
        (Diary d) => GlobalSearchResult(
          type: 'diary',
          id: d.id,
          diaryId: d.id,
          title: d.title.isEmpty ? '未命名日记' : d.title,
          snippet: d.contentText.length > 60
              ? d.contentText.substring(0, 60)
              : d.contentText,
          time: d.time,
        ),
      ),
    );

    // 2. Block 内容
    final blocks = await IsarUtil.searchBlocksByContent(trimmed);
    results.addAll(
      blocks.map(
        (Block b) => GlobalSearchResult(
          type: 'block',
          id: b.id,
          diaryId: b.diaryId,
          title: 'Block（${b.blockType.name}）',
          snippet: b.content.length > 60 ? b.content.substring(0, 60) : b.content,
          time: b.updatedAt,
        ),
      ),
    );

    // 3. CRM 缓存实体
    final crm = await IsarUtil.searchCrmByName(trimmed);
    results.addAll(
      crm.map(
        (CrmEntityCache c) => GlobalSearchResult(
          type: 'crm',
          id: c.twentyId,
          diaryId: '',
          title: c.name,
          snippet: '${c.entityType} · ${c.twentyId}',
          time: c.updatedAt,
        ),
      ),
    );

    results.sort((a, b) => b.time.compareTo(a.time));
    return results;
  }
}
