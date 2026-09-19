import 'package:get/get.dart';
import 'package:moodiary/features/smart_canvas/smart_canvas_logic.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/utils/log_util.dart';

/// 后台任务写回笔记内容后的 UI 刷新（批次 96）。
///
/// 反馈背景：语音/图片/链接笔记先落地时正文是空的，后台转写完成后**只有重新
/// 打开详情页**才看得到文字，首页列表一直是空白卡片。
///
/// 处理：写回后主动通知首页列表刷新；若此刻正打开着这条笔记的详情页，
/// 顺手让详情页立即重载块与标题（详情页自身还有 3 秒轮询兜底）。
class NoteRefreshService {
  NoteRefreshService._();

  static Future<void> afterWriteBack(String diaryId) async {
    // 首页列表（含日历）刷新：卡片正文/标题跟着后台结果更新
    try {
      if (Get.isRegistered<HomeLogic>()) {
        await Get.find<HomeLogic>().refreshDiaryLists();
      }
    } catch (e) {
      logger.e('后台写回后刷新首页失败', error: e);
    }
    // 详情页正开着这条笔记：立即刷新，不必等下一次轮询
    try {
      if (Get.isRegistered<SmartCanvasLogic>(tag: diaryId)) {
        final logic = Get.find<SmartCanvasLogic>(tag: diaryId);
        await logic.reloadBlocks();
        await logic.refreshDiary();
      }
    } catch (e) {
      logger.e('后台写回后刷新详情页失败', error: e);
    }
  }
}
