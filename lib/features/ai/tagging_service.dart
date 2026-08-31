import 'dart:convert';

import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';

/// AI 自动标签 / 自动分类 / 自动摘要服务（M1，保存后异步、非流式）。
///
/// 由 [AiTaskQueueWorker] 驱动；开关见设置页「AI 处理设置」：
/// - `aiAutoTag`（默认开）：从已有标签匹配 1-3 个，可新建 1 个；
/// - `aiAutoClassify`（默认开）：匹配/新建分类；
/// - `aiAutoSummary`（默认关）：生成一句中文摘要写入 `Diary.summary`。
class TaggingService {
  static bool get _autoTag => PrefUtil.getValue<bool>('aiAutoTag') ?? true;

  static bool get _autoClassify =>
      PrefUtil.getValue<bool>('aiAutoClassify') ?? true;

  static bool get _autoSummary =>
      PrefUtil.getValue<bool>('aiAutoSummary') ?? false;

  /// 对一篇日记执行自动标签 + 自动分类 + 自动摘要（按开关）。异常向上抛给队列重试。
  static Future<void> processAutoTag({required String diaryId}) async {
    if (!_autoTag && !_autoClassify && !_autoSummary) return;
    final diary = await IsarUtil.getDiaryById(diaryId);
    if (diary == null) return;

    final provider = await AiProviderFactory.load();
    if (!provider.isConfigured) {
      throw StateError('AI 未配置：请先在设置中填写 API Key');
    }

    // 已有标签 / 分类（供 AI 匹配）
    final allDiaries = await IsarUtil.getAllDiaries();
    final tagSet = <String>{};
    for (final d in allDiaries) {
      tagSet.addAll(d.tags.where((t) => t.trim().isNotEmpty));
    }
    final categories = await IsarUtil.getAllCategoryAsync();

    var ruleNo = 1;
    final rules = <String>[];
    if (_autoTag) {
      rules.add('$ruleNo. 从已有标签中选 1-3 个');
      ruleNo++;
      rules.add('$ruleNo. 无合适标签时可新建 1 个，格式 [新:标签名]');
      ruleNo++;
    }
    if (_autoClassify) {
      rules.add(
        '$ruleNo. 从已有分类中选 1 个（都不合适则返回空字符串表示不设置）',
      );
      ruleNo++;
    }
    if (_autoSummary) {
      rules.add('$ruleNo. 用一句中文概括笔记核心要点，不超过 30 字');
      ruleNo++;
    }
    rules.add('$ruleNo. 只返回 JSON，不要多余文字');
    final prompt = '''
角色：笔记分类助手
任务：为笔记添加标签和分类${_autoSummary ? '并生成摘要' : ''}

已有标签（共 ${tagSet.length} 个）：
${tagSet.join('、')}

已有分类：
${categories.map((c) => c.categoryName).join('、')}

规则：
${rules.join('\n')}

笔记内容：
"""${diary.contentText.isEmpty ? diary.content : diary.contentText}"""

返回 JSON：
{"tags":[],"new_tags":[],"category":"","summary":""}
''';

    var acc = '';
    await for (final chunk in provider.streamChat([
      const AiChatMessage(
        role: 'system',
        content: '你只输出合法 JSON，不输出任何其它内容。',
      ),
      AiChatMessage(role: 'user', content: prompt),
    ])) {
      if (chunk.error != null) throw StateError(chunk.error!);
      acc += chunk.text;
    }
    if (acc.trim().isEmpty) {
      throw StateError('AI 未返回有效结果');
    }

    final parsed = _parseJson(acc);
    if (parsed == null) {
      throw StateError('AI 返回内容无法解析为 JSON');
    }

    var changed = false;

    // 标签
    if (_autoTag) {
      final tags = <String>[...diary.tags];
      for (final raw in [..._strList(parsed['tags']), ..._strList(parsed['new_tags'])]) {
        final clean = raw
            .replaceAll(RegExp(r'^\[新:'), '')
            .replaceAll(']', '')
            .replaceAll('#', '')
            .trim();
        if (clean.isNotEmpty && !tags.contains(clean)) {
          tags.add(clean);
          changed = true;
        }
      }
      diary.tags = tags;
    }

    // 分类
    if (_autoClassify) {
      final categoryName = parsed['category']?.toString().trim() ?? '';
      if (categoryName.isNotEmpty) {
        final matched = categories
            .where((c) => c.categoryName == categoryName)
            .toList();
        if (matched.isNotEmpty) {
          if (diary.categoryId != matched.first.id) {
            diary.categoryId = matched.first.id;
            changed = true;
          }
        } else {
          final cat = Category()..categoryName = categoryName;
          await IsarUtil.insertACategory(cat);
          diary.categoryId = cat.id;
          changed = true;
        }
      }
    }

    // 摘要
    if (_autoSummary) {
      final summary = parsed['summary']?.toString().trim() ?? '';
      if (summary.isNotEmpty && diary.summary != summary) {
        diary.summary = summary;
        changed = true;
      }
    }

    if (!changed) return;
    diary.lastModified = DateTime.now();
    await IsarUtil.updateADiary(oldDiary: diary.clone(), newDiary: diary);
  }

  static List<String> _strList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e?.toString() ?? '').toList();
  }

  /// 提取首个 `{...}` JSON 块（容错 AI 输出多余文字/代码围栏）。
  static Map<String, dynamic>? _parseJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final obj = jsonDecode(raw.substring(start, end + 1));
      return obj is Map<String, dynamic> ? obj : null;
    } catch (_) {
      return null;
    }
  }
}
