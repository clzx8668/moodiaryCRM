import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/smart_canvas/services/canvas_datasource.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 智能实体表单编辑器：浏览/编辑实体卡字段，可链接本地 CRM 缓存实体。
///
/// 参数：[EntityEditPayload]。保存回写 Block（JSON content + meta.entityType），
/// 标记 syncStatus=pending，返回 true。
class EntityEditorPage extends StatefulWidget {
  final EntityEditPayload payload;

  const EntityEditorPage({super.key, required this.payload});

  @override
  State<EntityEditorPage> createState() => _EntityEditorPageState();
}

class _EntityEditorPageState extends State<EntityEditorPage> {
  static const List<String> entityTypes = [
    'company',
    'person',
    'opportunity',
    'task',
    'custom',
  ];

  final CanvasDatasource _datasource = CanvasDatasource();
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  final _companyController = TextEditingController();
  final _searchController = TextEditingController();

  String _entityType = 'company';
  String _linkedTwentyId = '';
  List<CrmEntityCache> _searchResults = [];
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _load() async {
    final block = await _datasource.loadBlock(widget.payload.blockId);
    if (!mounted) return;
    if (block != null) {
      final data = _parse(block);
      _nameController.text = data['name'] as String? ?? '';
      _statusController.text = data['status'] as String? ?? '';
      _companyController.text = data['company'] as String? ?? '';
      _linkedTwentyId = data['crm_id'] as String? ?? '';
      _entityType = data['entity_type'] as String? ?? block.meta.entityType;
      if (!entityTypes.contains(_entityType)) _entityType = 'company';
    }
    setState(() => _loaded = true);
  }

  static Map<String, dynamic> _parse(Block block) {
    try {
      final decoded = jsonDecode(block.content);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (_) {
      return {};
    }
  }

  void _onSearchChanged() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await IsarUtil.searchCrmByName(keyword);
    if (mounted) {
      setState(() => _searchResults = results.take(8).toList());
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      toast.info(message: '实体名称不能为空');
      return;
    }
    final block = await _datasource.loadBlock(widget.payload.blockId);
    if (block == null) {
      toast.error(message: '卡片不存在或已删除');
      return;
    }
    setState(() => _saving = true);
    try {
      final content = jsonEncode({
        'entity_type': _entityType,
        'name': name,
        'status': _statusController.text.trim(),
        'company': _companyController.text.trim(),
        if (_linkedTwentyId.isNotEmpty) 'crm_id': _linkedTwentyId,
      });
      final meta = block.meta.clone()
        ..entityType = _entityType
        ..syncStatus = BlockMeta.syncPending;
      block
        ..content = content
        ..meta = meta
        ..updatedAt = DateTime.now();
      await _datasource.saveBlock(block);
      final diary = await _datasource.loadDiary(block.diaryId);
      if (diary != null) {
        await _datasource.refreshDiaryProjection(diary);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      toast.error(message: '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    _companyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实体卡片'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          TextButton(
            onPressed: _loaded && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _entityType,
            decoration: const InputDecoration(labelText: '实体类型'),
            items: entityTypes
                .map(
                  (t) => DropdownMenuItem(value: t, child: Text(t)),
                )
                .toList(),
            onChanged: (v) => setState(() => _entityType = v ?? 'company'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _statusController,
            decoration: const InputDecoration(
              labelText: '状态（如 pending / 跟进中）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _companyController,
            decoration: const InputDecoration(
              labelText: '公司',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('链接本地 CRM 缓存（可选）', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: '搜索客户/联系人…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final entity in _searchResults)
              ListTile(
                dense: true,
                leading: const Icon(Icons.business_rounded, size: 20),
                title: Text(entity.name),
                subtitle: Text(entity.entityType),
                trailing: entity.twentyId == _linkedTwentyId
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _linkedTwentyId = entity.twentyId;
                    if (_nameController.text.trim().isEmpty) {
                      _nameController.text = entity.name;
                    }
                    _searchController.clear();
                    _searchResults = [];
                  });
                },
              ),
          ],
          if (_linkedTwentyId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '已关联：$_linkedTwentyId',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// 实体编辑载荷
class EntityEditPayload {
  final String diaryId;
  final String blockId;

  const EntityEditPayload({required this.diaryId, required this.blockId});
}
