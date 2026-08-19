import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/debounce.dart';
import 'package:moodiary/features/crm/twenty_api.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';

/// 可编程 Mock HTTP 适配器
class MockAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

TwentyApiClient makeClient(
  MockAdapter adapter, {
  SyncLogService? log,
}) {
  const config = TwentyConfig(
    baseUrl: 'http://test',
    apiToken: 'token',
  );
  final dio = Dio(
    BaseOptions(baseUrl: config.baseUrl),
  )..httpClientAdapter = adapter;
  return TwentyApiClient(
    config: config,
    log: log ?? SyncLogService.instance,
    dio: dio,
    backoffDelay: (_) => Duration.zero,
  );
}

void main() {
  group('TwentyApiClient.graphql', () {
    test('解析正常响应', () async {
      final client = makeClient(
        MockAdapter(
          (_) => jsonBody({
            'data': {
              'companies': {
                'edges': [
                  {
                    'node': {'id': 'c1', 'name': 'Notion'},
                  },
                ],
                'pageInfo': {'hasNextPage': false, 'endCursor': null},
              },
            },
          }),
        ),
      );
      final data = await client.graphql('query { companies { edges { node { id name } } } }');
      final edges = (data['companies'] as Map<String, dynamic>)['edges'] as List;
      expect(edges, hasLength(1));
      expect((edges.first as Map<String, dynamic>)['node']['name'], 'Notion');
    });

    test('GraphQL errors 抛异常', () async {
      final client = makeClient(
        MockAdapter(
          (_) => jsonBody({
            'errors': [
              {'message': 'Forbidden'},
            ],
          }),
        ),
      );
      expect(
        () => client.graphql('query { companies { edges { node { id } } } }'),
        throwsA(
          isA<TwentyApiException>().having(
            (e) => e.graphQlErrors,
            'graphQlErrors',
            contains('Forbidden'),
          ),
        ),
      );
    });

    test('429 触发指数退避重试后成功', () async {
      var calls = 0;
      final client = makeClient(
        MockAdapter(
          (_) {
            calls++;
            if (calls == 1) {
              return jsonBody({'message': 'Too Many Requests'}, status: 429);
            }
            return jsonBody({
              'data': {
                'companies': {
                  'edges': [],
                  'pageInfo': {'hasNextPage': false},
                },
              },
            });
          },
        ),
      );
      final data = await client.graphql('query { companies { edges { node { id } } } }');
      expect(calls, 2);
      expect(data, containsPair('companies', isNotNull));
    });

    test('500 重试耗尽后抛异常', () async {
      var calls = 0;
      final client = makeClient(
        MockAdapter(
          (_) {
            calls++;
            return jsonBody({'message': 'boom'}, status: 500);
          },
        ),
      );
      await expectLater(
        client.graphql('query { companies { edges { node { id } } } }'),
        throwsA(isA<TwentyApiException>()),
      );
      expect(calls, 5); // 1 次初始 + 4 次重试（maxAttempts=5 内尝试）
    });

    test('4xx 非重试错误立即失败', () async {
      var calls = 0;
      final client = makeClient(
        MockAdapter(
          (_) {
            calls++;
            return jsonBody({'message': 'Bad Request'}, status: 400);
          },
        ),
      );
      await expectLater(
        client.graphql('query { companies { edges { node { id } } } }'),
        throwsA(isA<TwentyApiException>()),
      );
      expect(calls, 1);
    });
  });

  group('TwentyApiClient.listAll', () {
    test('跨页合并结果', () async {
      var pages = 0;
      final client = makeClient(
        MockAdapter(
          (_) {
            pages++;
            if (pages == 1) {
              return jsonBody({
                'data': {
                  'companies': {
                    'edges': [
                      {
                        'node': {'id': 'c1', 'name': 'A'},
                      },
                    ],
                    'pageInfo': {
                      'hasNextPage': true,
                      'endCursor': 'cursor-1',
                    },
                  },
                },
              });
            }
            return jsonBody({
              'data': {
                'companies': {
                  'edges': [
                    {
                      'node': {'id': 'c2', 'name': 'B'},
                    },
                  ],
                  'pageInfo': {'hasNextPage': false, 'endCursor': null},
                },
              },
            });
          },
        ),
      );
      final items = await client.listAll(object: 'company');
      expect(items, hasLength(2));
      expect(items.map((e) => e.id), containsAll(['c1', 'c2']));
      expect(pages, 2);
    });
  });

  group('TwentyApiClient.create/update/delete', () {
    test('create 返回实体', () async {
      final client = makeClient(
        MockAdapter(
          (_) => jsonBody({
            'data': {
              'createCompany': {'id': 'new-1', 'name': '新公司'},
            },
          }),
        ),
      );
      final entity = await client.create(
        object: 'company',
        data: {'name': '新公司'},
      );
      expect(entity.id, 'new-1');
      expect(entity.data['name'], '新公司');
    });

    test('delete 返回 id', () async {
      final client = makeClient(
        MockAdapter(
          (_) => jsonBody({
            'data': {
              'deleteCompany': {'id': 'del-1'},
            },
          }),
        ),
      );
      final id = await client.delete(object: 'company', id: 'del-1');
      expect(id, 'del-1');
    });
  });

  group('Debouncer', () {
    test('2 秒内合并多次调用', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var calls = 0;
      for (var i = 0; i < 5; i++) {
        debouncer.schedule(() async {
          calls++;
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(calls, 1);
      expect(debouncer.isPending, isFalse);
    });
  });

  group('SyncLogService', () {
    test('内存环形缓冲保留最近 500 条', () async {
      final log = SyncLogService.instance;
      for (var i = 0; i < 510; i++) {
        await log.write(
          level: SyncLogLevel.info,
          operation: 'test',
          target: 'x',
          detail: 'entry-$i',
        );
      }
      expect(log.entries.length, 500);
      expect(log.entries.first.detail, 'entry-10');
    });

    test('级别与时间过滤', () async {
      final log = SyncLogService.instance;
      final before = DateTime.now();
      await log.write(
        level: SyncLogLevel.error,
        operation: 'pull',
        target: 'company',
        detail: '错误',
      );
      final errors = log.query(levels: {SyncLogLevel.error}, from: before);
      expect(errors, isNotEmpty);
      expect(errors.last.detail, '错误');
    });
  });
}
