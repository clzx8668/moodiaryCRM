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

/// GraphQL 类型字段信息（introspection）
class TwentyFieldInfo {
  final String name;
  final String type;
  final String kind;

  const TwentyFieldInfo({
    required this.name,
    required this.type,
    required this.kind,
  });
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

  /// 探测对象类型是否存在（标准对象 note/task 或自定义对象 moodiaryGeneric 等）。
  /// 通过 GraphQL introspection `__type` 判断，不存在的类型返回 false。
  /// 自定义对象在标准 API 中类型名为首字母大写（如 MoodiaryGeneric），
  /// 因此同时探测原始名与首字母大写名。
  Future<bool> typeExists(String typeName) async {
    for (final candidate in {typeName, _capitalize(typeName)}) {
      final data = await graphql(
        'query TypeExists { __type(name: "$candidate") { name } }',
      );
      if (data['__type'] is Map<String, dynamic>) return true;
    }
    return false;
  }

  /// 拉取对象的 GraphQL 字段清单（权威字段来源；metadata 缓存偶发缺失字段）。
  /// [typeName] 为 GraphQL 类型名（首字母大写，如 Company / MoodiaryGeneric）。
  Future<List<TwentyFieldInfo>> typeFields(String typeName) async {
    final data = await graphql(
      '''
query TypeFields {
  __type(name: "$typeName") {
    fields {
      name
      type { name kind ofType { name kind } }
    }
  }
}''',
    );
    final fields = (data['__type'] as Map<String, dynamic>?)?['fields'] as List?;
    if (fields == null) return const [];
    final result = <TwentyFieldInfo>[];
    for (final raw in fields) {
      final field = raw as Map<String, dynamic>;
      var type = (field['type'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
      var kind = (field['type'] as Map<String, dynamic>?)?['kind']?.toString() ?? '';
      if (kind == 'NON_NULL') {
        final inner = (field['type'] as Map<String, dynamic>?)?['ofType']
            as Map<String, dynamic>?;
        type = inner?['name']?.toString() ?? type;
        kind = inner?['kind']?.toString() ?? kind;
      }
      result.add(
        TwentyFieldInfo(
          name: field['name'] as String,
          type: type,
          kind: kind,
        ),
      );
    }
    return result;
  }

  /// Metadata API 通用调用（对象/字段元数据管理）。
  /// 端点优先 `/metadata`，部分 Twenty 版本为 `/metadata/graphql`（404 时回退）。
  Future<Map<String, dynamic>> metadataGraphql(
    String query, [
    Map<String, dynamic>? variables,
  ]) async {
    for (final path in const ['/metadata', '/metadata/graphql']) {
      try {
        final response = await _requestWithRetry(
          () => _dio.post<dynamic>(
            path,
            data: {
              'query': query,
              if (variables != null) 'variables': variables,
            },
          ),
          operation: 'metadata',
          target: path,
        );
        final body = response.data;
        if (body is! Map<String, dynamic>) {
          throw const TwentyApiException('Metadata 响应格式异常');
        }
        final errors = body['errors'];
        if (errors != null && errors is List && errors.isNotEmpty) {
          final messages = errors
              .map(
                (e) =>
                    (e as Map<String, dynamic>)['message']?.toString() ?? '',
              )
              .where((m) => m.isNotEmpty)
              .toList();
          throw TwentyApiException(
            'Metadata 返回错误',
            graphQlErrors: messages,
          );
        }
        final data = body['data'];
        if (data is! Map<String, dynamic>) {
          throw const TwentyApiException('Metadata 无 data 字段');
        }
        return data;
      } on TwentyApiException catch (e) {
        if (path == '/metadata' &&
            e.statusCode == 404 &&
            (e.graphQlErrors?.isEmpty ?? true)) {
          continue; // 端点不存在 → 尝试 /metadata/graphql
        }
        rethrow;
      }
    }
    throw const TwentyApiException('Metadata 端点不可用');
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

  // ==================== 笔记 / 待办 / 关联目标（内容同步） ====================

  /// 创建笔记（Twenty `note`）。body 走 bodyV2.markdown 投影，兼容 Markdown 内容。
  Future<TwentyEntity> createNote({
    required String title,
    String? body,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      if (body != null && body.isNotEmpty)
        'bodyV2': {
          'blocknote': null,
          'markdown': body,
        },
    };
    return create(object: 'note', data: data, fields: ['id', 'title', 'bodyV2']);
  }

  /// 更新笔记
  Future<TwentyEntity> updateNote({
    required String id,
    String? title,
    String? body,
  }) async {
    final data = <String, dynamic>{
      if (title != null) 'title': title,
      if (body != null)
        'bodyV2': {
          'blocknote': null,
          'markdown': body,
        },
    };
    return update(
      object: 'note',
      id: id,
      data: data,
      fields: ['id', 'title', 'bodyV2'],
    );
  }

  /// 创建笔记关联目标（noteTarget → 客户时间线）。target 至少填一个。
  Future<TwentyEntity> createNoteTarget({
    required String noteId,
    String? companyId,
    String? personId,
    String? opportunityId,
  }) async {
    final data = <String, dynamic>{
      'noteId': noteId,
      if (companyId != null) 'targetCompanyId': companyId,
      if (personId != null) 'targetPersonId': personId,
      if (opportunityId != null) 'targetOpportunityId': opportunityId,
    };
    return create(
      object: 'noteTarget',
      data: data,
      fields: [
        'id',
        'noteId',
        'targetCompanyId',
        'targetPersonId',
        'targetOpportunityId',
      ],
    );
  }

  /// 创建待办（Twenty `task`）
  Future<TwentyEntity> createTask({
    required String title,
    String? body,
    DateTime? dueAt,
    String? status,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      if (body != null && body.isNotEmpty)
        'bodyV2': {
          'blocknote': null,
          'markdown': body,
        },
      if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    return create(
      object: 'task',
      data: data,
      fields: ['id', 'title', 'dueAt', 'status'],
    );
  }

  /// 更新待办
  Future<TwentyEntity> updateTask({
    required String id,
    String? title,
    String? body,
    DateTime? dueAt,
    String? status,
  }) async {
    final data = <String, dynamic>{
      if (title != null) 'title': title,
      if (body != null)
        'bodyV2': {
          'blocknote': null,
          'markdown': body,
        },
      if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
      if (status != null) 'status': status,
    };
    return update(
      object: 'task',
      id: id,
      data: data,
      fields: ['id', 'title', 'dueAt', 'status'],
    );
  }

  /// 创建待办关联目标（taskTarget → 客户时间线）
  Future<TwentyEntity> createTaskTarget({
    required String taskId,
    String? companyId,
    String? personId,
    String? opportunityId,
  }) async {
    final data = <String, dynamic>{
      'taskId': taskId,
      if (companyId != null) 'targetCompanyId': companyId,
      if (personId != null) 'targetPersonId': personId,
      if (opportunityId != null) 'targetOpportunityId': opportunityId,
    };
    return create(
      object: 'taskTarget',
      data: data,
      fields: [
        'id',
        'taskId',
        'targetCompanyId',
        'targetPersonId',
        'targetOpportunityId',
      ],
    );
  }

  /// 拉取笔记列表（含关联目标摘要，用于展示/对账）
  Future<List<TwentyEntity>> listNotes({
    List<String> fields = const ['id', 'title', 'bodyV2', 'createdAt'],
    int pageSize = 100,
  }) {
    return listAll(
      object: 'note',
      fields: fields,
      pageSize: pageSize,
    );
  }

  /// 拉取待办列表（含状态/到期日）
  Future<List<TwentyEntity>> listTasks({
    List<String> fields = const [
      'id',
      'title',
      'bodyV2',
      'dueAt',
      'status',
      'createdAt',
    ],
    int pageSize = 100,
  }) {
    return listAll(
      object: 'task',
      fields: fields,
      pageSize: pageSize,
    );
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
      'contractsHeTongGuanLi': 'contractsHeTongGuanLi',
      'paymentsHuiKuanJiLu': 'paymentsHuiKuanJiLu',
      'invoiceFaPiao': 'invoiceFaPiao',
      'commissionsTiChengJieSuan': 'commissionsTiChengJieSuan',
    };
    return irregular[object] ?? '${object}s';
  }
}
