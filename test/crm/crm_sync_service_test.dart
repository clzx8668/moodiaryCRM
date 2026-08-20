import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/crm_sync_service.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/twenty_api.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

class MockAdapter implements HttpClientAdapter {
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
    final data = <String, dynamic>{};
    if (query.contains('companies')) {
      data['companies'] = {
        'edges': [
          {'node': {'id': 'c1', 'name': 'A'}},
          {'node': {'id': 'c2', 'name': 'B'}},
        ],
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
      };
    } else if (query.contains('people')) {
      data['people'] = {
        'edges': [],
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
      };
    } else if (query.contains('opportunities')) {
      data['opportunities'] = {
        'edges': [],
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
      };
    } else if (query.contains('tasks')) {
      data['tasks'] = {
        'edges': [],
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

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDb();
  });

  tearDown(() {
    closeTestDb(db);
  });

  test('reconcile 找出远端缺失与本地过期实体', () async {
    // 本地缓存：c2 与远端一致，c3 为本地独有
    await IsarUtil.upsertCrmEntities([
      CrmEntityCache()
        ..twentyId = 'c2'
        ..entityType = 'company'
        ..name = 'B',
      CrmEntityCache()
        ..twentyId = 'c3'
        ..entityType = 'company'
        ..name = 'Stale',
    ]);

    const config = TwentyConfig(baseUrl: 'http://test', apiToken: 't');
    final dio = Dio(BaseOptions(baseUrl: config.baseUrl))
      ..httpClientAdapter = MockAdapter();
    final service = CrmSyncService(
      client: TwentyApiClient(
        config: config,
        dio: dio,
        backoffDelay: (_) => Duration.zero,
      ),
    );

    final result = await service.reconcile();

    expect(result.missingLocal['company'], ['c1']);
    expect(result.staleLocal['company'], ['c3']);
    expect(result.totalDiff, 2);
  });

  test('reconcile 一致时无差异', () async {
    await IsarUtil.upsertCrmEntities([
      CrmEntityCache()
        ..twentyId = 'c1'
        ..entityType = 'company'
        ..name = 'A',
      CrmEntityCache()
        ..twentyId = 'c2'
        ..entityType = 'company'
        ..name = 'B',
    ]);

    const config = TwentyConfig(baseUrl: 'http://test', apiToken: 't');
    final dio = Dio(BaseOptions(baseUrl: config.baseUrl))
      ..httpClientAdapter = MockAdapter();
    final service = CrmSyncService(
      client: TwentyApiClient(
        config: config,
        dio: dio,
        backoffDelay: (_) => Duration.zero,
      ),
    );

    final result = await service.reconcile();
    expect(result.totalDiff, 0);
    expect(result.missingLocal, isEmpty);
    expect(result.staleLocal, isEmpty);
  });
}
