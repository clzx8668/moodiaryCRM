import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/dashboard/dashboard_logic.dart';
import 'package:moodiary/features/attachments/attachment_manager.dart';
import 'package:moodiary/features/sync_log/sync_log_page.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/persistence/secure_storage.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'setting_state.dart';

class SettingLogic extends GetxController {
  final SettingState state = SettingState();
  late final homeLogic = Bind.find<HomeLogic>();

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    unawaited(getDataUsage());
    unawaited(checkUserKey());
    super.onReady();
  }

  Future<void> checkUserKey() async {
    state.userKey.value = (await SecureStorageUtil.getValue('userKey')) ?? '';
  }

  //获取当前占用储存空间
  Future<void> getDataUsage() async {
    final sizeMap = await FileUtil.countSize();
    state.dataUsage = '${sizeMap['size']} ${sizeMap['unit']}';
    update(['DataUsage']);
    if (sizeMap['bytes'] > (1024 * 1024 * 100)) {
      await FileUtil.clearCache();
      await getDataUsage();
      toast.info(message: '缓存已自动清理');
    }
  }

  Future<void> deleteCache() async {
    await FileUtil.clearCache();
    await getDataUsage();
    toast.success(message: '清理成功');
  }

  // 清理孤立附件（数据健康度检查，架构文档"五、设置模块"）
  Future<void> cleanOrphanAttachments() async {
    final count = await AttachmentManager.cleanOrphans();
    toast.success(
      message: count > 0 ? '已清理 $count 个孤立附件' : '无孤立附件',
    );
  }

  void toSyncLogPage() {
    Get.to(() => const SyncLogPage());
  }

  //本地化
  Future<void> local(bool value) async {
    await PrefUtil.setValue<bool>('local', value);
    state.local = value;
    update(['Local']);
  }

  //立即锁定
  Future<void> lockNow(bool value) async {
    await PrefUtil.setValue<bool>('lockNow', value);
    state.lockNow = value;
    update(['Lock']);
  }

  void toAnalysePage() {
    HapticFeedback.selectionClick();
    Get.toNamed(AppRoutes.analysePage);
  }

  Future<void> toMap() async {
    if (PrefUtil.getValue<String>('tiandituKey') != null) {
      HapticFeedback.selectionClick();
      Get.toNamed(AppRoutes.mapPage);
    } else {
      toast.info(message: '请先配置Key');
    }
  }

  Future<void> toAi() async {
    if (PrefUtil.getValue<String>('tencentId') != null &&
        PrefUtil.getValue<String>('tencentKey') != null) {
      HapticFeedback.selectionClick();
      Get.toNamed(AppRoutes.assistantPage);
    } else {
      toast.info(message: '请先配置Key');
    }
  }

  Future<void> toCategoryManager() async {
    HapticFeedback.selectionClick();
    await Get.toNamed(AppRoutes.categoryManagerPage);
    Bind.find<DashboardLogic>().getCategoryCount();
  }

  Future<void> changeBackendPrivacy(bool value) async {
    await PrefUtil.setValue<bool>('backendPrivacy', value);
    state.backendPrivacy.value = value;
  }

  // 模块开关
  Future<void> changeModuleCrm(bool value) async {
    await PrefUtil.setValue<bool>('moduleCrm', value);
    state.moduleCrm.value = value;
    update(['ModuleSwitch']);
  }

  Future<void> changeModuleKnowledgeBase(bool value) async {
    await PrefUtil.setValue<bool>('moduleKnowledgeBase', value);
    state.moduleKnowledgeBase.value = value;
    update(['ModuleSwitch']);
  }

  Future<void> changeModuleCalendar(bool value) async {
    await PrefUtil.setValue<bool>('moduleCalendar', value);
    state.moduleCalendar.value = value;
    update(['ModuleSwitch']);
  }

  // AI 处理设置
  Future<void> changeAiAutoTag(bool value) async {
    await PrefUtil.setValue<bool>('aiAutoTag', value);
    state.aiAutoTag.value = value;
    update(['AiProcess']);
  }

  Future<void> changeAiAutoClassify(bool value) async {
    await PrefUtil.setValue<bool>('aiAutoClassify', value);
    state.aiAutoClassify.value = value;
    update(['AiProcess']);
  }

  Future<void> changeAiAutoSummary(bool value) async {
    await PrefUtil.setValue<bool>('aiAutoSummary', value);
    state.aiAutoSummary.value = value;
    update(['AiProcess']);
  }

  //进入回收站
  void toRecyclePage() {
    Get.toNamed(AppRoutes.recyclePage);
  }

  //进入字体大小设置页
  void toFontSizePage() {
    Get.toNamed(AppRoutes.fontPage);
  }

  void toLaboratoryPage() {
    Get.toNamed(AppRoutes.laboratoryPage);
  }

  void toAboutPage() {
    Get.toNamed(AppRoutes.aboutPage);
  }

  void toDiarySettingPage() {
    Get.toNamed(AppRoutes.diarySettingPage);
  }

  void toBackupAndSyncPage() {
    Get.toNamed(AppRoutes.backupSyncPage);
  }

  void toHealthPage() {
    Get.toNamed(AppRoutes.healthPage);
  }

  Future<void> setCustomTitle({required String title}) async {
    state.customTitle = title.trim();
    update(['CustomTitle']);
    await PrefUtil.setValue<String>('customTitleName', state.customTitle);
    Bind.find<DiaryLogic>().updateTitle();
  }

  Future<bool> setUserKey({required String key}) async {
    try {
      await SecureStorageUtil.setValue('userKey', key);
      state.userKey.value = key;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeUserKey() async {
    try {
      await SecureStorageUtil.remove('userKey');
      state.userKey.value = '';
      return true;
    } catch (e) {
      return false;
    }
  }
}
