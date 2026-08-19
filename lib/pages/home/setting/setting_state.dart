import 'package:get/get.dart';
import 'package:moodiary/common/values/language.dart';
import 'package:moodiary/persistence/pref.dart';

class SettingState {
  //当前占用空间
  String dataUsage = '';

  int themeMode = PrefUtil.getValue<int>('themeMode')!;

  int color = PrefUtil.getValue<int>('color')!;

  late RxInt fontTheme;

  bool lock = PrefUtil.getValue<bool>('lock')!;

  bool lockNow = PrefUtil.getValue<bool>('lockNow')!;

  bool local = PrefUtil.getValue<bool>('local')!;

  String customTitle = PrefUtil.getValue<String>('customTitleName')!;

  RxBool backendPrivacy = PrefUtil.getValue<bool>('backendPrivacy')!.obs;

  // 模块开关（架构文档"一、5. 模块化开关"）
  RxBool moduleCrm = (PrefUtil.getValue<bool>('moduleCrm') ?? true).obs;

  RxBool moduleKnowledgeBase =
      (PrefUtil.getValue<bool>('moduleKnowledgeBase') ?? true).obs;

  RxBool moduleCalendar =
      (PrefUtil.getValue<bool>('moduleCalendar') ?? true).obs;

  RxString userKey = ''.obs;

  Rx<Language> language =
      Language.values
          .firstWhere(
            (e) => e.languageCode == PrefUtil.getValue<String>('language')!,
            orElse: () => Language.system,
          )
          .obs;

  SettingState() {
    fontTheme = PrefUtil.getValue<int>('fontTheme')!.obs;
  }
}
