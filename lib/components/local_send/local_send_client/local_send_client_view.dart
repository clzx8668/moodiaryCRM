import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/features/backup/backup_service.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/file_util.dart';

import 'local_send_client_logic.dart';
import 'local_send_client_state.dart';

class LocalSendClientComponent extends StatelessWidget {
  const LocalSendClientComponent({super.key});

  BackupScope get _scope =>
      backupScopeFromName(PrefUtil.getValue<String>('lanSyncContentScope'));

  Future<void> _showScopeDialog(BuildContext context) async {
    var selected = _scope;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('同步内容设置'),
          content: RadioGroup<BackupScope>(
            groupValue: selected,
            onChanged: (v) => setDialogState(() => selected = v!),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<BackupScope>(
                  value: BackupScope.notes,
                  title: Text('仅笔记'),
                  subtitle: Text('日记、Block（含待办）、分类'),
                ),
                RadioListTile<BackupScope>(
                  value: BackupScope.all,
                  title: Text('全部'),
                  subtitle: Text(
                    '笔记 + CRM + 知识库/向量 + 对话记录 + AI 配置',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                await PrefUtil.setValue<String>(
                  'lanSyncContentScope',
                  selected.name,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LocalSendClientLogic logic = Get.put(LocalSendClientLogic());
    final LocalSendClientState state = Bind.find<LocalSendClientLogic>().state;

    Widget buildSend() {
      if (state.isFindingServer) {
        return AdaptiveListTile(
          title: context.l10n.lanTransferFindingServer,
          subtitle: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(2.0),
          ),
        );
      } else if (state.serverIp == null) {
        return Obx(() {
          return AdaptiveListTile(
            title: context.l10n.lanTransferCantFindServer,
            subtitle: state.findStatus.value,
            leading: const FaIcon(FontAwesomeIcons.triangleExclamation),
            trailing: FilledButton(
              onPressed: () {
                logic.restartFindServer();
              },
              child: const FaIcon(FontAwesomeIcons.repeat),
            ),
          );
        });
      } else {
        return Column(
          children: [
            AdaptiveListTile(
              title: state.serverName!,
              subtitle: state.serverIp!,
              trailing: FilledButton(
                onPressed: () async {
                  await logic.sendDiaryList();
                },
                child: const FaIcon(FontAwesomeIcons.solidPaperPlane),
              ),
            ),
            AdaptiveListTile(
              title: const Text('同步全部数据'),
              subtitle: const Text(
                '日记/Block/待办/CRM/知识库/对话记录/AI 配置（多端合并）',
              ),
              leading: const Icon(Icons.sync_rounded),
              trailing: FilledButton(
                onPressed: state.isSending.value
                    ? null
                    : () async {
                        await logic.sendAllData();
                      },
                child: const FaIcon(FontAwesomeIcons.fileZipper),
              ),
            ),
          ],
        );
      }
    }

    Widget buildProgress() {
      return Obx(() {
        return state.isSending.value
            ? ListTile(
              title: Obx(() {
                return LinearProgressIndicator(
                  value: state.progress.value,
                  borderRadius: BorderRadius.circular(2.0),
                );
              }),
              subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() {
                    return Text(
                      '${state.sendCount.value} / ${state.diaryToSend.length}',
                    );
                  }),
                  Obx(() {
                    final speed = FileUtil.bytesToUnits(
                      state.speed.value.toInt(),
                    );
                    return Text('${speed['size']}${speed['unit']}/s');
                  }),
                ],
              ),
            )
            : const SizedBox.shrink();
      });
    }

    Widget buildSelect() {
      return Obx(() {
        return AdaptiveListTile(
          title: context.l10n.lanTransferSelectDiary,
          subtitle: Text(
            '${context.l10n.lanTransferHasSelected} ${state.diaryToSend.length}',
          ),
          trailing: FilledButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                useSafeArea: true,
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Wrap(
                      spacing: 8.0,
                      children: [
                        ActionChip(
                          label: const Text('一天内'),
                          onPressed: () async {
                            await logic.setDiary(
                              const Duration(days: 1),
                              context,
                            );
                          },
                        ),
                        ActionChip(
                          label: const Text('一周内'),
                          onPressed: () async {
                            await logic.setDiary(
                              const Duration(days: 7),
                              context,
                            );
                          },
                        ),
                        ActionChip(
                          label: const Text('一个月内'),
                          onPressed: () async {
                            await logic.setDiary(
                              const Duration(days: 31),
                              context,
                            );
                          },
                        ),
                        ActionChip(
                          label: const Text('三个月'),
                          onPressed: () async {
                            await logic.setDiary(
                              const Duration(days: 92),
                              context,
                            );
                          },
                        ),
                        ActionChip(
                          label: const Text('全部'),
                          onPressed: () async {
                            await logic.setAllDiary(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: const FaIcon(FontAwesomeIcons.fileCirclePlus),
          ),
        );
      });
    }

    Widget buildScope() {
      return AdaptiveListTile(
        title: const Text('同步内容'),
        subtitle: Text(
          _scope == BackupScope.all
              ? '全部（含知识库/待办/对话记录/AI 配置）'
              : '仅笔记（日记/Block/分类）',
        ),
        leading: const Icon(Icons.tune_rounded),
        trailing: Text(
          _scope == BackupScope.all ? '全部' : '仅笔记',
          style: context.textTheme.bodySmall!.copyWith(
            color: context.theme.colorScheme.primary,
          ),
        ),
        onTap: () => _showScopeDialog(context),
      );
    }

    return GetBuilder<LocalSendClientLogic>(
      assignId: true,
      builder: (_) {
        return Column(
          children: [buildSelect(), buildScope(), buildSend(), buildProgress()],
        );
      },
    );
  }
}
