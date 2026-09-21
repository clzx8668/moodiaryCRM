import 'package:flutter/material.dart';
import 'package:moodiary/components/base/tile/qr_tile.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

/// **旧版智能助手（腾讯云混元）** 的凭据配置页。
///
/// ## 它到底是什么（代码实证）
///
/// 这个功能来自原笔记软件，和新的 AI 体系**不是同一套东西**：
///
/// - 它不走 OpenAI 兼容协议，而是**腾讯云 TC3-HMAC-SHA256 签名**直连
///   `hunyuan.tencentcloudapi.com`（见 `utils/signature_util.dart`、
///   `api/api.dart` 的 `getHunYuan`）；
/// - 因此它**无法**作为"服务商"加进「模型管理」——那里是 Base URL + API Key 的
///   OpenAI 兼容协议，填腾讯云的 SecretId/SecretKey 是连不上的（签名方式不同）；
/// - 它只服务两个页面：「设置 → 功能 → 智能助手」的旧版对话页、
///   以及「设置 → 功能 → 分析统计」的 AI 点评。
///
/// ## 处理策略
///
/// 1. 从「模型管理」里撤出（那里是 OpenAI 兼容服务商的地盘，放这里会误导）；
/// 2. 单独挂到它真正服务的地方（设置 → 工具 → 桌面与提醒 里的入口），
///    并在入口上标明"旧版、需要腾讯云 Key"，用户一看就知道要不要配；
/// 3. 新版 AI 助手已经覆盖同样的能力（多服务商、主备切换、流式、知识库检索），
///    所以这一套属于"可退役"路径——是否彻底删除由用户决定。
class TencentHunyuanSettingsPage extends StatefulWidget {
  const TencentHunyuanSettingsPage({super.key});

  @override
  State<TencentHunyuanSettingsPage> createState() =>
      _TencentHunyuanSettingsPageState();
}

class _TencentHunyuanSettingsPageState
    extends State<TencentHunyuanSettingsPage> {
  bool _isSet(String key) =>
      (PrefUtil.getValue<String>(key) ?? '').trim().isNotEmpty;

  Future<void> _save(String key, String value) async {
    await PrefUtil.setValue<String>(key, value.trim());
    if (!mounted) return;
    toast.success(message: '已保存');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final idSet = _isSet('tencentId');
    final keySet = _isSet('tencentKey');
    return Scaffold(
      appBar: AppBar(title: const Text('智能助手（旧版）凭据')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '这是"旧版智能助手"用的凭据',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '它直连腾讯云混元接口（用的是腾讯云签名，不是 OpenAI 兼容协议），'
                    '所以**不能**填进「模型管理」的服务商里。\n\n'
                    '只服务于两个地方：功能区的「智能助手」旧版对话页、'
                    '以及「分析统计」的 AI 点评。\n\n'
                    '新版 AI 助手（底部导航"✨ AI"）用的是「模型管理」里的服务商，'
                    '支持多服务商主备切换、知识库检索，建议优先用新的。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          QrInputTile(
            title: '腾讯云 SecretId',
            subtitle: '${idSet ? '已设置' : '未设置'} · 腾讯云控制台访问管理里创建（AKID 开头）',
            value: PrefUtil.getValue<String>('tencentId') ?? '',
            prefix: 'tencentId',
            onValue: (v) => _save('tencentId', v),
          ),
          const SizedBox(height: 10),
          QrInputTile(
            title: '腾讯云 SecretKey',
            subtitle: '${keySet ? '已设置' : '未设置'} · 与 SecretId 配对，仅存本机',
            value: PrefUtil.getValue<String>('tencentKey') ?? '',
            prefix: 'tencentKey',
            onValue: (v) => _save('tencentKey', v),
          ),
          const SizedBox(height: 16),
          if (idSet && keySet)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '已配置完成，旧版助手与分析统计可用',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
