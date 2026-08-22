import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/crm_content_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_content_link.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_api.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

/// 可编程 Mock 适配器（覆盖内容同步相关查询/变更）
class ContentMockAdapter implements HttpClientAdapter {
  final bool genericExists;
  final List<String> calls;

  ContentMockAdapter({this.genericExists = true}) : calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data is String
        ? jsonDecode(options.data as String) as Map<String, dynamic>
        : options.data as Map<String, dynamic>;
    final query = body['query'] as String? ?? '';
    final variables = (body['variables'] as Map<String, dynamic>?) ?? {};
    final data = <String, dynamic>{};

    if (query.contains('__type')) {
      data['__type'] = genericExists
          ? {'name': CrmContentSyncService.genericObjectName}
          : null;
    } else if (query.contains('createNote(')) {
      calls.add('createNote');
      data['createNote'] = {'id': 'note-1', 'title': '标题'};
    } else if (query.contains('updateNote(')) {
      calls.add('updateNote');
      data['updateNote'] = {'id': variables['id'], 'title': '标题'};
    } else if (query.contains('createTask(')) {
      calls.add('createTask');
      data['createTask'] = {'id': 'task-1', 'title': '任务', 'status': 'TODO'};
    } else if (query.contains('updateTask(')) {
      calls.add('updateTask');
      data['updateTask'] = {
        'id': variables['id'],
        'title': '任务',
        'status': 'TODO',
      };
    } else if (query.contains('createNoteTarget(')) {
      calls.add('createNoteTarget');
      data['createNoteTarget'] = {
        'id': 'nt-1',
        'noteId': variables['data']?['noteId'],
        'companyId': variables['data']?['companyId'],
      };
    } else if (query.contains('createTaskTarget(')) {
      calls.add('createTaskTarget');
      data['createTaskTarget'] = {
        'id': 'tt-1',
        'taskId': variables['data']?['taskId'],
        'companyId': variables['data']?['companyId'],
      };
    } else if (query.contains('createMoodiaryGeneric(')) {
      calls.add('createMoodiaryGeneric');
      data['createMoodiaryGeneric'] = {'id': 'gen-1', 'title': '通用'};
    } else if (query.contains('deleteNote(')) {
      calls.add('deleteNote');
      data['deleteNote'] = {'id': variables['id']};
    } else if (query.contains('deleteMoodiaryGeneric(')) {
      calls.add('deleteMoodiaryGeneric');
      data['deleteMoodiaryGeneric'] = {'id': variables['id']};
    } else if (query.contains('deleteNoteTarget(')) {
      calls.add('deleteNoteTarget');
      data['deleteNoteTarget'] = {'id': variables['id']};
    } else if (query.contains('notes(')) {
      data['notes'] = {
        'edges': [
          {'node': {'id': 'note-1', 'title': '远端笔记'}},
        ],
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
      };
    } else if (query.contains('tasks(')) {
      data['tasks'] = {
        'edges': [],
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
      };
    } else if (query.contains('noteTargets(')) {
      data['noteTargets'] = {
        'edges': [
          {
            'node': {
              'id': 'nt-1',
              'noteId': 'note-1',
              'companyId': 'company-1',
              'personId': null,
              'opportunityId': null,
            },
          },
        ],
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
      };
    }

    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

CrmContentSyncService makeService(ContentMockAdapter adapter) {
  const config = TwentyConfig(baseUrl: 'http://test', apiToken: 't');
  final dio = Dio(BaseOptions(baseUrl: config.baseUrl))
    ..httpClientAdapter = adapter;
  return CrmContentSyncService(
    client: TwentyApiClient(
      config: config,
      dio: dio,
      backoffDelay: (_) => Duration.zero,
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDb();
  });

  tearDown(() {
    closeTestDb(db);
  });

  group('CrmContentLink 模型', () {
    test('序列化往返一致', () {
      final link = CrmContentLink()
        ..localType = CrmContentLink.localTypeDiary
        ..localId = 'd1'
        ..remoteType = CrmContentLink.remoteTypeNote
        ..remoteId = 'n1'
        ..targetType = 'company'
        ..targetId = 'c1'
        ..status = CrmContentLink.statusLinked;
      final restored = CrmContentLink.fromJson(link.toJson());
      expect(restored.id, link.id);
      expect(restored.localType, 'diary');
      expect(restored.remoteId, 'n1');
      expect(restored.targetType, 'company');
      expect(restored.isLinked, isTrue);
    });

    test('本地映射唯一键可重复 upsert', () async {
      final adapter = ContentMockAdapter();
      final service = makeService(adapter);
      final diary = Diary()
        ..id = 'diary-1'
        ..type = 'markdown'
        ..title = '拜访 Notion'
        ..contentText = '与 Notion 沟通需求'
        ..time = DateTime(2026, 8, 22)
        ..lastModified = DateTime(2026, 8, 22);
      await IsarUtil.insertADiary(diary);
      await IsarUtil.upsertCrmEntities([
        CrmEntityCache()
          ..twentyId = 'company-1'
          ..entityType = 'company'
          ..name = 'Notion',
      ]);

      final first = await service.pushDiary(diary);
      final second = await service.pushDiary(diary);

      expect(first.remoteId, second.remoteId);
      expect(adapter.calls.where((c) => c == 'createNote').length, 1);
      expect(first.isLinked, isTrue);
      expect(first.targetId, 'company-1');
    });
  });

  group('CrmContentSyncService.pushDiary', () {
    test('匹配到客户 → 创建 note + noteTarget（客户时间线）', () async {
      final adapter = ContentMockAdapter();
      final service = makeService(adapter);
      await IsarUtil.upsertCrmEntities([
        CrmEntityCache()
          ..twentyId = 'company-1'
          ..entityType = 'company'
          ..name = 'Acme',
        CrmEntityCache()
          ..twentyId = 'person-1'
          ..entityType = 'person'
          ..name = '张三',
      ]);
      final diary = Diary()
        ..id = 'd1'
        ..type = 'markdown'
        ..title = 'Acme 周会纪要'
        ..contentText = '与 Acme 讨论新版本'
        ..time = DateTime(2026, 8, 22)
        ..lastModified = DateTime(2026, 8, 22);

      final link = await service.pushDiary(diary);

      expect(link.status, CrmContentLink.statusLinked);
      expect(link.remoteType, CrmContentLink.remoteTypeNote);
      expect(link.targetType, 'company');
      expect(link.targetId, 'company-1');
      expect(adapter.calls, containsAll(['createNote', 'createNoteTarget']));
    });

    test('无匹配 + 通用对象存在 → 写入 moodiaryGeneric', () async {
      final adapter = ContentMockAdapter(genericExists: true);
      final service = makeService(adapter);
      final diary = Diary()
        ..id = 'd2'
        ..type = 'markdown'
        ..title = '灵感片段'
        ..contentText = '无客户关联的内容'
        ..time = DateTime(2026, 8, 22)
        ..lastModified = DateTime(2026, 8, 22);

      final link = await service.pushDiary(diary);

      expect(link.remoteType, CrmContentLink.remoteTypeGeneric);
      expect(link.status, CrmContentLink.statusGeneric);
      expect(link.isGeneric, isTrue);
      expect(adapter.calls, contains('createMoodiaryGeneric'));
      expect(adapter.calls, isNot(contains('createNote')));
    });

    test('无匹配 + 通用对象缺失 → 回退无 target 标准 note', () async {
      final adapter = ContentMockAdapter(genericExists: false);
      final service = makeService(adapter);
      final diary = Diary()
        ..id = 'd3'
        ..type = 'markdown'
        ..title = '普通日记'
        ..contentText = '内容'
        ..time = DateTime(2026, 8, 22)
        ..lastModified = DateTime(2026, 8, 22);

      final link = await service.pushDiary(diary);

      expect(link.remoteType, CrmContentLink.remoteTypeNote);
      expect(link.status, CrmContentLink.statusGeneric);
      expect(link.targetId, isEmpty);
      expect(adapter.calls, contains('createNote'));
      expect(adapter.calls, isNot(contains('createMoodiaryGeneric')));
    });
  });

  group('CrmContentSyncService.pushTodoBlock', () {
    test('显式指定客户 → 创建 task + taskTarget', () async {
      final adapter = ContentMockAdapter();
      final service = makeService(adapter);
      await IsarUtil.upsertCrmEntities([
        CrmEntityCache()
          ..twentyId = 'company-9'
          ..entityType = 'company'
          ..name = 'Beta',
      ]);
      final diary = Diary()
        ..id = 'd-todo'
        ..type = 'markdown'
        ..title = '待办日记'
        ..time = DateTime(2026, 8, 22)
        ..lastModified = DateTime(2026, 8, 22);
      await IsarUtil.insertADiary(diary);
      final block = Block()
        ..id = 'block-1'
        ..diaryId = diary.id
        ..blockType = BlockType.todo
        ..content = '- [ ] 跟进报价\n- [x] 确认到货';
      await IsarUtil.insertBlock(block);

      final link = await service.pushTodoBlock(
        block,
        targetEntityType: 'company',
        targetId: 'company-9',
      );

      expect(link.remoteType, CrmContentLink.remoteTypeTask);
      expect(link.isLinked, isTrue);
      expect(adapter.calls, containsAll(['createTask', 'createTaskTarget']));
    });
  });

  group('CrmContentSyncService.claimAssociation', () {
    test('通用记录认领 → 升级为 note + target 并删除通用记录', () async {
      final adapter = ContentMockAdapter();
      final service = makeService(adapter);
      await IsarUtil.upsertCrmEntities([
        CrmEntityCache()
          ..twentyId = 'company-5'
          ..entityType = 'company'
          ..name = 'Gamma',
      ]);
      final diary = Diary()
        ..id = 'd-claim'
        ..type = 'markdown'
        ..title = '认领测试'
        ..contentText = '内容'
        ..time = DateTime(2026, 8, 22)
        ..lastModified = DateTime(2026, 8, 22);
      await IsarUtil.insertADiary(diary);
      final link = CrmContentLink()
        ..localType = CrmContentLink.localTypeDiary
        ..localId = diary.id
        ..remoteType = CrmContentLink.remoteTypeGeneric
        ..remoteId = 'gen-1'
        ..status = CrmContentLink.statusGeneric;
      await IsarUtil.upsertCrmContentLinks([link]);

      final updated = await service.claimAssociation(
        link,
        targetEntityType: 'company',
        targetId: 'company-5',
      );

      expect(updated.remoteType, CrmContentLink.remoteTypeNote);
      expect(updated.isLinked, isTrue);
      expect(updated.targetId, 'company-5');
      expect(
        adapter.calls,
        containsAll(['createNote', 'createNoteTarget', 'deleteMoodiaryGeneric']),
      );
    });
  });

  group('CrmContentSyncService.removeAssociation', () {
    test('删除匹配的 noteTarget 并回到未认领状态', () async {
      final adapter = ContentMockAdapter();
      final service = makeService(adapter);
      final link = CrmContentLink()
        ..localType = CrmContentLink.localTypeDiary
        ..localId = 'd-x'
        ..remoteType = CrmContentLink.remoteTypeNote
        ..remoteId = 'note-1'
        ..targetType = 'company'
        ..targetId = 'company-1'
        ..status = CrmContentLink.statusLinked;
      await IsarUtil.upsertCrmContentLinks([link]);

      final updated = await service.removeAssociation(link);

      expect(updated.status, CrmContentLink.statusGeneric);
      expect(updated.targetId, isEmpty);
      expect(adapter.calls, contains('deleteNoteTarget'));
    });
  });

  group('CrmContentSyncService 其它', () {
    test('拉取 Twenty 笔记/待办写入本地缓存', () async {
      final adapter = ContentMockAdapter();
      final service = makeService(adapter);
      final result = await service.pullRemoteContent();
      expect(result.totalPulled, 1);
      final notes = await IsarUtil.getCrmEntitiesByType('note');
      expect(notes, hasLength(1));
      expect(notes.first.name, '远端笔记');
    });

    test('matchEntity 公司优先于联系人', () async {
      final service = makeService(ContentMockAdapter());
      await IsarUtil.upsertCrmEntities([
        CrmEntityCache()
          ..twentyId = 'company-1'
          ..entityType = 'company'
          ..name = 'Acme',
        CrmEntityCache()
          ..twentyId = 'person-1'
          ..entityType = 'person'
          ..name = '张三',
      ]);
      final target = await service.matchEntity('与 Acme 的张三沟通');
      expect(target?.type, 'company');
      expect(target?.id, 'company-1');
    });
  });
}
