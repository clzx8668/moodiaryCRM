import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_content_link.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_api.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/persistence/isar.dart';

/// 内容同步结果汇总
class CrmContentSyncResult {
  final int pushedNotes;
  final int pushedTasks;
  final int linked;
  final int generic;
  final int failed;
  final List<String> errors;

  const CrmContentSyncResult({
    this.pushedNotes = 0,
    this.pushedTasks = 0,
    this.linked = 0,
    this.generic = 0,
    this.failed = 0,
    this.errors = const [],
  });

  int get total => pushedNotes + pushedTasks;

  @override
  String toString() =>
      '笔记 $pushedNotes · 待办 $pushedTasks · 关联 $linked · '
      '通用 $generic · 失败 $failed';
}

/// 未同步/已同步内容条目（内容同步页列表用）
class ContentSyncItem {
  final String localType;
  final String localId;
  final String title;
  final String snippet;
  final DateTime time;
  final CrmContentLink? link;

  /// 自动匹配提示（如「客户：Acme」）；未匹配为空
  final String matchHint;

  const ContentSyncItem({
    required this.localType,
    required this.localId,
    required this.title,
    required this.snippet,
    required this.time,
    this.link,
    this.matchHint = '',
  });

  bool get hasLink => link != null;

  bool get isLinked => link?.isLinked == true;

  bool get isGeneric => link?.isGeneric == true;

  bool get hasError => link?.hasError == true;
}

/// 关联目标结果（认领/自动匹配）
class EntityTarget {
  final String type;
  final String id;
  final String name;

  const EntityTarget({required this.type, required this.id, required this.name});
}

/// 内容同步服务：本地笔记/待办 ↔ Twenty note/task/moodiaryGeneric。
///
/// 设计（下一阶段：Twenty 数据对象对接）：
/// - 笔记（Diary）→ `note`；待办（Todo Block）→ `task`；
/// - 有客户/联系人/机会关联 → 自动创建 noteTarget/taskTarget 进入客户时间线；
/// - 无关联 → 优先写入通用对象 `moodiaryGeneric`（需按对接指导在 Twenty 创建），
///   对象不存在时回退为无 target 的标准 note/task；均可后续「认领关联」。
class CrmContentSyncService {
  final TwentyApiClient client;
  final SyncLogService log;

  /// 通用数据表对象名（Twenty 自定义对象，见 docs/twenty-数据对象对接指导.md）
  static const String genericObjectName = 'moodiaryGeneric';

  /// 标准对象中无关联数据使用的"未认领"状态标记
  static const String unclaimedMarker = '未认领';

  /// 通用对象存在性缓存（每次会话探测一次，避免逐条 introspection）
  bool? _genericExists;

  CrmContentSyncService({required this.client, SyncLogService? log})
    : log = log ?? SyncLogService.instance;

  factory CrmContentSyncService.fromConfig(TwentyConfig config) {
    return CrmContentSyncService(
      client: TwentyApiClient(config: config),
    );
  }

  // ==================== 推送 ====================

  /// 推送全部未同步内容（笔记 + 待办）。
  ///
  /// [force] 为 true 时无视已有映射重推；[targetEntityType]/[targetId] 指定后
  /// 仅推送并强制关联到该实体（用于「快速跟进」场景）。
  Future<CrmContentSyncResult> pushAll({
    bool force = false,
    String? targetEntityType,
    String? targetId,
  }) async {
    var notes = 0, tasks = 0, linked = 0, generic = 0, failed = 0;
    final errors = <String>[];

    final diaries = await IsarUtil.getAllDiaries();
    for (final diary in diaries) {
      if (!diary.show) continue;
      final existing = await IsarUtil.getCrmContentLinkByLocal(
        CrmContentLink.localTypeDiary,
        diary.id,
      );
      if (!force && existing != null) continue;
      try {
        final link = await pushDiary(
          diary,
          targetEntityType: targetEntityType,
          targetId: targetId,
        );
        notes++;
        if (link.isLinked) linked++;
        if (link.isGeneric) generic++;
      } catch (e) {
        failed++;
        errors.add('笔记「${diary.title}」：$e');
      }
    }

    final todoBlocks = await IsarUtil.getBlocksByType(BlockType.todo);
    for (final block in todoBlocks) {
      if (block.isDeleted) continue;
      final existing = await IsarUtil.getCrmContentLinkByLocal(
        CrmContentLink.localTypeBlock,
        block.id,
      );
      if (!force && existing != null) continue;
      try {
        final link = await pushTodoBlock(
          block,
          targetEntityType: targetEntityType,
          targetId: targetId,
        );
        tasks++;
        if (link.isLinked) linked++;
        if (link.isGeneric) generic++;
      } catch (e) {
        failed++;
        errors.add('待办「${_blockTitle(block)}」：$e');
      }
    }

    final result = CrmContentSyncResult(
      pushedNotes: notes,
      pushedTasks: tasks,
      linked: linked,
      generic: generic,
      failed: failed,
      errors: errors,
    );
    await log.write(
      level: failed > 0 ? SyncLogLevel.warn : SyncLogLevel.info,
      operation: 'push',
      target: 'content',
      detail: '内容推送完成：$result',
    );
    return result;
  }

  /// 推送一条日记为 Twenty 笔记。
  Future<CrmContentLink> pushDiary(
    Diary diary, {
    String? targetEntityType,
    String? targetId,
    bool autoMatch = true,
  }) async {
    final existing = await IsarUtil.getCrmContentLinkByLocal(
      CrmContentLink.localTypeDiary,
      diary.id,
    );
    final title = diary.title.trim().isEmpty ? '未命名日记' : diary.title.trim();
    final body = diary.contentText.trim().isNotEmpty
        ? diary.contentText.trim()
        : diary.content.trim();

    EntityTarget? target;
    if (targetEntityType != null && targetId != null) {
      target = await _resolveTargetById(targetEntityType, targetId);
    } else if (autoMatch) {
      target = await matchEntity('$title\n$body');
    }

    final link =
        existing ??
        (CrmContentLink()
          ..localType = CrmContentLink.localTypeDiary
          ..localId = diary.id)
      ..error = ''
      ..updatedAt = DateTime.now();

    if (target != null) {
      if (existing?.remoteType == CrmContentLink.remoteTypeGeneric) {
        // 通用对象已有映射，且本次携带关联 → 升级转换
        return _upgradeGenericToLinked(link, target);
      }
      String remoteId = link.remoteId;
      if (remoteId.isEmpty) {
        remoteId = (await client.createNote(title: title, body: body)).id;
      } else if (link.remoteType == CrmContentLink.remoteTypeNote) {
        await client.updateNote(id: remoteId, title: title, body: body);
      }
      await _ensureNoteTarget(remoteId, target);
      link
        ..remoteType = CrmContentLink.remoteTypeNote
        ..remoteId = remoteId
        ..targetType = target.type
        ..targetId = target.id
        ..status = CrmContentLink.statusLinked;
    } else {
      link
        ..targetType = ''
        ..targetId = '';
      if (await _genericObjectExists()) {
        String remoteId = link.remoteId;
        if (remoteId.isEmpty ||
            link.remoteType != CrmContentLink.remoteTypeGeneric) {
          remoteId = (await client.create(
            object: genericObjectName,
            data: {
              'title': title,
              'content': body,
              'sourceType': 'note',
            },
            fields: ['id', 'title'],
          )).id;
          // 旧标准对象残留清理（历史映射升级场景）
          if (link.remoteId.isNotEmpty &&
              link.remoteType != CrmContentLink.remoteTypeGeneric) {
            try {
              await client.delete(object: link.remoteType, id: link.remoteId);
            } catch (_) {}
          }
        } else {
          await client.update(
            object: genericObjectName,
            id: remoteId,
            data: {'title': title, 'content': body, 'sourceType': 'note'},
          );
        }
        link
          ..remoteType = CrmContentLink.remoteTypeGeneric
          ..remoteId = remoteId
          ..status = CrmContentLink.statusGeneric;
      } else {
        String remoteId = link.remoteId;
        if (remoteId.isEmpty) {
          remoteId = (await client.createNote(title: title, body: body)).id;
        } else if (link.remoteType == CrmContentLink.remoteTypeNote) {
          await client.updateNote(id: remoteId, title: title, body: body);
        }
        link
          ..remoteType = CrmContentLink.remoteTypeNote
          ..remoteId = remoteId
          ..status = CrmContentLink.statusGeneric;
      }
    }

    await IsarUtil.upsertCrmContentLinks([link]);
    return link;
  }

  /// 推送一个待办 Block 为 Twenty 任务。
  Future<CrmContentLink> pushTodoBlock(
    Block block, {
    String? targetEntityType,
    String? targetId,
    bool autoMatch = true,
  }) async {
    final diary = await IsarUtil.getDiaryById(block.diaryId);
    final existing = await IsarUtil.getCrmContentLinkByLocal(
      CrmContentLink.localTypeBlock,
      block.id,
    );
    final title = _blockTitle(block);
    final body = block.content;
    final dueAt = block.meta.dueDate.isEmpty
        ? null
        : DateTime.tryParse(block.meta.dueDate);
    final status = _statusFromBlock(block);

    EntityTarget? target;
    final diaryText =
        '${diary?.title ?? ''}\n${diary?.contentText ?? ''}\n$title';
    if (targetEntityType != null && targetId != null) {
      target = await _resolveTargetById(targetEntityType, targetId);
    } else if (autoMatch) {
      target = await matchEntity(diaryText);
    }

    final link =
        existing ??
        (CrmContentLink()
          ..localType = CrmContentLink.localTypeBlock
          ..localId = block.id)
      ..error = ''
      ..updatedAt = DateTime.now();

    if (target != null) {
      if (existing?.remoteType == CrmContentLink.remoteTypeGeneric) {
        return _upgradeGenericToLinked(link, target);
      }
      String remoteId = link.remoteId;
      if (remoteId.isEmpty) {
        remoteId = (await client.createTask(
          title: title,
          body: body,
          dueAt: dueAt,
          status: status,
        )).id;
      } else if (link.remoteType == CrmContentLink.remoteTypeTask) {
        await client.updateTask(
          id: remoteId,
          title: title,
          body: body,
          dueAt: dueAt,
          status: status,
        );
      }
      await _ensureTaskTarget(remoteId, target);
      link
        ..remoteType = CrmContentLink.remoteTypeTask
        ..remoteId = remoteId
        ..targetType = target.type
        ..targetId = target.id
        ..status = CrmContentLink.statusLinked;
    } else {
      link
        ..targetType = ''
        ..targetId = '';
      if (await _genericObjectExists()) {
        String remoteId = link.remoteId;
        if (remoteId.isEmpty ||
            link.remoteType != CrmContentLink.remoteTypeGeneric) {
          remoteId = (await client.create(
            object: genericObjectName,
            data: {
              'title': title,
              'content': body,
              'sourceType': 'todo',
              if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
              if (status.isNotEmpty) 'status': status,
            },
            fields: ['id', 'title'],
          )).id;
          if (link.remoteId.isNotEmpty &&
              link.remoteType != CrmContentLink.remoteTypeGeneric) {
            try {
              await client.delete(object: link.remoteType, id: link.remoteId);
            } catch (_) {}
          }
        } else {
          await client.update(
            object: genericObjectName,
            id: remoteId,
            data: {
              'title': title,
              'content': body,
              'sourceType': 'todo',
              if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
              if (status.isNotEmpty) 'status': status,
            },
          );
        }
        link
          ..remoteType = CrmContentLink.remoteTypeGeneric
          ..remoteId = remoteId
          ..status = CrmContentLink.statusGeneric;
      } else {
        String remoteId = link.remoteId;
        if (remoteId.isEmpty) {
          remoteId = (await client.createTask(
            title: title,
            body: body,
            dueAt: dueAt,
            status: status,
          )).id;
        } else if (link.remoteType == CrmContentLink.remoteTypeTask) {
          await client.updateTask(
            id: remoteId,
            title: title,
            body: body,
            dueAt: dueAt,
            status: status,
          );
        }
        link
          ..remoteType = CrmContentLink.remoteTypeTask
          ..remoteId = remoteId
          ..status = CrmContentLink.statusGeneric;
      }
    }

    await IsarUtil.upsertCrmContentLinks([link]);
    return link;
  }

  // ==================== 认领 / 取消关联 ====================

  /// 认领关联：为无关联的远端对象挂上公司/联系人/机会 target，进入客户时间线。
  Future<CrmContentLink> claimAssociation(
    CrmContentLink link, {
    required String targetEntityType,
    required String targetId,
  }) async {
    if (link.remoteId.isEmpty) {
      throw StateError('远端对象缺失，无法认领：${link.localId}');
    }
    final target = await _resolveTargetById(targetEntityType, targetId);

    if (link.remoteType == CrmContentLink.remoteTypeGeneric) {
      // 通用对象 → 升级为标准 note/task 并挂 target
      return _upgradeGenericToLinked(link, target);
    } else if (link.remoteType == CrmContentLink.remoteTypeNote) {
      await _ensureNoteTarget(link.remoteId, target);
    } else if (link.remoteType == CrmContentLink.remoteTypeTask) {
      await _ensureTaskTarget(link.remoteId, target);
    } else {
      throw UnsupportedError('不支持的远端类型：${link.remoteType}');
    }

    link
      ..targetType = target.type
      ..targetId = target.id
      ..status = CrmContentLink.statusLinked
      ..error = ''
      ..updatedAt = DateTime.now();
    await IsarUtil.upsertCrmContentLinks([link]);
    await log.write(
      level: SyncLogLevel.info,
      operation: 'claim',
      target: '${target.type}:${target.name}',
      detail: '认领关联 ${link.localType}/${link.localId} → ${link.remoteType}',
    );
    return link;
  }

  /// 通用对象记录升级为标准 note/task 并挂 target（认领关联的核心转换）。
  Future<CrmContentLink> _upgradeGenericToLinked(
    CrmContentLink link,
    EntityTarget target,
  ) async {
    final oldGenericId = link.remoteId;
    final sourceType = _genericSourceType(link);
    final (title, body, dueAt, status) = await _genericRecordContent(link);
    final now = DateTime.now();
    if (sourceType == 'todo') {
      final created = await client.createTask(
        title: title,
        body: body,
        dueAt: dueAt,
        status: status,
      );
      await _ensureTaskTarget(created.id, target);
      link
        ..remoteType = CrmContentLink.remoteTypeTask
        ..remoteId = created.id;
    } else {
      final created = await client.createNote(title: title, body: body);
      await _ensureNoteTarget(created.id, target);
      link
        ..remoteType = CrmContentLink.remoteTypeNote
        ..remoteId = created.id;
    }
    try {
      await client.delete(
        object: CrmContentLink.remoteTypeGeneric,
        id: oldGenericId,
      );
    } catch (_) {
      // 清理失败不阻断：数据仍以新 note/task 为准，通用记录留待手动清理
    }
    link
      ..targetType = target.type
      ..targetId = target.id
      ..status = CrmContentLink.statusLinked
      ..error = ''
      ..updatedAt = now;
    await IsarUtil.upsertCrmContentLinks([link]);
    return link;
  }

  /// 移除远端 noteTarget/taskTarget（取消关联，回到未认领状态）。
  Future<CrmContentLink> removeAssociation(CrmContentLink link) async {
    if (link.remoteId.isEmpty) return link;
    if (link.targetId.isEmpty) return link;
    final targetObject =
        link.remoteType == CrmContentLink.remoteTypeTask
            ? 'taskTarget'
            : 'noteTarget';
    final targets = await client.listAll(
      object: targetObject,
      fields: const ['id', 'taskId', 'noteId', 'companyId', 'personId', 'opportunityId'],
    );
    for (final t in targets) {
      final belongs =
          t.data['taskId']?.toString() == link.remoteId ||
          t.data['noteId']?.toString() == link.remoteId;
      final matchesTarget = t.data['companyId']?.toString() == link.targetId ||
          t.data['personId']?.toString() == link.targetId ||
          t.data['opportunityId']?.toString() == link.targetId;
      if (belongs && matchesTarget) {
        await client.delete(object: targetObject, id: t.id);
      }
    }
    link
      ..targetType = ''
      ..targetId = ''
      ..status = CrmContentLink.statusGeneric
      ..updatedAt = DateTime.now();
    await IsarUtil.upsertCrmContentLinks([link]);
    return link;
  }

  // ==================== 拉取 / 删除 ====================

  /// 拉取 Twenty 笔记/待办写入本地缓存（entityType = note/task），供展示与对账。
  Future<CrmSyncResult> pullRemoteContent() async {
    final notes = await client.listNotes();
    final tasks = await client.listTasks();
    final now = DateTime.now();
    final caches = <CrmEntityCache>[];
    for (final entity in notes) {
      caches.add(
        CrmEntityCache()
          ..twentyId = entity.id
          ..entityType = 'note'
          ..name =
              entity.data['title']?.toString() ??
              entity.data['name']?.toString() ??
              entity.id
          ..setData(entity.data)
          ..lastSyncedAt = now
          ..updatedAt = now,
      );
    }
    for (final entity in tasks) {
      caches.add(
        CrmEntityCache()
          ..twentyId = entity.id
          ..entityType = 'task'
          ..name =
              entity.data['title']?.toString() ??
              entity.data['name']?.toString() ??
              entity.id
          ..setData(entity.data)
          ..lastSyncedAt = now
          ..updatedAt = now,
      );
    }
    await IsarUtil.upsertCrmEntities(caches);
    return CrmSyncResult(
      syncedAt: now,
      pulledByObject: {'note': notes.length, 'task': tasks.length},
      totalPulled: notes.length + tasks.length,
    );
  }

  /// 删除远端对象（note/task/moodiaryGeneric）并清除本地映射。
  Future<void> deleteRemote(CrmContentLink link) async {
    if (link.remoteId.isNotEmpty && link.remoteType.isNotEmpty) {
      await client.delete(object: link.remoteType, id: link.remoteId);
    }
    await IsarUtil.removeCrmContentLink(link.id);
  }

  // ==================== 本地清单 / 自动匹配 ====================

  /// 内容同步清单（UI：笔记 + 待办，附映射与自动匹配提示）。
  Future<List<ContentSyncItem>> listContent() async {
    final items = <ContentSyncItem>[];
    final diaries = await IsarUtil.getAllDiaries();
    for (final diary in diaries.where((d) => d.show)) {
      final link = await IsarUtil.getCrmContentLinkByLocal(
        CrmContentLink.localTypeDiary,
        diary.id,
      );
      final text = '${diary.title}\n${diary.contentText}';
      items.add(
        ContentSyncItem(
          localType: CrmContentLink.localTypeDiary,
          localId: diary.id,
          title: diary.title.trim().isEmpty ? '未命名日记' : diary.title,
          snippet: diary.contentText,
          time: diary.time,
          link: link,
          matchHint: link == null ? await _matchHint(text) : '',
        ),
      );
    }
    final blocks = await IsarUtil.getBlocksByType(BlockType.todo);
    for (final block in blocks.where((b) => !b.isDeleted)) {
      final link = await IsarUtil.getCrmContentLinkByLocal(
        CrmContentLink.localTypeBlock,
        block.id,
      );
      final diary = await IsarUtil.getDiaryById(block.diaryId);
      items.add(
        ContentSyncItem(
          localType: CrmContentLink.localTypeBlock,
          localId: block.id,
          title: _blockTitle(block),
          snippet: block.content,
          time: block.updatedAt,
          link: link,
          matchHint: link == null
              ? await _matchHint('${diary?.title ?? ''}\n${diary?.contentText ?? ''}\n${block.content}')
              : '',
        ),
      );
    }
    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }

  /// 自动匹配：文本中出现本地缓存客户/联系人/机会名称 → 返回最优目标。
  /// 优先级：公司 > 联系人 > 机会（同为客户时间线的主要关联对象）。
  Future<EntityTarget?> matchEntity(String text) async {
    final normalized = text.toLowerCase();
    for (final type in ['company', 'person', 'opportunity']) {
      final entities = await IsarUtil.getCrmEntitiesByType(type);
      EntityTarget? best;
      var bestLen = 0;
      for (final entity in entities) {
        final name = entity.name.trim();
        if (name.length < 2) continue;
        if (normalized.contains(name.toLowerCase()) && name.length > bestLen) {
          best = EntityTarget(type: type, id: entity.twentyId, name: name);
          bestLen = name.length;
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  Future<String> _matchHint(String text) async {
    final target = await matchEntity(text);
    if (target == null) return '';
    const labels = {'company': '客户', 'person': '联系人', 'opportunity': '机会'};
    return '${labels[target.type] ?? target.type}：${target.name}';
  }

  Future<EntityTarget> _resolveTargetById(String type, String id) async {
    final entity = await IsarUtil.getCrmEntityByTwentyId(id);
    if (entity != null && entity.entityType == type) {
      return EntityTarget(type: type, id: entity.twentyId, name: entity.name);
    }
    // 兜底：类型已知但本地无缓存（远端直连场景）
    return EntityTarget(type: type, id: id, name: id);
  }

  /// 探测通用对象是否存在（结果缓存，一次同步会话只探测一次）。
  Future<bool> _genericObjectExists() async {
    if (_genericExists != null) return _genericExists!;
    try {
      _genericExists = await client.typeExists(genericObjectName);
    } catch (_) {
      _genericExists = false;
    }
    if (_genericExists == false) {
      await log.write(
        level: SyncLogLevel.info,
        operation: 'push',
        target: genericObjectName,
        detail: '通用对象不存在，未关联数据回退为标准对象（可后续认领关联）',
      );
    }
    return _genericExists!;
  }

  Future<void> _ensureNoteTarget(String noteId, EntityTarget target) async {
    await client.createNoteTarget(
      noteId: noteId,
      companyId: target.type == 'company' ? target.id : null,
      personId: target.type == 'person' ? target.id : null,
      opportunityId: target.type == 'opportunity' ? target.id : null,
    );
  }

  Future<void> _ensureTaskTarget(String taskId, EntityTarget target) async {
    await client.createTaskTarget(
      taskId: taskId,
      companyId: target.type == 'company' ? target.id : null,
      personId: target.type == 'person' ? target.id : null,
      opportunityId: target.type == 'opportunity' ? target.id : null,
    );
  }

  String _blockTitle(Block block) {
    final lines = block.content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '未命名待办';
    final first = lines.first.replaceFirst(RegExp(r'^[-*]\s+\[\s*[ xX]\]\s+'), '');
    return first.length > 40 ? '${first.substring(0, 40)}…' : first;
  }

  String _statusFromBlock(Block block) {
    final done = RegExp(r'\[[xX]\]').hasMatch(block.content) &&
        !RegExp(r'\[ \]').hasMatch(block.content);
    return done ? 'DONE' : 'TODO';
  }

  String _genericSourceType(CrmContentLink link) =>
      link.localType == CrmContentLink.localTypeBlock ? 'todo' : 'note';

  Future<(String, String, DateTime?, String?)> _genericRecordContent(
    CrmContentLink link,
  ) async {
    if (link.localType == CrmContentLink.localTypeBlock) {
      final block = await IsarUtil.getBlockById(link.localId);
      if (block != null) {
        final dueAt = block.meta.dueDate.isEmpty
            ? null
            : DateTime.tryParse(block.meta.dueDate);
        return (_blockTitle(block), block.content, dueAt, _statusFromBlock(block));
      }
    }
    final diary = await IsarUtil.getDiaryById(link.localId);
    if (diary != null) {
      final title = diary.title.trim().isEmpty ? '未命名日记' : diary.title.trim();
      final body = diary.contentText.trim().isNotEmpty
          ? diary.contentText.trim()
          : diary.content.trim();
      return (title, body, null, null);
    }
    return ('未命名记录', '', null, null);
  }
}
