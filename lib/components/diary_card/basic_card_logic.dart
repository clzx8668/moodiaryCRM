import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/diary_tab_view/diary_tab_view_logic.dart';
import 'package:moodiary/pages/diary_details/diary_details_logic.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/router/app_routes.dart';

mixin BasicCardLogic {
  Future<void> toDiary(Diary diary) async {
    HapticFeedback.mediumImpact();
    Bind.lazyPut(() => DiaryDetailsLogic(), tag: diary.id);
    final res = await Get.toNamed(
      AppRoutes.diaryPage,
      arguments: [diary.clone(), true],
    );
    if (res == 'delete') {
      //如果分类为空，删除主页即可，如果分类不为空，双删除
      if (diary.categoryId != null &&
          Bind.isRegistered<DiaryTabViewLogic>(tag: diary.categoryId)) {
        Bind.find<DiaryTabViewLogic>(
          tag: diary.categoryId,
        ).state.diaryList.removeWhere((e) => e.id == diary.id);
        Bind.find<DiaryTabViewLogic>(tag: diary.categoryId).update();
      }
      Bind.find<DiaryTabViewLogic>(
        tag: 'default',
      ).state.diaryList.removeWhere((e) => e.id == diary.id);
      Bind.find<DiaryTabViewLogic>(tag: 'default').update();
    } else {
      final newDiary = await IsarUtil.getDiaryById(diary.id);
      if (newDiary == null) {
        // 日记已不存在（可能被删除/重置），仅从列表移除，避免空指针崩溃
        _removeDiaryFromLists(diary);
        return;
      }
      if (_sameDiary(diary, newDiary)) {
        return;
      }
      final newCategoryId = newDiary.categoryId;
      final oldCategoryId = diary.categoryId;
      //如果修改了但是没有修改分类，就替换掉原来的
      if (oldCategoryId == newCategoryId) {
        //替换掉全部分类中的
        final oldIndex = Bind.find<DiaryTabViewLogic>(
          tag: 'default',
        ).state.diaryList.indexWhere((e) => e.id == newDiary.id);
        Bind.find<DiaryTabViewLogic>(
          tag: 'default',
        ).state.diaryList.replaceRange(oldIndex, oldIndex + 1, [newDiary]);
        Bind.find<DiaryTabViewLogic>(tag: 'default').update();
        //如果注册了控制器
        if (newDiary.categoryId != null &&
            Bind.isRegistered<DiaryTabViewLogic>(tag: newDiary.categoryId)) {
          final oldIndex = Bind.find<DiaryTabViewLogic>(
            tag: newDiary.categoryId,
          ).state.diaryList.indexWhere((e) => e.id == newDiary.id);
          Bind.find<DiaryTabViewLogic>(
            tag: newDiary.categoryId,
          ).state.diaryList.replaceRange(oldIndex, oldIndex + 1, [newDiary]);
          Bind.find<DiaryTabViewLogic>(tag: newDiary.categoryId).update();
        }
        //await Bind.find<DiaryLogic>().updateDiary(oldCategoryId);
      } else {
        //如果修改了分类
        //再去新的分类
        await Bind.find<DiaryLogic>().updateDiary(newCategoryId);
        //先改旧分类
        await Bind.find<DiaryLogic>().updateDiary(oldCategoryId, jump: false);
      }
    }
  }

  bool _sameDiary(Diary a, Diary b) =>
      a.id == b.id &&
      a.title == b.title &&
      a.categoryId == b.categoryId &&
      a.contentText == b.contentText;

  void _removeDiaryFromLists(Diary diary) {
    try {
      if (diary.categoryId != null &&
          Bind.isRegistered<DiaryTabViewLogic>(tag: diary.categoryId)) {
        Bind.find<DiaryTabViewLogic>(
          tag: diary.categoryId,
        ).state.diaryList.removeWhere((e) => e.id == diary.id);
        Bind.find<DiaryTabViewLogic>(tag: diary.categoryId).update();
      }
      if (Bind.isRegistered<DiaryTabViewLogic>(tag: 'default')) {
        Bind.find<DiaryTabViewLogic>(
          tag: 'default',
        ).state.diaryList.removeWhere((e) => e.id == diary.id);
        Bind.find<DiaryTabViewLogic>(tag: 'default').update();
      }
    } catch (_) {
      // 列表可能未注册，忽略
    }
  }

  Future<void> toDiaryInCalendar(Diary diary) async {
    await HapticFeedback.mediumImpact();
    Bind.lazyPut(() => DiaryDetailsLogic(), tag: diary.id);
    await Get.toNamed(AppRoutes.diaryPage, arguments: [diary.clone(), false]);
  }

  int getMaxLines(String context) {
    return switch (context.length) {
      >= 20 && < 30 => 2,
      >= 30 && < 40 => 3,
      >= 40 => 4,
      _ => 1,
    };
  }
}
