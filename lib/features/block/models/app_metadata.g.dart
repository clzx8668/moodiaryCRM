// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_metadata.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetAppMetadataCollection on Isar {
  IsarCollection<int, AppMetadata> get appMetadatas => this.collection();
}

const AppMetadataSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'AppMetadata',
    idName: 'isarId',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'key', type: IsarType.string),
      IsarPropertySchema(name: 'value', type: IsarType.string),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, AppMetadata>(
    serialize: serializeAppMetadata,
    deserialize: deserializeAppMetadata,
    deserializeProperty: deserializeAppMetadataProp,
  ),
  embeddedSchemas: [],
);

@isarProtected
int serializeAppMetadata(IsarWriter writer, AppMetadata object) {
  IsarCore.writeString(writer, 1, object.key);
  IsarCore.writeString(writer, 2, object.value);
  return object.isarId;
}

@isarProtected
AppMetadata deserializeAppMetadata(IsarReader reader) {
  final String _key;
  _key = IsarCore.readString(reader, 1) ?? '';
  final String _value;
  _value = IsarCore.readString(reader, 2) ?? '';
  final object = AppMetadata(key: _key, value: _value);
  return object;
}

@isarProtected
dynamic deserializeAppMetadataProp(IsarReader reader, int property) {
  switch (property) {
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 0:
      return IsarCore.readId(reader);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _AppMetadataUpdate {
  bool call({required int isarId, String? key, String? value});
}

class _AppMetadataUpdateImpl implements _AppMetadataUpdate {
  const _AppMetadataUpdateImpl(this.collection);

  final IsarCollection<int, AppMetadata> collection;

  @override
  bool call({
    required int isarId,
    Object? key = ignore,
    Object? value = ignore,
  }) {
    return collection.updateProperties(
          [isarId],
          {
            if (key != ignore) 1: key as String?,
            if (value != ignore) 2: value as String?,
          },
        ) >
        0;
  }
}

sealed class _AppMetadataUpdateAll {
  int call({required List<int> isarId, String? key, String? value});
}

class _AppMetadataUpdateAllImpl implements _AppMetadataUpdateAll {
  const _AppMetadataUpdateAllImpl(this.collection);

  final IsarCollection<int, AppMetadata> collection;

  @override
  int call({
    required List<int> isarId,
    Object? key = ignore,
    Object? value = ignore,
  }) {
    return collection.updateProperties(isarId, {
      if (key != ignore) 1: key as String?,
      if (value != ignore) 2: value as String?,
    });
  }
}

extension AppMetadataUpdate on IsarCollection<int, AppMetadata> {
  _AppMetadataUpdate get update => _AppMetadataUpdateImpl(this);

  _AppMetadataUpdateAll get updateAll => _AppMetadataUpdateAllImpl(this);
}

sealed class _AppMetadataQueryUpdate {
  int call({String? key, String? value});
}

class _AppMetadataQueryUpdateImpl implements _AppMetadataQueryUpdate {
  const _AppMetadataQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<AppMetadata> query;
  final int? limit;

  @override
  int call({Object? key = ignore, Object? value = ignore}) {
    return query.updateProperties(limit: limit, {
      if (key != ignore) 1: key as String?,
      if (value != ignore) 2: value as String?,
    });
  }
}

extension AppMetadataQueryUpdate on IsarQuery<AppMetadata> {
  _AppMetadataQueryUpdate get updateFirst =>
      _AppMetadataQueryUpdateImpl(this, limit: 1);

  _AppMetadataQueryUpdate get updateAll => _AppMetadataQueryUpdateImpl(this);
}

class _AppMetadataQueryBuilderUpdateImpl implements _AppMetadataQueryUpdate {
  const _AppMetadataQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<AppMetadata, AppMetadata, QOperations> query;
  final int? limit;

  @override
  int call({Object? key = ignore, Object? value = ignore}) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (key != ignore) 1: key as String?,
        if (value != ignore) 2: value as String?,
      });
    } finally {
      q.close();
    }
  }
}

extension AppMetadataQueryBuilderUpdate
    on QueryBuilder<AppMetadata, AppMetadata, QOperations> {
  _AppMetadataQueryUpdate get updateFirst =>
      _AppMetadataQueryBuilderUpdateImpl(this, limit: 1);

  _AppMetadataQueryUpdate get updateAll =>
      _AppMetadataQueryBuilderUpdateImpl(this);
}

extension AppMetadataQueryFilter
    on QueryBuilder<AppMetadata, AppMetadata, QFilterCondition> {
  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  keyGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  keyLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyBetween(
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyMatches(
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> keyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  keyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> valueEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  valueGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  valueGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> valueLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  valueLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> valueBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> valueStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> valueEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> valueContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> valueMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> valueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  valueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> isarIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  isarIdGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  isarIdGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> isarIdLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition>
  isarIdLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterFilterCondition> isarIdBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }
}

extension AppMetadataQueryObject
    on QueryBuilder<AppMetadata, AppMetadata, QFilterCondition> {}

extension AppMetadataQuerySortBy
    on QueryBuilder<AppMetadata, AppMetadata, QSortBy> {
  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> sortByKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> sortByKeyDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> sortByValue({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> sortByValueDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> sortByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> sortByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension AppMetadataQuerySortThenBy
    on QueryBuilder<AppMetadata, AppMetadata, QSortThenBy> {
  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> thenByKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> thenByKeyDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> thenByValue({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> thenByValueDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension AppMetadataQueryWhereDistinct
    on QueryBuilder<AppMetadata, AppMetadata, QDistinct> {
  QueryBuilder<AppMetadata, AppMetadata, QAfterDistinct> distinctByKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppMetadata, AppMetadata, QAfterDistinct> distinctByValue({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }
}

extension AppMetadataQueryProperty1
    on QueryBuilder<AppMetadata, AppMetadata, QProperty> {
  QueryBuilder<AppMetadata, String, QAfterProperty> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AppMetadata, String, QAfterProperty> valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AppMetadata, int, QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}

extension AppMetadataQueryProperty2<R>
    on QueryBuilder<AppMetadata, R, QAfterProperty> {
  QueryBuilder<AppMetadata, (R, String), QAfterProperty> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AppMetadata, (R, String), QAfterProperty> valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AppMetadata, (R, int), QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}

extension AppMetadataQueryProperty3<R1, R2>
    on QueryBuilder<AppMetadata, (R1, R2), QAfterProperty> {
  QueryBuilder<AppMetadata, (R1, R2, String), QOperations> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AppMetadata, (R1, R2, String), QOperations> valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AppMetadata, (R1, R2, int), QOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}
