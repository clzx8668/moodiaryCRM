import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/tile/qr_tile.dart';
import 'package:moodiary/features/ai/ai_settings_page.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'laboratory_logic.dart';

class LaboratoryPage extends StatelessWidget {
  const LaboratoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<LaboratoryLogic>();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingLab)),
      body: GetBuilder<LaboratoryLogic>(
        builder: (_) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'AI 服务（OpenAI 兼容）',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Card.filled(
                color: context.theme.colorScheme.surfaceContainerLow,
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('AI 设置'),
                  subtitle: const Text(
                    '对话模型 / Embedding 模型 / API Key 与连接测试（安全存储）',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Get.to(() => const AiSettingsPage());
                  },
                ),
              ),
              const Gap(18),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '第三方服务 Key',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              QrInputTile(
                title: '${context.l10n.labTencentCloud} ID',
                subtitle:
                    '${(PrefUtil.getValue<String>('tencentId') ?? '').isNotEmpty ? '已设置' : '未设置'} · 腾讯云 SecretId（AKID 开头）· 混元大模型对话',
                value: PrefUtil.getValue<String>('tencentId') ?? '',
                prefix: 'tencentId',
                onValue: (value) async {
                  final res = await logic.setTencentID(id: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labTencentCloud} Key',
                subtitle:
                    '${(PrefUtil.getValue<String>('tencentKey') ?? '').isNotEmpty ? '已设置' : '未设置'} · 腾讯云 SecretKey，与 SecretId 配对',
                value: PrefUtil.getValue<String>('tencentKey') ?? '',
                prefix: 'tencentKey',
                onValue: (value) async {
                  final res = await logic.setTencentKey(key: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labQweather} Key',
                subtitle:
                    '${(PrefUtil.getValue<String>('qweatherKey') ?? '').isNotEmpty ? '已设置' : '未设置'} · 和风天气开发服务 Key（约 40 位）',
                value: PrefUtil.getValue<String>('qweatherKey') ?? '',
                prefix: 'qweatherKey',
                onValue: (value) async {
                  final res = await logic.setQweatherKey(key: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labQweather} API Host',
                subtitle:
                    '${(PrefUtil.getValue<String>('qweatherApiHost') ?? '').isNotEmpty ? '已设置' : '未设置'} · 默认 devapi.qweather.com（个人版）',
                value: PrefUtil.getValue<String>('qweatherApiHost') ?? '',
                prefix: 'qweatherApiHost',
                onValue: (value) async {
                  final res = await logic.setQweatherApiHost(host: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),

              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labTianditu} Key',
                subtitle:
                    '${(PrefUtil.getValue<String>('tiandituKey') ?? '').isNotEmpty ? '已设置' : '未设置'} · 天地图开放平台浏览器端 Key（约 32 位）',
                value: PrefUtil.getValue<String>('tiandituKey') ?? '',
                prefix: 'tiandituKey',
                onValue: (value) async {
                  final res = await logic.setTiandituKey(key: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  logic.exportErrorLog();
                },
                title: const Text('导出日志文件'),
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  final res = await logic.aesTest();
                  if (res) {
                    toast.success(message: '加密测试通过');
                  } else {
                    toast.error(message: '加密测试失败');
                  }
                },
                title: const Text('加密测试'),
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  final res = await logic.clearImageThumbnail();
                  if (res) {
                    toast.success(message: '清理成功');
                  } else {
                    toast.error(message: '清理失败');
                  }
                },
                title: const Text('清理图片缩略图缓存'),
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  final res = logic.generateFTSAndKeyword();
                  if (res) {
                    toast.success(message: '重新生成成功');
                  } else {
                    toast.error(message: '重新生成失败');
                  }
                },
                title: const Text('重新进行全文搜索索引'),
              ),
            ],
          );
        },
      ),
    );
  }
}
