import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/components/local_send/local_send_view.dart';
import 'package:moodiary/components/web_dav/web_dav_view.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'backup_sync_logic.dart';

class BackupSyncPage extends StatelessWidget {
  const BackupSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final BackupSyncLogic logic = Get.put(BackupSyncLogic());

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingDataSyncAndBackup),
        leading: const PageBackButton(),
      ),
      body: ListView(
        children: [
          AdaptiveListTile(
            title: Text(context.l10n.settingExport),
            onTap: () async {
              final res = await showOkCancelAlertDialog(
                context: context,
                title: context.l10n.settingExportDialogTitle,
                message: context.l10n.settingExportDialogContent,
                style: AdaptiveStyle.material,
              );
              if (res == OkCancelResult.ok) {
                await logic.exportFile();
              }
            },
            trailing: const Icon(Icons.chevron_right_rounded),
            leading: const Icon(Icons.file_upload_outlined),
          ),
          AdaptiveListTile(
            title: Text(context.l10n.settingImport),
            subtitle: context.l10n.settingImportDes,
            onTap: () async {
              final res = await showOkCancelAlertDialog(
                context: context,
                title: context.l10n.settingImportDialogTitle,
                message: context.l10n.settingImportDialogContent,
                okLabel: context.l10n.settingImportSelectFile,
                style: AdaptiveStyle.material,
              );
              if (res == OkCancelResult.ok) {
                await logic.import();
              }
            },
            trailing: const Icon(Icons.chevron_right_rounded),
            leading: const Icon(Icons.file_download_outlined),
          ),
          AdaptiveListTile(
            title: const Text('导出 Markdown+JSON 备份'),
            subtitle: const Text(
              '全量结构化备份（日记/Block/CRM/知识库/对话），可跨端迁移',
            ),
            onTap: () => logic.exportStructured(),
            trailing: const Icon(Icons.chevron_right_rounded),
            leading: const Icon(Icons.backup_outlined),
          ),
          AdaptiveListTile(
            title: const Text('导入 Markdown+JSON 备份'),
            subtitle: const Text(
              '选择 moodiary_backup_*.zip 恢复（按 id 幂等合并）',
            ),
            onTap: () => logic.importStructured(),
            trailing: const Icon(Icons.chevron_right_rounded),
            leading: const Icon(Icons.restore_outlined),
          ),
          const LocalSendComponent(),
          const WebDavComponent(),
        ],
      ),
    );
  }
}
