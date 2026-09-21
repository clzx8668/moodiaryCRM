import 'package:flutter/material.dart';
import 'package:moodiary/features/nav/mobile_nav_config.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 底部导航设置（二级页面，批次 118）。
///
/// 从「外观与交互」区进入——它属于界面定制，但条目多（6 个 tab 开关 + 说明），
/// 放在设置首页会把其它项挤下去，所以收成二级页。
class MobileNavSettingsPage extends StatefulWidget {
  const MobileNavSettingsPage({super.key});

  @override
  State<MobileNavSettingsPage> createState() => _MobileNavSettingsPageState();
}

class _MobileNavSettingsPageState extends State<MobileNavSettingsPage> {
  late List<int> _items;

  @override
  void initState() {
    super.initState();
    _items = List<int>.of(MobileNavConfig.items);
  }

  Future<void> _toggle(int pageIndex, bool on) async {
    final next = List<int>.of(_items);
    if (on) {
      if (!next.contains(pageIndex)) next.add(pageIndex);
    } else {
      // 至少保留 minItems 个，否则不允许关
      if (next.length <= MobileNavConfig.minItems) {
        toast.info(
          message: '至少保留 ${MobileNavConfig.minItems} 个导航项',
        );
        return;
      }
      next.remove(pageIndex);
    }
    // 按定义顺序排列，避免开关顺序错乱
    next.sort();
    setState(() => _items = next);
    await MobileNavConfig.save(next);
  }

  Future<void> _reset() async {
    final next = List<int>.of(MobileNavConfig.defaultItems);
    setState(() => _items = next);
    await MobileNavConfig.save(next);
    if (!mounted) return;
    toast.success(message: '已恢复默认底部导航');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('底部导航'),
        actions: [
          TextButton(onPressed: _reset, child: const Text('恢复默认')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            color: colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '选择底部导航要显示哪些入口；至少保留 ${MobileNavConfig.minItems} 个，'
                '顺序固定为「日记 → 日历 → 媒体 → CRM → AI → 设置」。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < MobileNavConfig.all.length; i++)
                  SwitchListTile(
                    value: _items.contains(MobileNavConfig.all[i].pageIndex),
                    onChanged: (v) =>
                        _toggle(MobileNavConfig.all[i].pageIndex, v),
                    title: Text(MobileNavConfig.all[i].label),
                    secondary: Icon(
                      _items.contains(MobileNavConfig.all[i].pageIndex)
                          ? MobileNavConfig.all[i].selectedIcon
                          : MobileNavConfig.all[i].icon,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '提示：把不常用的模块关掉，底部导航更清爽（隐藏的模块不会丢数据）。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
