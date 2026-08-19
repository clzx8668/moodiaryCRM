import 'dart:async';

import 'package:dio/dio.dart';
import 'package:moodiary/features/crm/twenty_config.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';

/// Twenty API 异常
class TwentyApiException implements Exception {
  final String message;
  final int? statusCode;
  final List<String>? graphQlErrors;

  const TwentyApiException(
    this.message, {
    this.statusCode,
    this.graphQlErrors,
  });

  @override
  String toString() {
    final buffer = StringBuffer('TwentyApiException: $message');
    if (statusCode != null) buffer.write(' (HTTP $statusCode)');
    if (graphQlErrors != null && graphQlErrors!.isNotEmpty) {
      buffer.write(' GraphQL: ${graphQlErrors!.join('; ')}');
    }
    return buffer.toString();
  }
}

/// Twenty GraphQL 实体
class TwentyEntity {
  final String id;
  final Map<String, dynamic> data;

  const TwentyEntity({required this.id, required this.data});
}

/// 分页结果
class TwentyPage {
  final List<TwentyEntity> items;
  final bool hasNextPage;
  final String? endCursor;

  const TwentyPage({
    required this.items,
    required this.hasNextPage,
    this.endCursor,
  });
}

/// Twenty CRM API 客户端（GraphQL + 指数退避重试）
///
/// 对齐架构文档 4.8/4.9：
/// - 429/5xx/网络错误 → 指数退避重试（2s 起、×2、上限 60s、最多 5 次）；
/// - 读多写少数据走本地缓存，后台增量刷新。
class TwentyApiClient {
  final TwentyConfig config;
  final SyncLogService log;
  final Dio _dio;

  /// 可注入的退避延迟（测试用），默认 2s×2^n
  final Duration Function(int attempt)? backoffDelay;

  TwentyApiClient({
    required this.config,
    SyncLogService? log,
    Dio? dio,
    this.backoffDelay,
  }) : log = log ?? SyncLogService.instance,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: config.baseUrl,
               connectTimeout: Duration(seconds: config.timeoutSeconds),
               receiveTimeout: Duration(seconds: config.timeoutSeconds),
               headers: {
                 'Authorization': 'Bearer ${config.apiToken}',
                 'Content-Type': 'application/json',
               },
             ),
           );

  bool get isConfigured => config.isConfigured;

  Duration _delayFor(int attempt) {
    if (backoffDelay != null) return backoffDelay!(attempt);
    // 2s, 4s, 8s, 16s, 32s（上限 60s 由最大次数 5 保证）
    final ms = 2000 * (1 << (attempt - 1));
    return Duration(milliseconds: ms.clamp(1, 60000));
  }

  bool _isRetryable(DioException e) {
    final status = e.response?.statusCode;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        status == 429 ||
        (status != null && status >= 500);
  }

  Future<Response<dynamic>> _requestWithRetry(
    Future<Response<dynamic>> Function() request, {
    required String operation,
    required String target,
  }) async {
    const maxAttempts = 5;
    DioException? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await request();
      } on DioException catch (e) {
        lastError = e;
        if (!_isRetryable(e) || attempt == maxAttempts) {
          throw TwentyApiException(
            '请求失败：${e.message}',
            statusCode: e.response?.statusCode,
          );
        }
        final delayMs = _delayFor(attempt).inMilliseconds;
        await log.write(
          level: SyncLogLevel.warn,
          operation: operation,
          target: target,
          detail: '第 $attempt 次请求失败，$delayMs ms 后重试',
          error: e.message,
        );
        await Future<void>.delayed(_delayFor(attempt));
      }
    }
    throw TwentyApiException('请求失败：$lastError');
  }

  /// 健康检查
  Future<bool> ping() async {
    final response = await _requestWithRetry(
      () => _dio.get<dynamic>('/healthz'),
      operation: 'test',
      target: 'server',
    );
    return response.statusCode == 200;
  }

  /// 通用 GraphQL 查询/变更
  Future<Map<String, dynamic>> graphql(
    String query, [
    Map<String, dynamic>? variables,
  ]) async {
    final response = await _requestWithRetry(
      () => _dio.post<dynamic>(
        '/graphql',
        data: {
          'query': query,
          if (variables != null) 'variables': variables,
        },
      ),
      operation: 'graphql',
      target: 'api',
    );

    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const TwentyApiException('GraphQL 响应格式异常');
    }
    final errors = body['errors'];
    if (errors != null && errors is List && errors.isNotEmpty) {
      final messages = errors
          .map((e) => (e as Map<String, dynamic>)['message']?.toString() ?? '')
          .where((m) => m.isNotEmpty)
          .toList();
      throw TwentyApiException(
        'GraphQL 返回错误',
        graphQlErrors: messages,
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const TwentyApiException('GraphQL 无 data 字段');
    }
    return data;
  }

  /// 分页拉取一个对象的所有记录
  Future<List<TwentyEntity>> listAll({
    required String object,
    List<String> fields = const ['id', 'name'],
    int pageSize = 100,
    Map<String, dynamic>? filter,
  }) async {
    final results = <TwentyEntity>[];
    String? after;
    do {
      final page = await _listPage(
        object: object,
        fields: fields,
        pageSize: pageSize,
        after: after,
        filter: filter,
      );
      results.addAll(page.items);
      after = page.hasNextPage ? page.endCursor : null;
    } while (after != null);
    return results;
  }

  Future<TwentyPage> _listPage({
    required String object,
    required List<String> fields,
    required int pageSize,
    String? after,
    Map<String, dynamic>? filter,
  }) async {
    // Twenty GraphQL 列表字段为复数（person → people 等不规则）
    final fieldName = _pluralFieldName(object);
    final fieldList = fields.toSet().toList();
    if (!fieldList.contains('id')) fieldList.insert(0, 'id');
    final filterArg = filter == null ? '' : ', filter: \$filter';
    final query = '''
query List$object(\$first: Int!, \$after: String${
      filter == null ? '' : ', \$filter: JSON'
    }) {
  $fieldName(first: \$first, after: \$after$filterArg) {
    edges {
      node {
        ${fieldList.join('\n        ')}
      }
    }
    pageInfo {
      endCursor
      hasNextPage
    }
  }
}''';

    final data = await graphql(
      query,
      {
        'first': pageSize,
        'after': after,
        if (filter != null) 'filter': filter,
      },
    );
    final objectData = data[fieldName] as Map<String, dynamic>?;
    if (objectData == null) {
      throw TwentyApiException('GraphQL 响应缺少对象 $fieldName');
    }
    final edges = (objectData['edges'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final items = edges.map((edge) {
      final node = edge['node'] as Map<String, dynamic>;
      final id = node['id']?.toString() ?? '';
      return TwentyEntity(id: id, data: node);
    }).toList();
    final pageInfo =
        (objectData['pageInfo'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    return TwentyPage(
      items: items,
      hasNextPage: pageInfo['hasNextPage'] as bool? ?? false,
      endCursor: pageInfo['endCursor'] as String?,
    );
  }

  /// 创建实体（对象名：company/person/opportunity/task）
  Future<TwentyEntity> create({
    required String object,
    required Map<String, dynamic> data,
    List<String> fields = const ['id', 'name'],
  }) async {
    final className = _capitalize(object);
    final fieldList = fields.toSet().toList();
    if (!fieldList.contains('id')) fieldList.insert(0, 'id');
    final query = '''
mutation Create$className(\$data: ${className}CreateInput!) {
  create$className(data: \$data) {
    ${fieldList.join('\n    ')}
  }
}''';
    final result = await graphql(query, {'data': data});
    final created = result['create$className'];
    if (created is! Map<String, dynamic>) {
      throw const TwentyApiException('创建失败：响应缺少创建结果');
    }
    return TwentyEntity(
      id: created['id']?.toString() ?? '',
      data: created,
    );
  }

  /// 更新实体
  Future<TwentyEntity> update({
    required String object,
    required String id,
    required Map<String, dynamic> data,
    List<String> fields = const ['id', 'name'],
  }) async {
    final className = _capitalize(object);
    final fieldList = fields.toSet().toList();
    if (!fieldList.contains('id')) fieldList.insert(0, 'id');
    final query = '''
mutation Update$className(\$id: ID!, \$data: ${className}UpdateInput!) {
  update$className(id: \$id, data: \$data) {
    ${fieldList.join('\n    ')}
  }
}''';
    final result = await graphql(query, {'id': id, 'data': data});
    final updated = result['update$className'];
    if (updated is! Map<String, dynamic>) {
      throw const TwentyApiException('更新失败：响应缺少更新结果');
    }
    return TwentyEntity(
      id: updated['id']?.toString() ?? '',
      data: updated,
    );
  }

  /// 删除实体
  Future<String?> delete({
    required String object,
    required String id,
  }) async {
    final className = _capitalize(object);
    final query = '''
mutation Delete$className(\$id: ID!) {
  delete$className(id: \$id) {
    id
  }
}''';
    final result = await graphql(query, {'id': id});
    final deleted = result['delete$className'];
    return deleted is Map<String, dynamic>
        ? deleted['id']?.toString()
        : null;
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  /// 对象名 → GraphQL 复数列表字段名
  static String _pluralFieldName(String object) {
    const irregular = {
      'person': 'people',
      'company': 'companies',
      'opportunity': 'opportunities',
    };
    return irregular[object] ?? '${object}s';
  }
}
