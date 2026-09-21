import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'laboratory_logic.dart';

/// 实验室：**只留开发者/维护用的一次性工具**（批次 114 收敛）。
///
/// 移出去的内容：
/// - AI 设置入口 → 直接放在「AI 与笔记处理」区（不必绕这一层）；
/// - 第三方服务 Key（腾讯云/和风/天地图）→ 归到各功能对应设置：
///   和风天气与天地图在「设置 → 通用 → 第三方服务」，腾讯云在「模型管理」。
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
                padding: EdgeInsets.only(top: 12, bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '维护工具（面向开发者，平时用不到）',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              ListTile(
                onTap: () async {
                  logic.exportErrorLog();
                },
                title: const Text('导出日志文件'),
                subtitle: const Text('把运行日志导出成文件，便于排查问题'),
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
                subtitle: const Text('搜索不到旧内容时用；会重建关键词索引'),
              ),
            ],
          );
        },
      ),
    );
  }
}
