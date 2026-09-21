import 'package:flutter/material.dart';
import 'package:moodiary/components/base/tile/qr_tile.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 第三方服务凭据（批次 114 从"实验室"归位到这里）。
///
/// 为什么单独成页：这些 Key 属于**功能配置**，不是实验开关。
/// 原来埋在"实验室"里，用户根本找不到，也说不清哪个功能需要哪把 Key。
/// 现在按用途分组，并在标题里写清"给谁用"。
class ThirdPartyKeysPage extends StatefulWidget {
  const ThirdPartyKeysPage({super.key});

  @override
  State<ThirdPartyKeysPage> createState() => _ThirdPartyKeysPageState();
}

class _ThirdPartyKeysPageState extends State<ThirdPartyKeysPage> {
  Future<void> _save(String key, String value) async {
    try {
      await PrefUtil.setValue<String>(key, value.trim());
      if (!mounted) return;
      toast.success(message: '已保存');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      toast.error(message: '保存失败：$e');
    }
  }

  bool _isSet(String key) =>
      (PrefUtil.getValue<String>(key) ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('第三方服务')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _section(
            context,
            icon: Icons.cloud_outlined,
            title: '天气服务（和风天气）',
            subtitle: '用于日记里的天气信息与自动定位',
          ),
          _tile(
            key: 'qweatherKey',
            title: '和风天气 Key',
            hint: '约 40 位；和风天气开发服务控制台可获取',
          ),
          _tile(
            key: 'qweatherApiHost',
            title: '和风天气 API Host',
            hint: '默认 devapi.qweather.com（个人版）；付费版填自己的 Host',
          ),
          const SizedBox(height: 18),
          _section(
            context,
            icon: Icons.map_outlined,
            title: '地图服务（天地图）',
            subtitle: '用于"足迹地图"加载底图瓦片',
          ),
          _tile(
            key: 'tiandituKey',
            title: '天地图 Key',
            hint: '约 32 位；天地图开放平台申请"浏览器端"Key',
          ),
          const SizedBox(height: 18),
          Card(
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '这些 Key 只保存在本机，不会随备份上传（除非你自己导出备份）。'
                '留空即表示不使用对应的在线服务，相关功能会保持关闭状态。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required String key,
    required String title,
    required String hint,
  }) {
    final set = _isSet(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: QrInputTile(
        title: title,
        subtitle: '${set ? '已设置' : '未设置'} · $hint',
        value: PrefUtil.getValue<String>(key) ?? '',
        prefix: key,
        onValue: (v) => _save(key, v),
      ),
    );
  }
}
