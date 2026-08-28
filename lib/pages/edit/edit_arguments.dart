import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/diary_type.dart';

/// 编辑页路由参数（统一入口：新建 / 整篇编辑 / 子笔记编辑 / 追加 / 笔记整合）。
///
/// 全局只保留 [EditPage]（功能完整 Markdown 编辑器）这一个日记编辑器，
/// 所有入口都通过本载荷进入：
/// - 新建：`type` + 可选 `categoryId`；
/// - 整篇编辑：`diary`；
/// - 子笔记编辑：`diary` + `blockId`（非空）；
/// - 追加子笔记：`diary` + `blockId == ''`；
/// - 笔记整合：`diary` + `consolidate: true`（保存后删除子笔记块）。
class EditArguments {
  /// 编辑模式所属日记（整篇 / 子笔记 / 追加 / 整合时必传）
  final Diary? diary;

  /// 子笔记编辑：非空 = 编辑既有 Block；空串 = 追加新 Block；null = 非子笔记模式
  final String? blockId;

  /// 初始正文（子笔记内容 / 整合后的融合内容）；null 时回退 diary.content
  final String? initialContent;

  /// 新建模式类型（null 且 diary 为 null 时默认 markdown）
  final DiaryType? type;

  /// 新建模式默认分类
  final String? categoryId;

  /// 笔记整合：保存后删除该日记下所有子笔记（保留 AI 对话）块
  final bool consolidate;

  const EditArguments({
    this.diary,
    this.blockId,
    this.initialContent,
    this.type,
    this.categoryId,
    this.consolidate = false,
  });
}
