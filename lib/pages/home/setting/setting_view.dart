import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/common/values/language.dart';
import 'package:moodiary/components/base/clipper.dart';
import 'package:moodiary/components/base/sheet.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/base/tile/qr_tile.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/components/color_sheet/color_sheet_view.dart';
import 'package:moodiary/components/dashboard/dashboard_view.dart';
import 'package:moodiary/components/language_dialog/language_dialog_view.dart';
import 'package:moodiary/components/remove_password/remove_password_view.dart';
import 'package:moodiary/components/set_password/set_password_view.dart';
import 'package:moodiary/components/theme_mode_dialog/theme_mode_dialog_view.dart';
import 'package:moodiary/features/ai/ai_settings_page.dart';
import 'package:moodiary/features/ai/legacy/tencent_hunyuan_settings_page.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_page.dart';
import 'package:moodiary/features/ai/digest/digest_scheduler.dart';
import 'package:moodiary/features/thirdparty/third_party_keys_page.dart';
import 'package:moodiary/features/crm/crm_settings_page.dart';
import 'package:moodiary/features/feed/feed_settings_page.dart';
import 'package:moodiary/features/feed/feed_scheduler.dart';
import 'package:moodiary/features/nav/mobile_nav_config.dart';
import 'package:moodiary/features/obsidian/obsidian_settings_page.dart';
import 'package:moodiary/features/reminder/reminder_scheduler.dart';
import 'package:moodiary/features/quick_capture/global_capture.dart';
import 'package:moodiary/features/quick_capture/global_shortcut_service.dart';
import 'package:moodiary/features/quick_capture/shortcut_capture_dialog.dart';
import 'package:moodiary/features/quick_capture/tray_service.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'setting_logic.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  Future<void> _toggleNavItem(int pageIndex, bool on) async {
    final next = List<int>.from(MobileNavConfig.items);
    if (on) {
      if (!next.contains(pageIndex)) next.add(pageIndex);
    } else {
      next.remove(pageIndex);
    }
    if (next.length < MobileNavConfig.minItems) {
      toast.info(message: '至少保留 ${MobileNavConfig.minItems} 个底部按钮');
      return;
    }
    await MobileNavConfig.save(next);
    toast.success(message: '已更新底部导航');
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SettingLogic());
    final state = Bind.find<SettingLogic>().state;

    final size = MediaQuery.sizeOf(context);

    /// 二级小标题（工具区内部再分段的视觉锚点）
    Widget subTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: context.textTheme.labelLarge?.copyWith(
            color: context.theme.colorScheme.primary,
          ),
        ),
      ),
    );

    Widget buildDashboard() {
      return Column(
        children: [
          AdaptiveTitleTile(title: context.l10n.settingDashboard),
          const DashboardComponent(),
        ],
      );
    }

    Widget buildAFeatureButton({
      required Widget icon,
      required String text,
      required Function() onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        child: Card.outlined(
          color: context.theme.colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                icon,
                AdaptiveText(
                  text,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildFeature() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveTitleTile(title: context.l10n.settingFunction),
          GridView(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 100,
              childAspectRatio: 1.0,
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
            ),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              buildAFeatureButton(
                icon: Icon(
                  Icons.category_rounded,
                  color: context.theme.colorScheme.secondary,
                ),
                text: context.l10n.settingFunctionCategoryManage,
                onTap: logic.toCategoryManager,
              ),
              buildAFeatureButton(
                icon: FaIcon(
                  FontAwesomeIcons.squarePollVertical,
                  color: context.theme.colorScheme.secondary,
                ),
                text: context.l10n.settingFunctionAnalysis,
                onTap: logic.toAnalysePage,
              ),
              buildAFeatureButton(
                icon: FaIcon(
                  FontAwesomeIcons.solidMap,
                  color: context.theme.colorScheme.secondary,
                ),
                text: context.l10n.settingFunctionTrailMap,
                onTap: logic.toMap,
              ),
              buildAFeatureButton(
                icon: FaIcon(
                  FontAwesomeIcons.solidCommentDots,
                  color: context.theme.colorScheme.secondary,
                ),
                text: context.l10n.settingFunctionAIAssistant,
                onTap: logic.toAi,
              ),
            ],
          ),
        ],
      );
    }

    Widget buildData() {
      return Column(
        children: [
          const AdaptiveTitleTile(title: '数据与存储'),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: Text(context.l10n.settingRecycle),
                  isFirst: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toRecyclePage();
                  },
                  leading: const Icon(Icons.delete_rounded),
                ),
                AdaptiveListTile(
                  title: Text(context.l10n.settingDataSyncAndBackup),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toBackupAndSyncPage();
                  },
                  leading: const Icon(Icons.sync_rounded),
                ),
                AdaptiveListTile(
                  title: const Text('数据健康度'),
                  subtitle: const Text('统计概览 / 附件清理 / 重建向量索引 / CRM 对账'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toHealthPage();
                  },
                  leading: const Icon(Icons.monitor_heart_rounded),
                ),
                AdaptiveListTile(
                  title: const Text('Obsidian'),
                  subtitle: const Text('配置本地 Vault：文件树 / 双链渲染 / AI 检索'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Get.to(() => const ObsidianSettingsPage());
                  },
                  leading: const Icon(Icons.link_rounded),
                ),
                // CRM 数据入口归到"数据与存储"：它是**本地数据**，
                // 不是 AI 功能；按 CRM 模块开关显隐（不显示时不留空洞）。
                if (state.moduleCrm.value)
                  AdaptiveListTile(
                    title: const Text('本地 CRM 数据'),
                    subtitle: const Text('客户/联系人/机会/合同 · 自定义对象 · 无需联网'),
                    leading: const Icon(Icons.storage_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Get.to(() => const CrmSettingsPage());
                    },
                  ),
                AdaptiveListTile(
                  title: Text(context.l10n.settingClean),
                  leading: const Icon(Icons.cleaning_services_rounded),
                  trailing: GetBuilder<SettingLogic>(
                    id: 'DataUsage',
                    builder: (_) {
                      return Text(
                        state.dataUsage,
                        style: context.textTheme.bodySmall!.copyWith(
                          color: context.theme.colorScheme.primary,
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    logic.deleteCache();
                  },
                ),
                AdaptiveListTile(
                  title: const Text('清理孤立附件'),
                  subtitle: const Text('扫描并删除未被任何记录引用的附件'),
                  leading: const Icon(Icons.attachment_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.cleanOrphanAttachments();
                  },
                ),
                AdaptiveListTile(
                  title: const Text('同步日志'),
                  subtitle: const Text('查看最近 500 条同步记录（可筛选/清空）'),
                  leading: const Icon(Icons.receipt_long_rounded),
                  isLast: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toSyncLogPage();
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildCrm() {
      // 「本地 CRM 数据」入口已归到「数据与存储」分区（按模块开关显隐），
      // 这里只保留 CRM 模块的开关本身，避免同一个入口出现两次。
      return Column(
        children: [
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AdaptiveSwitchListTile(
                  value: state.moduleKnowledgeBase.value,
                  onChanged: logic.changeModuleCrm,
                  title: const Text('CRM 模块'),
                  subtitle: const Text('客户/联系人/机会/合同 · 本地存储，无需联网'),
                  secondary: const Icon(Icons.business_rounded),
                  isFirst: true,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildAi() {
      return Column(
        children: [
          const AdaptiveTitleTile(title: 'AI 与笔记处理'),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: const Text('AI 设置'),
                  subtitle: const Text('API Key / 模型配置与连接测试'),
                  leading: const Icon(Icons.auto_awesome_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isFirst: true,
                  onTap: () {
                    Get.to(() => const AiSettingsPage());
                  },
                ),
                const Divider(height: 1),
                const AiTaskQueueTile(),
                const Divider(height: 1),
                GetBuilder<SettingLogic>(
                  id: 'AiProcess',
                  builder: (_) => Column(
                    children: [
                      AdaptiveSwitchListTile(
                        value: state.aiAutoTag.value,
                        onChanged: logic.changeAiAutoTag,
                        title: const Text('AI 自动标签'),
                        subtitle: const Text('保存后异步为笔记匹配/新建标签'),
                        secondary: const Icon(Icons.label_outline_rounded),
                      ),
                      AdaptiveSwitchListTile(
                        value: state.aiAutoClassify.value,
                        onChanged: logic.changeAiAutoClassify,
                        title: const Text('AI 自动分类'),
                        subtitle: const Text('保存后异步匹配/新建分类'),
                        secondary: const Icon(Icons.folder_outlined),
                      ),
                      AdaptiveSwitchListTile(
                        value: state.aiAutoSummary.value,
                        onChanged: logic.changeAiAutoSummary,
                        title: const Text('AI 自动摘要'),
                        subtitle: const Text('为笔记生成一句话摘要（默认关）'),
                        secondary: const Icon(Icons.summarize_outlined),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildModuleSwitches() {
      return Column(
        children: [
          const AdaptiveTitleTile(title: '功能开关'),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AdaptiveSwitchListTile(
                  value: state.moduleCrm.value,
                  onChanged: logic.changeModuleKnowledgeBase,
                  title: const Text('知识库模块'),
                  subtitle: const Text('关闭后隐藏知识库选择与索引（AI 对话仍可用）'),
                  secondary: const Icon(Icons.menu_book_rounded),
                  isFirst: true,
                ),
                AdaptiveSwitchListTile(
                  value: state.moduleCalendar.value,
                  onChanged: logic.changeModuleCalendar,
                  title: const Text('日历模块'),
                  subtitle: const Text('日历热力图与待办聚合'),
                  secondary: const Icon(Icons.calendar_month_rounded),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildDisplay() {
      return Column(
        children: [
          const AdaptiveTitleTile(title: '外观与交互'),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: Text(context.l10n.settingDiary),
                  leading: const Icon(Icons.article_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isFirst: true,
                  onTap: () {
                    logic.toDiarySettingPage();
                  },
                ),
                AdaptiveListTile(
                  title: Text(context.l10n.settingThemeMode),
                  leading: const Icon(Icons.invert_colors_rounded),
                  trailing: Text(
                    switch (state.themeMode) {
                      0 => context.l10n.themeModeSystem,
                      1 => context.l10n.themeModeLight,
                      2 => context.l10n.themeModeDark,
                      int() => throw UnimplementedError(),
                    },
                    style: context.textTheme.bodySmall!.copyWith(
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return const ThemeModeDialogComponent();
                      },
                    );
                  },
                ),
                AdaptiveListTile(
                  title: Text(context.l10n.settingColor),
                  leading: const Icon(Icons.color_lens_rounded),
                  trailing: Text(
                    AppColor.colorName(state.color, context),
                    style: context.textTheme.bodySmall!.copyWith(
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () {
                    showFloatingModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return const ColorSheetComponent();
                      },
                    );
                  },
                ),
                AdaptiveListTile(
                  title: Text(context.l10n.settingFontStyle),
                  leading: const Icon(Icons.format_size_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    logic.toFontSizePage();
                  },
                ),
                AdaptiveListTile(
                  title: Text(context.l10n.settingHomepageName),
                  leading: const Icon(Icons.drive_file_rename_outline_rounded),
                  isLast: true,
                  trailing: GetBuilder<SettingLogic>(
                    id: 'CustomTitle',
                    builder: (_) {
                      return Text(
                        state.customTitle,
                        style: context.textTheme.bodySmall!.copyWith(
                          color: context.theme.colorScheme.primary,
                        ),
                      );
                    },
                  ),
                  onTap: () async {
                    final res = await showTextInputDialog(
                      context: context,
                      textFields: [
                        DialogTextField(initialText: state.customTitle),
                      ],
                      title: context.l10n.settingHomepageName,
                    );
                    if (res != null) {
                      logic.setCustomTitle(title: res.first);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildPrivacy() {
      return Column(
        children: [
          const AdaptiveTitleTile(title: '隐私与安全'),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                GetBuilder<SettingLogic>(
                  id: 'Lock',
                  builder: (_) {
                    return AdaptiveListTile(
                      trailing: Text(
                        state.lock
                            ? context.l10n.settingLockOpen
                            : context.l10n.settingLockNotOpen,
                        style: context.textTheme.bodySmall!.copyWith(
                          color: context.theme.colorScheme.primary,
                        ),
                      ),
                      isFirst: true,
                      onTap: () async {
                        final res = await showOkCancelAlertDialog(
                          context: context,
                          title: context.l10n.settingLock,
                          message:
                              state.lock
                                  ? context.l10n.settingLockResetLock
                                  : context.l10n.settingLockChooseLockType,
                          okLabel:
                              state.lock
                                  ? context.l10n.settingLockClose
                                  : context.l10n.settingLockTypeNumber,
                        );
                        if (res == OkCancelResult.ok && context.mounted) {
                          showFloatingModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return state.lock
                                  ? const RemovePasswordComponent()
                                  : const SetPasswordComponent();
                            },
                          );
                        }
                      },
                      title: Text(context.l10n.settingLock),
                      leading: const Icon(Icons.lock_rounded),
                    );
                  },
                ),
                Obx(() {
                  return QrInputTile(
                    title: context.l10n.settingUserKey,
                    value: state.userKey.value,
                    prefix: 'userKey',
                    onValue: (value) async {
                      final res = await logic.setUserKey(key: value);
                      if (res) {
                        toast.success();
                      } else {
                        toast.error();
                      }
                    },
                    onInput: () async {
                      if (state.userKey.value.isNotNullOrBlank) {
                        final res = await showOkCancelAlertDialog(
                          context: context,
                          title: context.l10n.settingUserKeyReset,
                          message: context.l10n.settingUserKeyResetDes,
                        );
                        if (res == OkCancelResult.ok) {
                          final res_ = await logic.removeUserKey();
                          if (res_) {
                            toast.success();
                          } else {
                            toast.error();
                          }
                        }
                        return;
                      } else {
                        final res = await showTextInputDialog(
                          title: context.l10n.settingUserKeySet,
                          message: context.l10n.settingUserKeySetDes,
                          context: context,
                          textFields: [const DialogTextField()],
                        );
                        if (res != null) {
                          final res_ = await logic.setUserKey(key: res.first);
                          if (res_) {
                            toast.success();
                          } else {
                            toast.error();
                          }
                        }
                      }
                    },
                    leading: const Icon(Icons.key_rounded),
                  );
                }),
                GetBuilder<SettingLogic>(
                  id: 'Lock',
                  builder: (_) {
                    return AdaptiveSwitchListTile(
                      value: state.lockNow,
                      onChanged:
                          state.lock
                              ? (value) {
                                logic.lockNow(value);
                              }
                              : null,
                      title: Text(context.l10n.settingLockNow),
                      subtitle: context.l10n.settingLockNowDes,
                      secondary: const Icon(Icons.lock_clock_rounded),
                    );
                  },
                ),
                Obx(() {
                  return AdaptiveSwitchListTile(
                    value: state.backendPrivacy.value,
                    onChanged: logic.changeBackendPrivacy,
                    title: context.l10n.settingBackendPrivacyProtection,
                    subtitle: context.l10n.settingBackendPrivacyProtectionDes,
                    secondary: const Icon(Icons.remove_red_eye_rounded),
                    isLast: true,
                  );
                }),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildMobileNav() {
      return Column(
        children: [
          const AdaptiveTitleTile(title: '底部导航'),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Obx(() {
              final current = MobileNavConfig.items;
              const all = MobileNavConfig.all;
              return Column(
                children: [
                  for (var i = 0; i < all.length; i++)
                    AdaptiveSwitchListTile(
                      value: current.contains(all[i].pageIndex),
                      onChanged: (v) => _toggleNavItem(all[i].pageIndex, v),
                      title: Text(all[i].label),
                      secondary: Icon(all[i].icon),
                      isFirst: i == 0,
                      isLast: i == all.length - 1,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      '默认：日记 / 日历 / AI / 设置；至少保留 ${MobileNavConfig.minItems} 个',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      );
    }

    /// 工具区（批次 114 收敛）：**只留设置项**，动作类入口已移除。
    ///
    /// - 删掉「每日回望 / 每周回望」手动入口：和「自动生成回望」重叠，
    ///   而且它们是"执行动作"不是"设置"（用户确认删除，保留自动回望）；
    /// - 订阅与回望的开关**紧挨着它们各自的入口**排在一起，
    ///   不再是"入口在上、开关散落在下面"的分裂状态。
    Widget buildTools() {
      return Column(
        children: [
          const AdaptiveTitleTile(title: '工具'),
          // 子段①：内容源（RSS 订阅与自动刷新、自动回望都归这里）
          subTitle('内容源'),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: const Text('内容源（RSS）'),
                  subtitle: const Text('订阅公开 RSS/Atom，增量入库为笔记'),
                  leading: const Icon(Icons.rss_feed_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isFirst: true,
                  onTap: () => Get.to(() => const FeedSettingsPage()),
                ),
                const _FeedAutoSwitchTile(),
                const _DigestAutoSwitchTile(isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 子段②：桌面与提醒（提醒、快捷键、托盘，多为桌面端特性）
          subTitle('桌面与提醒'),
          const Card.filled(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _ReminderSwitchTile(),
                _GlobalShortcutSwitchTile(),
                _ShortcutComboTile(),
                _CloseToTraySwitchTile(isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 子段③：入口类（音频/服务凭据）
          subTitle('其他'),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: const Text('语音记录'),
                  subtitle: const Text('录音转写 / 去口语化'),
                  leading: const Icon(Icons.mic_none_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isFirst: true,
                  onTap: () => Get.toNamed(AppRoutes.voiceRecordPage),
                ),
                AdaptiveListTile(
                  title: const Text('第三方服务'),
                  subtitle: const Text('和风天气 / 天地图的 Key（天气与足迹地图）'),
                  leading: const Icon(Icons.vpn_key_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Get.to(() => const ThirdPartyKeysPage()),
                ),
                AdaptiveListTile(
                  title: const Text('智能助手（旧版）凭据'),
                  subtitle: const Text('腾讯云混元：仅旧版助手与分析统计需要'),
                  leading: const Icon(Icons.cloud_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isLast: true,
                  onTap: () =>
                      Get.to(() => const TencentHunyuanSettingsPage()),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildMore() {
      return Column(
        children: [
          AdaptiveTitleTile(title: context.l10n.settingMore),
          Card.filled(
            color: context.theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AdaptiveListTile(
                  title: Text(context.l10n.settingAbout),
                  leading: const Icon(Icons.info_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isFirst: true,
                  onTap: () {
                    logic.toAboutPage();
                  },
                ),
                AdaptiveListTile(
                  title: Text(context.l10n.settingLanguage),
                  leading: const Icon(Icons.language_rounded),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return const LanguageDialogComponent();
                      },
                    );
                  },
                  trailing: Obx(() {
                    return Text(
                      state.language.value.l10nText(context),
                      style: context.textTheme.bodySmall!.copyWith(
                        color: context.theme.colorScheme.primary,
                      ),
                    );
                  }),
                ),
                AdaptiveListTile(
                  title: Text(context.l10n.settingLab),
                  leading: const Icon(Icons.science_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  isLast: true,
                  onTap: () {
                    logic.toLaboratoryPage();
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GetBuilder<SettingLogic>(
      assignId: true,
      builder: (_) {
        return PageClipper(
          child: ListView(
            cacheExtent: size.height * 2,
            children: [
              buildDashboard(),
              buildFeature(),
              // 分区顺序（批次 113 整理）：
              // ① 日常四入口 ② 数据与存储 ③ AI 与笔记处理 ④ 功能开关
              // ⑤ 外观与交互 ⑥ 底部导航 ⑦ 工具 ⑧ 隐私与安全 ⑨ 关于
              GetBuilder<SettingLogic>(
                id: 'ModuleSwitch',
                builder: (_) => buildData(),
              ),
              buildAi(),
              GetBuilder<SettingLogic>(
                id: 'ModuleSwitch',
                builder: (_) => Column(
                  children: [buildModuleSwitches(), buildCrm()],
                ),
              ),
              buildDisplay(),
              buildMobileNav(),
              buildTools(),
              buildPrivacy(),
              buildMore(),
            ],
          ),
        );
      },
    );
  }
}

/// 自动回望开关（每天 21:00 后自动生成每日回望；周一另生成每周回望）。
class _DigestAutoSwitchTile extends StatefulWidget {
  const _DigestAutoSwitchTile({this.isLast = false});

  final bool isLast;

  @override
  State<_DigestAutoSwitchTile> createState() => _DigestAutoSwitchTileState();
}

class _DigestAutoSwitchTileState extends State<_DigestAutoSwitchTile> {
  bool _value = false;

  @override
  void initState() {
    super.initState();
    _value = PrefUtil.getValue<bool>(DigestScheduler.prefKey) ?? false;
  }

  Future<void> _toggle(bool value) async {
    setState(() => _value = value);
    await PrefUtil.setValue(DigestScheduler.prefKey, value);
    toast.success(
      message: value ? '已开启自动回望（每天 21:00 后）' : '已关闭自动回望',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSwitchListTile(
      value: _value,
      onChanged: _toggle,
      title: const Text('自动生成回望'),
      subtitle: const Text('每日 21:00 后自动生成；周一含周报'),
      secondary: const Icon(Icons.auto_mode_rounded),
      isLast: widget.isLast,
    );
  }
}

/// 订阅自动刷新开关（默认关；启动/回前台对到期源低频刷新，间隔 6 小时）。
class _FeedAutoSwitchTile extends StatefulWidget {
  const _FeedAutoSwitchTile();

  @override
  State<_FeedAutoSwitchTile> createState() => _FeedAutoSwitchTileState();
}

class _FeedAutoSwitchTileState extends State<_FeedAutoSwitchTile> {
  bool _value = false;

  @override
  void initState() {
    super.initState();
    _value = PrefUtil.getValue<bool>(FeedScheduler.prefKey) ?? false;
  }

  Future<void> _toggle(bool value) async {
    setState(() => _value = value);
    await PrefUtil.setValue(FeedScheduler.prefKey, value);
    toast.success(
      message: value ? '已开启订阅自动刷新（每 6 小时）' : '已关闭订阅自动刷新',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSwitchListTile(
      value: _value,
      onChanged: _toggle,
      title: const Text('自动刷新订阅'),
      subtitle: const Text('启动/回前台时刷新到期源（间隔 6 小时）'),
      secondary: const Icon(Icons.sync_rounded),
    );
  }
}

/// 到点提醒开关（默认开；应用运行时轮询日程/CRM 提醒，到点浮出提醒卡）。
class _ReminderSwitchTile extends StatefulWidget {
  const _ReminderSwitchTile();

  @override
  State<_ReminderSwitchTile> createState() => _ReminderSwitchTileState();
}

class _ReminderSwitchTileState extends State<_ReminderSwitchTile> {
  bool _value = true;

  @override
  void initState() {
    super.initState();
    _value = ReminderScheduler.enabled;
  }

  Future<void> _toggle(bool value) async {
    setState(() => _value = value);
    await PrefUtil.setValue(ReminderScheduler.prefKey, value);
    toast.success(
      message: value ? '已开启到点提醒（应用运行时生效）' : '已关闭到点提醒',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSwitchListTile(
      value: _value,
      onChanged: _toggle,
      title: const Text('到点提醒'),
      subtitle: const Text('日程/CRM 提醒到点浮出提醒卡（需应用运行）'),
      secondary: const Icon(Icons.alarm_rounded),
    );
  }
}

/// 桌面全局快捷键开关（默认开；Ctrl+Alt+M 从任意程序唤起快速收集）。
class _GlobalShortcutSwitchTile extends StatefulWidget {
  const _GlobalShortcutSwitchTile();

  @override
  State<_GlobalShortcutSwitchTile> createState() =>
      _GlobalShortcutSwitchTileState();
}

class _GlobalShortcutSwitchTileState
    extends State<_GlobalShortcutSwitchTile> {
  bool _value = true;

  @override
  void initState() {
    super.initState();
    _value = GlobalShortcutService.enabled;
  }

  Future<void> _toggle(bool value) async {
    setState(() => _value = value);
    await GlobalShortcutService.setEnabled(value);
    toast.success(
      message: value
          ? '已开启全局快捷键（$globalShortcutLabel 唤起快速收集）'
          : '已关闭全局快捷键（不再占用系统按键）',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSwitchListTile(
      value: _value,
      onChanged: GlobalShortcutService.supported ? _toggle : null,
      title: const Text('全局快捷键速记'),
      subtitle: Text(
        GlobalShortcutService.supported
            ? '$globalShortcutLabel 从任意程序唤起快速收集'
            : '仅桌面端可用',
      ),
      secondary: const Icon(Icons.keyboard_alt_outlined),
    );
  }
}

/// 关闭窗口到托盘开关（默认开；关闭后点关闭按钮直接退出）。
class _CloseToTraySwitchTile extends StatefulWidget {
  const _CloseToTraySwitchTile({this.isLast = false});

  final bool isLast;

  @override
  State<_CloseToTraySwitchTile> createState() => _CloseToTraySwitchTileState();
}

class _CloseToTraySwitchTileState extends State<_CloseToTraySwitchTile> {
  bool _value = true;

  @override
  void initState() {
    super.initState();
    _value = TrayService.enabled;
  }

  Future<void> _toggle(bool value) async {
    setState(() => _value = value);
    await TrayService.setEnabled(value);
    toast.success(
      message: value
          ? '已开启：关闭窗口时最小化到托盘（托盘菜单可退出）'
          : '已关闭：关闭窗口将直接退出应用',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSwitchListTile(
      value: _value,
      onChanged: TrayService.supported ? _toggle : null,
      title: const Text('关闭到托盘'),
      subtitle: Text(
        TrayService.supported
            ? '关闭窗口时最小化到托盘；托盘菜单：打开 / 快速收集 / 退出'
            : '仅桌面端可用',
      ),
      secondary: const Icon(Icons.desktop_windows_outlined),
      isLast: widget.isLast,
    );
  }
}

/// 全局快捷键组合键设置（点按录制；冲突时回滚并提示）。
class _ShortcutComboTile extends StatefulWidget {
  const _ShortcutComboTile();

  @override
  State<_ShortcutComboTile> createState() => _ShortcutComboTileState();
}

class _ShortcutComboTileState extends State<_ShortcutComboTile> {
  @override
  Widget build(BuildContext context) {
    final label = GlobalShortcutService.spec.label;
    return AdaptiveListTile(
      title: const Text('快捷键组合'),
      subtitle: Text(
        GlobalShortcutService.supported
            ? '当前：$label（点按重新录制）'
            : '仅桌面端可用',
      ),
      leading: const Icon(Icons.keyboard_rounded),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: GlobalShortcutService.supported ? _record : null,
    );
  }

  Future<void> _record() async {
    final spec = await ShortcutCaptureDialog.show(context);
    if (spec == null || !mounted) return;
    final ok = await GlobalShortcutService.setSpec(spec);
    if (!mounted) return;
    if (ok) {
      toast.success(message: '已设为 ${spec.label}');
    }
    setState(() {});
  }
}
