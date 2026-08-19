// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crm_entity_cache.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetCrmEntityCacheCollection on Isar {
  IsarCollection<int, CrmEntityCache> get crmEntityCaches => this.collection();
}

const CrmEntityCacheSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'CrmEntityCache',
    idName: 'isarId',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'id', type: IsarType.string),
      IsarPropertySchema(name: 'twentyId', type: IsarType.string),
      IsarPropertySchema(name: 'entityType', type: IsarType.string),
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'dataJson', type: IsarType.string),
      IsarPropertySchema(name: 'isDeleted', type: IsarType.bool),
      IsarPropertySchema(name: 'localVersion', type: IsarType.long),
      IsarPropertySchema(name: 'lastSyncedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'updatedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'data', type: IsarType.json),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'twentyId',
        properties: ["twentyId"],
        unique: false,
        hash: false,
      ),
      IsarIndexSchema(
        name: 'entityType',
        properties: ["entityType"],
        unique: false,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, CrmEntityCache>(
    serialize: serializeCrmEntityCache,
    deserialize: deserializeCrmEntityCache,
    deserializeProperty: deserializeCrmEntityCacheProp,
  ),
  embeddedSchemas: [],
);

@isarProtected
int serializeCrmEntityCache(IsarWriter writer, CrmEntityCache object) {
  IsarCore.writeString(writer, 1, object.id);
  IsarCore.writeString(writer, 2, object.twentyId);
  IsarCore.writeString(writer, 3, object.entityType);
  IsarCore.writeString(writer, 4, object.name);
  IsarCore.writeString(writer, 5, object.dataJson);
  IsarCore.writeBool(writer, 6, object.isDeleted);
  IsarCore.writeLong(writer, 7, object.localVersion);
  IsarCore.writeLong(
    writer,
    8,
    object.lastSyncedAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeLong(
    writer,
    9,
    object.updatedAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeString(writer, 10, isarJsonEncode(object.data));
  return object.isarId;
}

@isarProtected
CrmEntityCache deserializeCrmEntityCache(IsarReader reader) {
  final object = CrmEntityCache();
  object.id = IsarCore.readString(reader, 1) ?? '';
  object.twentyId = IsarCore.readString(reader, 2) ?? '';
  object.entityType = IsarCore.readString(reader, 3) ?? '';
  object.name = IsarCore.readString(reader, 4) ?? '';
  object.dataJson = IsarCore.readString(reader, 5) ?? '';
  object.isDeleted = IsarCore.readBool(reader, 6);
  object.localVersion = IsarCore.readLong(reader, 7);
  {
    final value = IsarCore.readLong(reader, 8);
    if (value == -9223372036854775808) {
      object.lastSyncedAt =
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
    } else {
      object.lastSyncedAt =
          DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true).toLocal();
    }
  }
  {
    final value = IsarCore.readLong(reader, 9);
    if (value == -9223372036854775808) {
      object.updatedAt =
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
    } else {
      object.updatedAt =
          DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true).toLocal();
    }
  }
  return object;
}

@isarProtected
dynamic deserializeCrmEntityCacheProp(IsarReader reader, int property) {
  switch (property) {
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readString(reader, 3) ?? '';
    case 4:
      return IsarCore.readString(reader, 4) ?? '';
    case 5:
      return IsarCore.readString(reader, 5) ?? '';
    case 6:
      return IsarCore.readBool(reader, 6);
    case 7:
      return IsarCore.readLong(reader, 7);
    case 8:
      {
        final value = IsarCore.readLong(reader, 8);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 9:
      {
        final value = IsarCore.readLong(reader, 9);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 0:
      return IsarCore.readId(reader);
    case 10:
      {
        final json = isarJsonDecode(IsarCore.readString(reader, 10) ?? 'null');
        if (json is Map<String, dynamic>) {
          return json;
        } else {
          return const <String, dynamic>{};
        }
      }
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _CrmEntityCacheUpdate {
  bool call({
    required int isarId,
    String? id,
    String? twentyId,
    String? entityType,
    String? name,
    String? dataJson,
    bool? isDeleted,
    int? localVersion,
    DateTime? lastSyncedAt,
    DateTime? updatedAt,
  });
}

class _CrmEntityCacheUpdateImpl implements _CrmEntityCacheUpdate {
  const _CrmEntityCacheUpdateImpl(this.collection);

  final IsarCollection<int, CrmEntityCache> collection;

  @override
  bool call({
    required int isarId,
    Object? id = ignore,
    Object? twentyId = ignore,
    Object? entityType = ignore,
    Object? name = ignore,
    Object? dataJson = ignore,
    Object? isDeleted = ignore,
    Object? localVersion = ignore,
    Object? lastSyncedAt = ignore,
    Object? updatedAt = ignore,
  }) {
    return collection.updateProperties(
          [isarId],
          {
            if (id != ignore) 1: id as String?,
            if (twentyId != ignore) 2: twentyId as String?,
            if (entityType != ignore) 3: entityType as String?,
            if (name != ignore) 4: name as String?,
            if (dataJson != ignore) 5: dataJson as String?,
            if (isDeleted != ignore) 6: isDeleted as bool?,
            if (localVersion != ignore) 7: localVersion as int?,
            if (lastSyncedAt != ignore) 8: lastSyncedAt as DateTime?,
            if (updatedAt != ignore) 9: updatedAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _CrmEntityCacheUpdateAll {
  int call({
    required List<int> isarId,
    String? id,
    String? twentyId,
    String? entityType,
    String? name,
    String? dataJson,
    bool? isDeleted,
    int? localVersion,
    DateTime? lastSyncedAt,
    DateTime? updatedAt,
  });
}

class _CrmEntityCacheUpdateAllImpl implements _CrmEntityCacheUpdateAll {
  const _CrmEntityCacheUpdateAllImpl(this.collection);

  final IsarCollection<int, CrmEntityCache> collection;

  @override
  int call({
    required List<int> isarId,
    Object? id = ignore,
    Object? twentyId = ignore,
    Object? entityType = ignore,
    Object? name = ignore,
    Object? dataJson = ignore,
    Object? isDeleted = ignore,
    Object? localVersion = ignore,
    Object? lastSyncedAt = ignore,
    Object? updatedAt = ignore,
  }) {
    return collection.updateProperties(isarId, {
      if (id != ignore) 1: id as String?,
      if (twentyId != ignore) 2: twentyId as String?,
      if (entityType != ignore) 3: entityType as String?,
      if (name != ignore) 4: name as String?,
      if (dataJson != ignore) 5: dataJson as String?,
      if (isDeleted != ignore) 6: isDeleted as bool?,
      if (localVersion != ignore) 7: localVersion as int?,
      if (lastSyncedAt != ignore) 8: lastSyncedAt as DateTime?,
      if (updatedAt != ignore) 9: updatedAt as DateTime?,
    });
  }
}

extension CrmEntityCacheUpdate on IsarCollection<int, CrmEntityCache> {
  _CrmEntityCacheUpdate get update => _CrmEntityCacheUpdateImpl(this);

  _CrmEntityCacheUpdateAll get updateAll => _CrmEntityCacheUpdateAllImpl(this);
}

sealed class _CrmEntityCacheQueryUpdate {
  int call({
    String? id,
    String? twentyId,
    String? entityType,
    String? name,
    String? dataJson,
    bool? isDeleted,
    int? localVersion,
    DateTime? lastSyncedAt,
    DateTime? updatedAt,
  });
}

class _CrmEntityCacheQueryUpdateImpl implements _CrmEntityCacheQueryUpdate {
  const _CrmEntityCacheQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<CrmEntityCache> query;
  final int? limit;

  @override
  int call({
    Object? id = ignore,
    Object? twentyId = ignore,
    Object? entityType = ignore,
    Object? name = ignore,
    Object? dataJson = ignore,
    Object? isDeleted = ignore,
    Object? localVersion = ignore,
    Object? lastSyncedAt = ignore,
    Object? updatedAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (id != ignore) 1: id as String?,
      if (twentyId != ignore) 2: twentyId as String?,
      if (entityType != ignore) 3: entityType as String?,
      if (name != ignore) 4: name as String?,
      if (dataJson != ignore) 5: dataJson as String?,
      if (isDeleted != ignore) 6: isDeleted as bool?,
      if (localVersion != ignore) 7: localVersion as int?,
      if (lastSyncedAt != ignore) 8: lastSyncedAt as DateTime?,
      if (updatedAt != ignore) 9: updatedAt as DateTime?,
    });
  }
}

extension CrmEntityCacheQueryUpdate on IsarQuery<CrmEntityCache> {
  _CrmEntityCacheQueryUpdate get updateFirst =>
      _CrmEntityCacheQueryUpdateImpl(this, limit: 1);

  _CrmEntityCacheQueryUpdate get updateAll =>
      _CrmEntityCacheQueryUpdateImpl(this);
}

class _CrmEntityCacheQueryBuilderUpdateImpl
    implements _CrmEntityCacheQueryUpdate {
  const _CrmEntityCacheQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<CrmEntityCache, CrmEntityCache, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? id = ignore,
    Object? twentyId = ignore,
    Object? entityType = ignore,
    Object? name = ignore,
    Object? dataJson = ignore,
    Object? isDeleted = ignore,
    Object? localVersion = ignore,
    Object? lastSyncedAt = ignore,
    Object? updatedAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (id != ignore) 1: id as String?,
        if (twentyId != ignore) 2: twentyId as String?,
        if (entityType != ignore) 3: entityType as String?,
        if (name != ignore) 4: name as String?,
        if (dataJson != ignore) 5: dataJson as String?,
        if (isDeleted != ignore) 6: isDeleted as bool?,
        if (localVersion != ignore) 7: localVersion as int?,
        if (lastSyncedAt != ignore) 8: lastSyncedAt as DateTime?,
        if (updatedAt != ignore) 9: updatedAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension CrmEntityCacheQueryBuilderUpdate
    on QueryBuilder<CrmEntityCache, CrmEntityCache, QOperations> {
  _CrmEntityCacheQueryUpdate get updateFirst =>
      _CrmEntityCacheQueryBuilderUpdateImpl(this, limit: 1);

  _CrmEntityCacheQueryUpdate get updateAll =>
      _CrmEntityCacheQueryBuilderUpdateImpl(this);
}

extension CrmEntityCacheQueryFilter
    on QueryBuilder<CrmEntityCache, CrmEntityCache, QFilterCondition> {
  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 1,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition> idMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 1,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 2,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 2,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  twentyIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 3,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 3,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  entityTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 4,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 4,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 5,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 5,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  dataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  localVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  localVersionGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  localVersionGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  localVersionLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 7, value: value));
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  localVersionLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  localVersionBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 7, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  lastSyncedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  lastSyncedAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  lastSyncedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  lastSyncedAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 8, value: value));
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  lastSyncedAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  lastSyncedAtBetween(DateTime lower, DateTime upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 8, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  updatedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  updatedAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 9, value: value));
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  updatedAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  updatedAtBetween(DateTime lower, DateTime upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 9, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  isarIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  isarIdGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  isarIdGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  isarIdLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  isarIdLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterFilterCondition>
  isarIdBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }
}

extension CrmEntityCacheQueryObject
    on QueryBuilder<CrmEntityCache, CrmEntityCache, QFilterCondition> {}

extension CrmEntityCacheQuerySortBy
    on QueryBuilder<CrmEntityCache, CrmEntityCache, QSortBy> {
  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByTwentyId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByTwentyIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByEntityType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByEntityTypeDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByDataJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByDataJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByLocalVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByLocalVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  sortByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> sortByDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }
}

extension CrmEntityCacheQuerySortThenBy
    on QueryBuilder<CrmEntityCache, CrmEntityCache, QSortThenBy> {
  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByTwentyId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByTwentyIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByEntityType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByEntityTypeDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByDataJson({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByDataJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByLocalVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByLocalVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy>
  thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterSortBy> thenByDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }
}

extension CrmEntityCacheQueryWhereDistinct
    on QueryBuilder<CrmEntityCache, CrmEntityCache, QDistinct> {
  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct> distinctById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct>
  distinctByTwentyId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct>
  distinctByEntityType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct>
  distinctByDataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct>
  distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct>
  distinctByLocalVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct>
  distinctByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }

  QueryBuilder<CrmEntityCache, CrmEntityCache, QAfterDistinct>
  distinctByData() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10);
    });
  }
}

extension CrmEntityCacheQueryProperty1
    on QueryBuilder<CrmEntityCache, CrmEntityCache, QProperty> {
  QueryBuilder<CrmEntityCache, String, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CrmEntityCache, String, QAfterProperty> twentyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<CrmEntityCache, String, QAfterProperty> entityTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<CrmEntityCache, String, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<CrmEntityCache, String, QAfterProperty> dataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<CrmEntityCache, bool, QAfterProperty> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<CrmEntityCache, int, QAfterProperty> localVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<CrmEntityCache, DateTime, QAfterProperty>
  lastSyncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<CrmEntityCache, DateTime, QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<CrmEntityCache, int, QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CrmEntityCache, Map<String, dynamic>, QAfterProperty>
  dataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }
}

extension CrmEntityCacheQueryProperty2<R>
    on QueryBuilder<CrmEntityCache, R, QAfterProperty> {
  QueryBuilder<CrmEntityCache, (R, String), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CrmEntityCache, (R, String), QAfterProperty> twentyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<CrmEntityCache, (R, String), QAfterProperty>
  entityTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<CrmEntityCache, (R, String), QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<CrmEntityCache, (R, String), QAfterProperty> dataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<CrmEntityCache, (R, bool), QAfterProperty> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<CrmEntityCache, (R, int), QAfterProperty>
  localVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<CrmEntityCache, (R, DateTime), QAfterProperty>
  lastSyncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<CrmEntityCache, (R, DateTime), QAfterProperty>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<CrmEntityCache, (R, int), QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CrmEntityCache, (R, Map<String, dynamic>), QAfterProperty>
  dataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }
}

extension CrmEntityCacheQueryProperty3<R1, R2>
    on QueryBuilder<CrmEntityCache, (R1, R2), QAfterProperty> {
  QueryBuilder<CrmEntityCache, (R1, R2, String), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, String), QOperations>
  twentyIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, String), QOperations>
  entityTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, String), QOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, String), QOperations>
  dataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, bool), QOperations>
  isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, int), QOperations>
  localVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, DateTime), QOperations>
  lastSyncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, DateTime), QOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, int), QOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<CrmEntityCache, (R1, R2, Map<String, dynamic>), QOperations>
  dataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }
}
