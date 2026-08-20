import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/features/rag/models/knowledge_base.dart';
import 'package:moodiary/features/rag/rag_chat_page.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 知识库管理页（P3.2）：多知识空间 CRUD + 索引入口。
class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  final RagService _service = RagService();
  List<KnowledgeBase> _kbs = [];
  final Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final kbs = await _service.listKnowledgeBases();
    final counts = <String, int>{};
    for (final kb in kbs) {
      counts[kb.id] = await _service.countEmbeddings(kb.id);
    }
    if (mounted) {
      setState(() {
        _kbs = kbs;
        _counts..clear()..addAll(counts);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建知识库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: '描述（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.createKnowledgeBase(
          name.text,
          description: desc.text,
        );
        toast.success(message: '知识库已创建');
        await _load();
      } catch (e) {
        toast.error(message: '$e');
      }
    }
  }

  Future<void> _delete(KnowledgeBase kb) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除知识库'),
        content: Text('删除「${kb.name}」将同时清除其中所有向量索引，确定？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteKnowledgeBase(kb.id);
      toast.success(message: '已删除');
      await _load();
    }
  }

  Future<void> _indexAll(KnowledgeBase kb) async {
    toast.info(message: '正在索引全部文本卡片（可能需要几分钟）…');
    final count = await _service.indexBlocks(knowledgeBaseId: kb.id);
    toast.success(message: '索引完成：$count 个卡片');
    await _load();
  }

  void _openChat(KnowledgeBase kb) {
    Get.to(() => RagChatPage(knowledgeBase: kb))?.then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识库'),
        actions: [
          IconButton(
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
            tooltip: '新建知识库',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _kbs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 56,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('还没有知识库，点击右上角 + 新建'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _kbs.length,
              itemBuilder: (context, index) {
                final kb = _kbs[index];
                final count = _counts[kb.id] ?? 0;
                return Card.outlined(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(kb.name),
                    subtitle: Text(
                      [
                        if (kb.description.isNotEmpty) kb.description,
                        '$count 条向量',
                        DateFormat.yMMMd()
                            .add_Hm()
                            .format(kb.updatedAt),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'index') {
                          _indexAll(kb);
                        } else if (v == 'delete') {
                          _delete(kb);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'index',
                          child: Text('索引全部卡片'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('删除'),
                        ),
                      ],
                    ),
                    onTap: () => _openChat(kb),
                  ),
                );
              },
            ),
    );
  }
}
