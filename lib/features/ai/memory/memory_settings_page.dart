import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/features/ai/memory/markdown_file_editor_page.dart';
import 'package:moodiary/features/ai/memory/memory_files.dart';
import 'package:moodiary/features/ai/memory/memory_store.dart';
import 'package:moodiary/features/ai/memory/memory_suggestion_service.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:path/path.dart' as p;

/// 「记忆与画像」页（批次 119）。
///
/// 把 Hermes 式分层记忆落到本项目：
/// - **Tier 1**（永远进上下文）：`profile.md` 我的画像 + `memory.md` 长期记忆；
/// - **Tier 2**（按需进上下文）：`skills/*.md` 自写技能手册；
/// - **Tier 3**：笔记向量检索（已有 RAG，不在此页管理）；
/// - **安全**：所有改动都有快照，可回滚；文件都在 `ai-memory/` 自留地内。
class MemorySettingsPage extends StatefulWidget {
  const MemorySettingsPage({super.key});

  @override
  State<MemorySettingsPage> createState() => _MemorySettingsPageState();
}

class _MemorySettingsPageState extends State<MemorySettingsPage> {
  bool _loading = true;
  String _profilePreview = '';
  String _memoryPreview = '';
  List<({String title, String preview})> _skills = const [];
  int _snapshotCount = 0;
  bool _suggestEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await MemoryStore.ensureReady();
    final profile = await MemoryStore.loadProfile();
    final memory = await MemoryStore.loadMemory();
    final skills = await MemoryStore.loadSkills();
    if (!mounted) return;
    setState(() {
      _profilePreview = profile.toPromptSection();
      _memoryPreview = memory.trim();
      _skills = skills.entries
          .map((e) => (title: e.key, preview: _firstLines(e.value)))
          .toList();
      _snapshotCount = MemoryStore.listSnapshots().length;
      _suggestEnabled = MemorySuggestionService.enabled;
      _loading = false;
    });
  }

  static String _firstLines(String text, [int n = 3]) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .take(n)
        .join(' · ');
    return lines.isEmpty ? '（空）' : lines;
  }

  Future<void> _editFile({
    required String path,
    required String title,
    String? hint,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MarkdownFileEditorPage(
          filePath: path,
          title: title,
          hint: hint,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openSnapshots() async {
    final snaps = MemoryStore.listSnapshots();
    if (snaps.isEmpty) {
      toast.info(message: '还没有历史版本');
      return;
    }
    final names = snaps.keys.toList()..sort((a, b) => b.compareTo(a));
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              dense: true,
              title: Text('历史版本（点一条回滚）'),
              subtitle: Text('每次保存前都会留一份快照，最多保留 10 份/文件'),
            ),
            const Divider(height: 1),
            for (final n in names.take(40))
              ListTile(
                dense: true,
                leading: const Icon(Icons.history_rounded, size: 18),
                title: Text(_prettySnapshotName(n), style: const TextStyle(fontSize: 13)),
                onTap: () => Navigator.of(ctx).pop(n),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final ok = await MemoryStore.restoreSnapshot(picked);
    if (!mounted) return;
    if (ok) {
      toast.success(message: '已回滚到该版本');
      await _load();
    } else {
      toast.error(message: '回滚失败（快照可能已被清理）');
    }
  }

  /// `profile.md.1730000000000.md` → `profile.md · 09-21 18:30`
  static String _prettySnapshotName(String raw) {
    final m = RegExp(r'^(.*)\.(\d{13})\.md$').firstMatch(raw);
    if (m == null) return raw;
    final ms = int.tryParse(m.group(2)!);
    final t = ms == null
        ? ''
        : DateTime.fromMillisecondsSinceEpoch(ms)
              .toString()
              .substring(5, 16)
              .replaceFirst('T', ' ');
    return '${m.group(1)} · $t';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆与画像'),
        actions: [
          IconButton(
            tooltip: '历史版本（可回滚）',
            onPressed: _openSnapshots,
            icon: Badge(
              isLabelVisible: _snapshotCount > 0,
              label: Text('$_snapshotCount'),
              child: const Icon(Icons.history_rounded),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _intro(context),
          const SizedBox(height: 12),
          // 自学习方式（用户选定的"建议式"）：AI 只提议，你点了才落盘
          SwitchListTile(
            value: _suggestEnabled,
            onChanged: (v) async {
              setState(() => _suggestEnabled = v);
              await MemorySuggestionService.setEnabled(v);
            },
            title: const Text('让 AI 建议值得记的内容'),
            subtitle: Text(
              _suggestEnabled
                  ? '任务结束时本地判断一次，弹一张卡片问你要不要记（不会自动写入）'
                  : '已关闭：AI 不会主动提议，只能你自己维护这些文件',
            ),
            secondary: const Icon(Icons.lightbulb_outline_rounded),
          ),
          const SizedBox(height: 14),
          _tierTitle(context, '第一层 · 永远参与 AI 处理'),
          _fileCard(
            icon: Icons.person_outline_rounded,
            title: '我的画像',
            subtitle: '专业词库 / 常用表达 / 风格偏好',
            preview: _profilePreview.isEmpty ? '（还没写）点右侧编辑' : _profilePreview,
            path: MemoryFiles.profilePath(),
            hint: '这里的内容会注入每一次 AI 处理：词库与常用表达每行一条，'
                '风格偏好写成一段话即可。可以自己加小节，AI 只读那三块。',
          ),
          _fileCard(
            icon: Icons.psychology_alt_outlined,
            title: '长期记忆',
            subtitle: '稳定、长期有效的事实与偏好',
            preview: _memoryPreview.isEmpty ? '（空）' : _memoryPreview,
            path: MemoryFiles.memoryPath(),
            hint: '只放**长期有效**的东西（"我常驻上海""客户多在制造业"）。'
                '一次性的事留在笔记里，AI 会通过检索找到。',
          ),
          const SizedBox(height: 14),
          _tierTitle(context, '第二层 · 命中关键词才参与'),
          if (_skills.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.auto_stories_outlined),
                title: Text('还没有技能手册'),
                subtitle: Text(
                  'AI 完成复杂任务或你纠正它之后，可以把"以后再遇到就这么做"写成手册存在这里；'
                  '下次相关内容会自动带上它',
                ),
              ),
            )
          else
            for (final s in _skills)
              _fileCard(
                icon: Icons.auto_stories_outlined,
                title: s.title,
                subtitle: '技能手册',
                preview: s.preview,
                path: p.join(MemoryFiles.skillsDir(), '${s.title}.md'),
                hint: '这是 AI 可以自学的流程手册；也可以自己写。',
                onDelete: () => _deleteSkill(s.title),
              ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _createSkill,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('新建技能手册'),
            ),
          ),
          const SizedBox(height: 14),
          _tierTitle(context, '第三层 · 笔记检索（系统自动）'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.search_rounded),
              title: const Text('笔记向量检索'),
              subtitle: Text(
                '你的笔记由系统按语义检索后按需提供给 AI，'
                '不需要在这里维护；相关开关在「AI 与笔记处理」。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '文件目录：${MemoryFiles.rootDir()}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '所有写入都会先留快照，右上角可回滚；这些文件只在本机，不会自动上传。',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.layers_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('三层记忆', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '① 画像 + 长期记忆：**永远**参与，用来记住你这个人；\n'
              '② 技能手册：**命中关键词才带上**，用来记住"该怎么做事"；\n'
              '③ 笔记检索：系统按语义找相关笔记，不用你维护。\n\n'
              '前两层就是下面这几个 Markdown 文件，可以直接在 App 里改。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _fileCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String preview,
    required String path,
    String? hint,
    VoidCallback? onDelete,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editFile(path: path, title: title, hint: hint),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${_fileSizeKb(path)} KB',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                )
              else
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fileSizeKb(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return '0';
      return (f.lengthSync() / 1024).toStringAsFixed(1);
    } catch (_) {
      return '0';
    }
  }

  Future<void> _createSkill() async {
    final name = await _askSkillTitle();
    if (name == null || name.trim().isEmpty) return;
    final title = name.trim();
    final path = p.join(MemoryFiles.skillsDir(), '${MemoryFiles.slugify(title)}.md');
    await MemoryStore.saveSkill(
      title,
      '# $title\n\n## 什么时候用\n\n（描述触发场景）\n\n## 步骤\n\n1. \n\n## 注意事项\n\n- \n',
      snapshot: false,
    );
    if (!mounted) return;
    await _editFile(path: path, title: title, hint: '这是 AI 与你自己都能读的手册');
    await _load();
  }

  Future<String?> _askSkillTitle() async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建技能手册'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '手册名',
            hintText: '例如：客户报价流程',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    return res;
  }

  Future<void> _deleteSkill(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「$title」？'),
        content: const Text('删除前会留一份快照，之后可以回滚。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await MemoryStore.deleteSkill(title);
    if (!mounted) return;
    toast.success(message: '已删除（可在历史版本里找回）');
    await _load();
  }
}
