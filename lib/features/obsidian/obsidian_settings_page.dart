import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/obsidian/obsidian_config.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/utils/notice_util.dart';

/// Obsidian 设置页：启用开关 + Vault 路径 + 浏览 + 扫描索引。
class ObsidianSettingsPage extends StatefulWidget {
  const ObsidianSettingsPage({super.key});

  @override
  State<ObsidianSettingsPage> createState() => _ObsidianSettingsPageState();
}

class _ObsidianSettingsPageState extends State<ObsidianSettingsPage> {
  late TextEditingController _path;
  bool _enabled = ObsidianConfig.enabled.value;
  bool _scanning = false;
  int? _fileCount;

  @override
  void initState() {
    super.initState();
    _path = TextEditingController(text: ObsidianConfig.vaultPath.value);
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _save({bool? enabled, String? path}) async {
    await ObsidianConfig.save(enabled: enabled, vaultPath: path);
    // 首页 tab 行按开关显隐，重建 tab 控制器
    if (Get.isRegistered<DiaryLogic>()) {
      Get.find<DiaryLogic>().refreshTabs();
    }
  }

  Future<void> _browse() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || dir.isEmpty) return;
    setState(() => _path.text = dir);
    await _save(path: dir);
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final count = await ObsidianService.instance.scan(
      vaultPath: _path.text,
      force: true,
    );
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _fileCount = count;
    });
    toast.success(message: '已扫描 $count 个 Markdown 文件');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Obsidian 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _enabled,
            title: const Text('启用 Obsidian'),
            subtitle: const Text('开启后首页 tab 行显示「Obsidian」子页'),
            secondary: const Icon(Icons.link_rounded),
            onChanged: (v) async {
              setState(() => _enabled = v);
              await _save(enabled: v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _path,
            decoration: InputDecoration(
              labelText: 'Vault 路径',
              hintText: '如 D:\\MyVault',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: '浏览…',
                onPressed: _browse,
                icon: const Icon(Icons.folder_open_rounded),
              ),
            ),
            onSubmitted: (v) => _save(path: v),
          ),
          const SizedBox(height: 6),
          Text(
            'Vault 为只读接入（文件树 + 渲染 + 双链跳转），不做双向同步。',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: Icon(
                  _scanning
                      ? Icons.hourglass_top_rounded
                      : Icons.manage_search_rounded,
                  size: 16,
                ),
                label: Text(_scanning ? '扫描中…' : '扫描文件'),
              ),
              if (_fileCount != null) ...[
                const SizedBox(width: 12),
                Text(
                  '已索引 $_fileCount 个文件',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
