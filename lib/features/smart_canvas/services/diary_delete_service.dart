import 'package:moodiary/persistence/isar.dart';

/// 删除一条记录的统一入口（详情页菜单 / 首页多选都走这里）。
///
/// 语义：**移入回收站**（`show=false`）而不是物理删除——用户可在
/// 「设置 → 回收站」恢复或彻底删除；同时软删该记录下的子笔记块，
/// 避免卡片流/检索里残留孤儿块。媒体文件保留（恢复时仍可用）。
class DiaryDeleteService {
  DiaryDeleteService._();

  static Future<void> moveToRecycle({
    required String diaryId,
    required int isarId,
  }) async {
    // 先让日记本身离开列表，再软删子块：中途失败也不会留下"看得见的空记录"
    await IsarUtil.moveDiaryToRecycle(isarId);
    await IsarUtil.softDeleteBlocksByDiary(diaryId);
  }
}
