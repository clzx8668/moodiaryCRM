import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/tool_executor.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_write_service.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;
  late CrmLocalRepository repo;

  setUp(() {
    db = openTestDb();
    repo = CrmLocalRepository(db);
  });

  tearDown(() {
    closeTestDb(db);
  });

  group('CrmWriteService.buildProposal', () {
    test('创建：缺 object 报参数错误', () async {
      expect(
        CrmWriteService.buildProposal(action: 'create', args: {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('创建：缺 fields 报参数错误', () async {
      expect(
        CrmWriteService.buildProposal(
          action: 'create',
          args: {'object': 'account'},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('更新：缺 id 报参数错误', () async {
      expect(
        CrmWriteService.buildProposal(
          action: 'update',
          args: {'object': 'account', 'fields': {'name': '新名字'}},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('删除：缺 id 报参数错误', () async {
      expect(
        CrmWriteService.buildProposal(
          action: 'delete',
          args: {'object': 'account'},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CrmWriteService.execute', () {
    test('创建 → 更新 → 删除全链路落库（软删除）', () async {
      final create = await CrmWriteService.buildProposal(
        action: 'create',
        args: {
          'object': 'account',
          'fields': {'name': '星河科技', 'industry': '软件'},
        },
      );
      final created = await CrmWriteService.execute(create);
      expect(created, contains('星河科技'));

      final list = await repo.listAccounts();
      expect(list, hasLength(1));
      final id = list.first.id;

      final update = await CrmWriteService.buildProposal(
        action: 'update',
        args: {
          'object': 'account',
          'id': id,
          'fields': {'phone': '13800000000'},
        },
      );
      await CrmWriteService.execute(update);
      expect((await repo.getAccount(id))?.phone, '13800000000');

      final del = await CrmWriteService.buildProposal(
        action: 'delete',
        args: {'object': 'account', 'id': id},
      );
      await CrmWriteService.execute(del);
      expect(await repo.listAccounts(), isEmpty);
    });

    test('更新不存在的记录抛错', () async {
      final p = await CrmWriteService.buildProposal(
        action: 'update',
        args: {
          'object': 'account',
          'id': 'not-exist',
          'fields': {'name': 'x'},
        },
      );
      expect(CrmWriteService.execute(p), throwsA(isA<StateError>()));
    });
  });

  group('ToolExecutor crm 写工具', () {
    test('未注册确认回调时拒绝执行且不落库', () async {
      final executor = ToolExecutor();
      final result = await executor.execute(
        const AiToolCall(
          id: '1',
          name: 'crm_create',
          arguments: '{"object":"account","fields":{"name":"测试"}}',
        ),
      );
      expect(result, contains('需要用户确认'));
      expect(await repo.listAccounts(), isEmpty);
    });

    test('确认回调返回 false 时取消且不落库', () async {
      final executor = ToolExecutor()
        ..onCrmWriteConfirm = (_) async => false;
      final result = await executor.execute(
        const AiToolCall(
          id: '2',
          name: 'crm_create',
          arguments: '{"object":"account","fields":{"name":"测试"}}',
        ),
      );
      expect(result, contains('取消'));
      expect(await repo.listAccounts(), isEmpty);
    });

    test('确认回调返回 true 时执行并落库', () async {
      final executor = ToolExecutor()
        ..onCrmWriteConfirm = (_) async => true;
      final result = await executor.execute(
        const AiToolCall(
          id: '3',
          name: 'crm_create',
          arguments: '{"object":"account","fields":{"name":"测试公司"}}',
        ),
      );
      expect(result, contains('测试公司'));
      expect(await repo.listAccounts(), hasLength(1));
    });
  });
}
