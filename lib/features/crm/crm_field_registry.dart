import 'dart:convert';

import 'package:moodiary/features/crm/twenty_api.dart';
import 'package:moodiary/persistence/pref.dart';

/// 字段元数据（对应 Twenty metadata Field）
class CrmFieldMeta {
  final String name;
  final String label;
  final String type;
  final bool isSystem;
  final bool isCustom;

  const CrmFieldMeta({
    required this.name,
    required this.label,
    required this.type,
    this.isSystem = false,
    this.isCustom = false,
  });

  bool get isRelation =>
      type == 'RELATION' ||
      type == 'MORPH_RELATION' ||
      type == 'MORPH_RELATION_MANY_TO_ONE' ||
      type == 'MORPH_RELATION_ONE_TO_MANY';

  Map<String, dynamic> toJson() => {
    'name': name,
    'label': label,
    'type': type,
    'isSystem': isSystem,
    'isCustom': isCustom,
  };

  factory CrmFieldMeta.fromJson(Map<String, dynamic> json) => CrmFieldMeta(
    name: json['name'] as String,
    label: json['label'] as String? ?? json['name'] as String,
    type: json['type'] as String? ?? 'TEXT',
    isSystem: json['isSystem'] as bool? ?? false,
    isCustom: json['isCustom'] as bool? ?? false,
  );
}

/// 对象元数据（对应 Twenty metadata Object + Fields）
class CrmObjectMeta {
  final String nameSingular;
  final String namePlural;
  final String labelSingular;

  /// 标签标识字段名（Twenty labelIdentifier，如 company→name / task→title）
  final String labelField;

  final List<CrmFieldMeta> fields;

  const CrmObjectMeta({
    required this.nameSingular,
    required this.namePlural,
    required this.labelSingular,
    required this.labelField,
    required this.fields,
  });

  Map<String, dynamic> toJson() => {
    'nameSingular': nameSingular,
    'namePlural': namePlural,
    'labelSingular': labelSingular,
    'labelField': labelField,
    'fields': fields.map((f) => f.toJson()).toList(),
  };

  factory CrmObjectMeta.fromJson(Map<String, dynamic> json) => CrmObjectMeta(
    nameSingular: json['nameSingular'] as String,
    namePlural: json['namePlural'] as String? ?? '',
    labelSingular: json['labelSingular'] as String? ?? '',
    labelField: json['labelField'] as String? ?? '',
    fields: ((json['fields'] as List?) ?? [])
        .map((e) => CrmFieldMeta.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// 字段注册表：按 Twenty 元数据规则提供对象字段与默认展示列。
///
/// - 对象名映射：应用对象 key（含历史自定义对象名）→ Twenty metadata nameSingular；
/// - 默认列 = 标签标识字段 + 可展示标量字段（按 metadata 顺序，遵循 Twenty 设计）；
/// - 结果缓存到 PrefUtil（`crmFieldMeta_<对象>`），离线/失败时回退缓存。
class CrmFieldRegistry {
  /// 应用对象 key → Twenty metadata nameSingular
  static const Map<String, String> objectMetaName = {
    'company': 'company',
    'person': 'person',
    'opportunity': 'opportunity',
    'task': 'task',
    'note': 'note',
    'moodiaryGeneric': 'moodiaryGeneric',
    'contractsHeTongGuanLi': 'contract',
    'paymentsHuiKuanJiLu': 'payment',
    'invoiceFaPiao': 'invoice',
    'commissionsTiChengJieSuan': 'commission',
  };

  /// metadata 字段列表偶发缺失的已知字段补充（GraphQL 实际可用；
  /// 目前仅 moodiaryGeneric 受 Twenty metadata 缓存怪癖影响）
  static const Map<String, List<CrmFieldMeta>> extraObjectFields = {
    'moodiaryGeneric': [
      CrmFieldMeta(name: 'title', label: 'Title', type: 'TEXT'),
      CrmFieldMeta(name: 'content', label: 'Content', type: 'TEXT'),
      CrmFieldMeta(name: 'sourceType', label: 'Source Type', type: 'SELECT'),
      CrmFieldMeta(name: 'status', label: 'Status', type: 'SELECT'),
    ],
  };

  /// 系统/审计字段（默认不展示）
  static const Set<String> _auditFields = {
    'id',
    'createdAt',
    'updatedAt',
    'deletedAt',
    'createdBy',
    'updatedBy',
    'position',
    'searchVector',
    'attachments',
    'timelineActivities',
    'favorites',
    'avatarFile',
    'noteTargets',
    'taskTargets',
    'people',
    'company',
    'accountOwner',
    'assignee',
  };

  /// 会话级内存缓存（避免每个对象重复拉全量 metadata）
  static final Map<String, CrmObjectMeta> _cache = {};

  /// 默认不拉取/展示的字段类型（复合大字段或系统内部类型）
  static const Set<String> _excludedTypes = {
    'RELATION',
    'MORPH_RELATION',
    'RICH_TEXT',
    'RICH_TEXT_V2',
    'RAW_JSON',
    'TS_VECTOR',
    'POSITION',
    'ACTOR',
  };

  /// 复合标量对象类型（GraphQL schema 形态，可整字段查询并展示）
  static const Set<String> _compositeScalarTypes = {
    'Links',
    'Address',
    'Currency',
    'Emails',
    'Phones',
    'FullName',
    'String',
    'Float',
    'Int',
    'Boolean',
    'DateTime',
    'Date',
    'Number',
    'UUID',
  };

  /// metadata 类型形态（UPPER_SNAKE，如 TEXT/DATE_TIME/RELATION）
  static final RegExp _metaTypePattern = RegExp(r'^[A-Z0-9_]+$');

  /// 拉取对象元数据（网络优先，失败回退本地缓存）。
  static Future<CrmObjectMeta?> fetchObjectMeta(
    TwentyApiClient client,
    String objectKey,
  ) async {
    final cachedMeta = _cache[objectKey];
    if (cachedMeta != null) return cachedMeta;
    final metaName = objectMetaName[objectKey];
    final cacheKey = 'crmFieldMeta_$objectKey';
    if (metaName == null) return null;
    try {
      final data = await client.metadataGraphql(
        '''
query ListObjects {
  objects(paging: { first: 100 }) {
    edges {
      node {
        nameSingular
        namePlural
        labelSingular
        labelIdentifierFieldMetadataId
        fields(paging: { first: 200 }) {
          edges {
            node {
              id
              name
              label
              type
              isActive
              isSystem
              isCustom
            }
          }
        }
      }
    }
  }
}''',
      );
      final edges =
          ((data['objects'] as Map<String, dynamic>?)?['edges'] as List?) ??
          const [];
      for (final edge in edges) {
        final node = (edge as Map<String, dynamic>)['node'] as Map<String, dynamic>;
        if (node['nameSingular'] != metaName) continue;
        final rawFields = ((node['fields'] as Map<String, dynamic>?)?['edges']
                as List?) ??
            const [];
        final fields = <CrmFieldMeta>[];
        for (final fe in rawFields) {
          final fn = (fe as Map<String, dynamic>)['node'] as Map<String, dynamic>;
          if (fn['isActive'] == false) continue;
          final meta = CrmFieldMeta(
            name: fn['name'] as String,
            label: fn['label'] as String? ?? fn['name'] as String,
            type: fn['type'] as String? ?? 'TEXT',
            isSystem: fn['isSystem'] as bool? ?? false,
            isCustom: fn['isCustom'] as bool? ?? false,
          );
          fields.add(meta);
        }
        // 补充 metadata 缺失的应用已知字段
        for (final extra in extraObjectFields[objectKey] ?? const []) {
          if (!fields.any((f) => f.name == extra.name)) {
            fields.add(extra);
          }
        }
        // 合并 GraphQL schema 字段（权威）：metadata 缺失的字段补充进来
        try {
          final schemaFields = await client.typeFields(
            _capitalize(metaName),
          );
          final metaByName = {
            for (final f in fields) f.name: f,
          };
          final merged = <CrmFieldMeta>[];
          for (final sf in schemaFields) {
            final existing = metaByName[sf.name];
            merged.add(
              existing ??
                  CrmFieldMeta(
                    name: sf.name,
                    label: existing?.label ?? sf.name,
                    // 枚举按 SELECT 处理（schema 类型名不可枚举）
                    type: sf.kind == 'ENUM' ? 'SELECT' : sf.type,
                  ),
            );
          }
          // metadata 独有字段（含 extraObjectFields 补充）保留
          for (final f in fields) {
            if (!merged.any((m) => m.name == f.name)) merged.add(f);
          }
          fields
            ..clear()
            ..addAll(merged);
        } catch (_) {
          // schema 拉取失败时使用 metadata + 补充字段
        }
        final labelField = _guessLabelField(
          node['nameSingular'] as String,
          fields,
        );
        final meta = CrmObjectMeta(
          nameSingular: node['nameSingular'] as String,
          namePlural: node['namePlural'] as String? ?? '',
          labelSingular: node['labelSingular'] as String? ?? '',
          labelField: labelField,
          fields: fields,
        );
        _cache[objectKey] = meta;
        try {
          await PrefUtil.setValue<String>(cacheKey, jsonEncode(meta.toJson()));
        } catch (_) {
          // 测试/CLI 环境未初始化 PrefUtil 时忽略缓存
        }
        return meta;
      }
    } catch (_) {
      // 网络失败 → 回退缓存
    }
    String? cached;
    try {
      cached = PrefUtil.getValue<String>(cacheKey);
    } catch (_) {}
    if (cached != null && cached.isNotEmpty) {
      try {
        return CrmObjectMeta.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  /// 默认展示列：标签字段 + 可展示标量字段（metadata 顺序）。
  static List<CrmFieldMeta> defaultDisplayFields(CrmObjectMeta meta) {
    final result = <CrmFieldMeta>[];
    CrmFieldMeta? label;
    for (final field in meta.fields) {
      if (field.name == meta.labelField) {
        label = field;
      } else if (isDisplayableField(field)) {
        result.add(field);
      }
    }
    if (label != null) result.insert(0, label);
    return result;
  }

  /// 字段是否可展示（非系统、非审计、非关系）
  static bool isDisplayableField(CrmFieldMeta field) {
    if (field.isSystem) return false;
    if (_auditFields.contains(field.name)) return false;
    if (field.name.endsWith('Id')) return false;
    if (field.name.startsWith('__')) return false;
    final type = field.type;
    if (type.isEmpty) return true;
    if (_excludedTypes.contains(type)) return false;
    if (_metaTypePattern.hasMatch(type)) {
      // metadata 风格（UPPER_SNAKE）：仅排除关系类型
      return type != 'RELATION' && type != 'MORPH_RELATION';
    }
    // schema 风格（PascalCase）：复合标量白名单，其余对象视为关系
    return _compositeScalarTypes.contains(type);
  }

  /// 标签字段命名规则兜底（与 Twenty label identifier 对齐）
  static String _guessLabelField(String nameSingular, List<CrmFieldMeta> fields) {
    const labelNames = {
      'company': 'name',
      'person': 'name',
      'opportunity': 'name',
      'task': 'title',
      'note': 'title',
      'moodiaryGeneric': 'name',
      'contract': 'name',
      'payment': 'name',
      'invoice': 'name',
      'commission': 'name',
    };
    final preferred = labelNames[nameSingular] ?? 'name';
    if (fields.any((f) => f.name == preferred)) return preferred;
    // 无 name/title 时取第一个可展示字段
    for (final f in fields) {
      if (isDisplayableField(f)) return f.name;
    }
    return 'name';
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
