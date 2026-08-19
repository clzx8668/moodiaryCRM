// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'block.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetBlockCollection on Isar {
  IsarCollection<int, Block> get blocks => this.collection();
}

const BlockSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'Block',
    idName: 'isarId',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'id', type: IsarType.string),
      IsarPropertySchema(name: 'diaryId', type: IsarType.string),
      IsarPropertySchema(
        name: 'blockType',
        type: IsarType.long,

        enumMap: {
          "text": 0,
          "smartEntity": 1,
          "todo": 2,
          "chart": 3,
          "aiStream": 4,
          "image": 5,
          "code": 6,
        },
      ),
      IsarPropertySchema(name: 'content', type: IsarType.string),
      IsarPropertySchema(name: 'sortOrder', type: IsarType.long),
      IsarPropertySchema(name: 'isDeleted', type: IsarType.bool),
      IsarPropertySchema(name: 'streamBuffer', type: IsarType.string),
      IsarPropertySchema(name: 'streamComplete', type: IsarType.bool),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'updatedAt', type: IsarType.dateTime),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'diaryId',
        properties: ["diaryId"],
        unique: false,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, Block>(
    serialize: serializeBlock,
    deserialize: deserializeBlock,
    deserializeProperty: deserializeBlockProp,
  ),
  embeddedSchemas: [],
);

@isarProtected
int serializeBlock(IsarWriter writer, Block object) {
  IsarCore.writeString(writer, 1, object.id);
  IsarCore.writeString(writer, 2, object.diaryId);
  IsarCore.writeLong(writer, 3, object.blockType.value);
  IsarCore.writeString(writer, 4, object.content);
  IsarCore.writeLong(writer, 5, object.sortOrder);
  IsarCore.writeBool(writer, 6, object.isDeleted);
  IsarCore.writeString(writer, 7, object.streamBuffer);
  IsarCore.writeBool(writer, 8, object.streamComplete);
  IsarCore.writeLong(
    writer,
    9,
    object.createdAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeLong(
    writer,
    10,
    object.updatedAt.toUtc().microsecondsSinceEpoch,
  );
  return object.isarId;
}

@isarProtected
Block deserializeBlock(IsarReader reader) {
  final object = Block();
  object.id = IsarCore.readString(reader, 1) ?? '';
  object.diaryId = IsarCore.readString(reader, 2) ?? '';
  {
    final value = IsarCore.readLong(reader, 3);
    if (value == -9223372036854775808) {
      object.blockType = BlockType.text;
    } else {
      object.blockType = _blockBlockType[value] ?? BlockType.text;
    }
  }
  object.content = IsarCore.readString(reader, 4) ?? '';
  object.sortOrder = IsarCore.readLong(reader, 5);
  object.isDeleted = IsarCore.readBool(reader, 6);
  object.streamBuffer = IsarCore.readString(reader, 7) ?? '';
  object.streamComplete = IsarCore.readBool(reader, 8);
  {
    final value = IsarCore.readLong(reader, 9);
    if (value == -9223372036854775808) {
      object.createdAt =
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
    } else {
      object.createdAt =
          DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true).toLocal();
    }
  }
  {
    final value = IsarCore.readLong(reader, 10);
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
dynamic deserializeBlockProp(IsarReader reader, int property) {
  switch (property) {
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      {
        final value = IsarCore.readLong(reader, 3);
        if (value == -9223372036854775808) {
          return BlockType.text;
        } else {
          return _blockBlockType[value] ?? BlockType.text;
        }
      }
    case 4:
      return IsarCore.readString(reader, 4) ?? '';
    case 5:
      return IsarCore.readLong(reader, 5);
    case 6:
      return IsarCore.readBool(reader, 6);
    case 7:
      return IsarCore.readString(reader, 7) ?? '';
    case 8:
      return IsarCore.readBool(reader, 8);
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
    case 10:
      {
        final value = IsarCore.readLong(reader, 10);
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
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _BlockUpdate {
  bool call({
    required int isarId,
    String? id,
    String? diaryId,
    BlockType? blockType,
    String? content,
    int? sortOrder,
    bool? isDeleted,
    String? streamBuffer,
    bool? streamComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

class _BlockUpdateImpl implements _BlockUpdate {
  const _BlockUpdateImpl(this.collection);

  final IsarCollection<int, Block> collection;

  @override
  bool call({
    required int isarId,
    Object? id = ignore,
    Object? diaryId = ignore,
    Object? blockType = ignore,
    Object? content = ignore,
    Object? sortOrder = ignore,
    Object? isDeleted = ignore,
    Object? streamBuffer = ignore,
    Object? streamComplete = ignore,
    Object? createdAt = ignore,
    Object? updatedAt = ignore,
  }) {
    return collection.updateProperties(
          [isarId],
          {
            if (id != ignore) 1: id as String?,
            if (diaryId != ignore) 2: diaryId as String?,
            if (blockType != ignore) 3: blockType as BlockType?,
            if (content != ignore) 4: content as String?,
            if (sortOrder != ignore) 5: sortOrder as int?,
            if (isDeleted != ignore) 6: isDeleted as bool?,
            if (streamBuffer != ignore) 7: streamBuffer as String?,
            if (streamComplete != ignore) 8: streamComplete as bool?,
            if (createdAt != ignore) 9: createdAt as DateTime?,
            if (updatedAt != ignore) 10: updatedAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _BlockUpdateAll {
  int call({
    required List<int> isarId,
    String? id,
    String? diaryId,
    BlockType? blockType,
    String? content,
    int? sortOrder,
    bool? isDeleted,
    String? streamBuffer,
    bool? streamComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

class _BlockUpdateAllImpl implements _BlockUpdateAll {
  const _BlockUpdateAllImpl(this.collection);

  final IsarCollection<int, Block> collection;

  @override
  int call({
    required List<int> isarId,
    Object? id = ignore,
    Object? diaryId = ignore,
    Object? blockType = ignore,
    Object? content = ignore,
    Object? sortOrder = ignore,
    Object? isDeleted = ignore,
    Object? streamBuffer = ignore,
    Object? streamComplete = ignore,
    Object? createdAt = ignore,
    Object? updatedAt = ignore,
  }) {
    return collection.updateProperties(isarId, {
      if (id != ignore) 1: id as String?,
      if (diaryId != ignore) 2: diaryId as String?,
      if (blockType != ignore) 3: blockType as BlockType?,
      if (content != ignore) 4: content as String?,
      if (sortOrder != ignore) 5: sortOrder as int?,
      if (isDeleted != ignore) 6: isDeleted as bool?,
      if (streamBuffer != ignore) 7: streamBuffer as String?,
      if (streamComplete != ignore) 8: streamComplete as bool?,
      if (createdAt != ignore) 9: createdAt as DateTime?,
      if (updatedAt != ignore) 10: updatedAt as DateTime?,
    });
  }
}

extension BlockUpdate on IsarCollection<int, Block> {
  _BlockUpdate get update => _BlockUpdateImpl(this);

  _BlockUpdateAll get updateAll => _BlockUpdateAllImpl(this);
}

sealed class _BlockQueryUpdate {
  int call({
    String? id,
    String? diaryId,
    BlockType? blockType,
    String? content,
    int? sortOrder,
    bool? isDeleted,
    String? streamBuffer,
    bool? streamComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

class _BlockQueryUpdateImpl implements _BlockQueryUpdate {
  const _BlockQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<Block> query;
  final int? limit;

  @override
  int call({
    Object? id = ignore,
    Object? diaryId = ignore,
    Object? blockType = ignore,
    Object? content = ignore,
    Object? sortOrder = ignore,
    Object? isDeleted = ignore,
    Object? streamBuffer = ignore,
    Object? streamComplete = ignore,
    Object? createdAt = ignore,
    Object? updatedAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (id != ignore) 1: id as String?,
      if (diaryId != ignore) 2: diaryId as String?,
      if (blockType != ignore) 3: blockType as BlockType?,
      if (content != ignore) 4: content as String?,
      if (sortOrder != ignore) 5: sortOrder as int?,
      if (isDeleted != ignore) 6: isDeleted as bool?,
      if (streamBuffer != ignore) 7: streamBuffer as String?,
      if (streamComplete != ignore) 8: streamComplete as bool?,
      if (createdAt != ignore) 9: createdAt as DateTime?,
      if (updatedAt != ignore) 10: updatedAt as DateTime?,
    });
  }
}

extension BlockQueryUpdate on IsarQuery<Block> {
  _BlockQueryUpdate get updateFirst => _BlockQueryUpdateImpl(this, limit: 1);

  _BlockQueryUpdate get updateAll => _BlockQueryUpdateImpl(this);
}

class _BlockQueryBuilderUpdateImpl implements _BlockQueryUpdate {
  const _BlockQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<Block, Block, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? id = ignore,
    Object? diaryId = ignore,
    Object? blockType = ignore,
    Object? content = ignore,
    Object? sortOrder = ignore,
    Object? isDeleted = ignore,
    Object? streamBuffer = ignore,
    Object? streamComplete = ignore,
    Object? createdAt = ignore,
    Object? updatedAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (id != ignore) 1: id as String?,
        if (diaryId != ignore) 2: diaryId as String?,
        if (blockType != ignore) 3: blockType as BlockType?,
        if (content != ignore) 4: content as String?,
        if (sortOrder != ignore) 5: sortOrder as int?,
        if (isDeleted != ignore) 6: isDeleted as bool?,
        if (streamBuffer != ignore) 7: streamBuffer as String?,
        if (streamComplete != ignore) 8: streamComplete as bool?,
        if (createdAt != ignore) 9: createdAt as DateTime?,
        if (updatedAt != ignore) 10: updatedAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension BlockQueryBuilderUpdate on QueryBuilder<Block, Block, QOperations> {
  _BlockQueryUpdate get updateFirst =>
      _BlockQueryBuilderUpdateImpl(this, limit: 1);

  _BlockQueryUpdate get updateAll => _BlockQueryBuilderUpdateImpl(this);
}

const _blockBlockType = {
  0: BlockType.text,
  1: BlockType.smartEntity,
  2: BlockType.todo,
  3: BlockType.chart,
  4: BlockType.aiStream,
  5: BlockType.image,
  6: BlockType.code,
};

extension BlockQueryFilter on QueryBuilder<Block, Block, QFilterCondition> {
  QueryBuilder<Block, Block, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> idGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> idLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> idLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> idStartsWith(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> idEndsWith(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> idContains(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> idMatches(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdBetween(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdStartsWith(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdEndsWith(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdContains(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdMatches(
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

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> diaryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> blockTypeEqualTo(
    BlockType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value.value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> blockTypeGreaterThan(
    BlockType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 3, value: value.value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition>
  blockTypeGreaterThanOrEqualTo(BlockType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 3, value: value.value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> blockTypeLessThan(
    BlockType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value.value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> blockTypeLessThanOrEqualTo(
    BlockType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 3, value: value.value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> blockTypeBetween(
    BlockType lower,
    BlockType upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 3, lower: lower.value, upper: upper.value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> contentGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> contentGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> contentLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> contentLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> contentBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> contentContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> contentMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Block, Block, QAfterFilterCondition> contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> sortOrderEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> sortOrderGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition>
  sortOrderGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> sortOrderLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 5, value: value));
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> sortOrderLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> sortOrderBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 5, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> isDeletedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition>
  streamBufferGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition>
  streamBufferLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 7,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 7,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamBufferIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> streamCompleteEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> createdAtLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 9, value: value));
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> createdAtLessThanOrEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 9, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> updatedAtGreaterThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition>
  updatedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> updatedAtLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> updatedAtLessThanOrEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 10, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> isarIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> isarIdGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> isarIdGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> isarIdLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> isarIdLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<Block, Block, QAfterFilterCondition> isarIdBetween(
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

extension BlockQueryObject on QueryBuilder<Block, Block, QFilterCondition> {}

extension BlockQuerySortBy on QueryBuilder<Block, Block, QSortBy> {
  QueryBuilder<Block, Block, QAfterSortBy> sortById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByDiaryId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByDiaryIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByBlockType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByBlockTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByContent({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByContentDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByStreamBuffer({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByStreamBufferDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByStreamComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByStreamCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> sortByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension BlockQuerySortThenBy on QueryBuilder<Block, Block, QSortThenBy> {
  QueryBuilder<Block, Block, QAfterSortBy> thenById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByDiaryId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByDiaryIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByBlockType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByBlockTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByContent({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByContentDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByStreamBuffer({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByStreamBufferDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByStreamComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByStreamCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<Block, Block, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension BlockQueryWhereDistinct on QueryBuilder<Block, Block, QDistinct> {
  QueryBuilder<Block, Block, QAfterDistinct> distinctById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctByDiaryId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctByBlockType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctByContent({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctByStreamBuffer({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctByStreamComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }

  QueryBuilder<Block, Block, QAfterDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10);
    });
  }
}

extension BlockQueryProperty1 on QueryBuilder<Block, Block, QProperty> {
  QueryBuilder<Block, String, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Block, String, QAfterProperty> diaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Block, BlockType, QAfterProperty> blockTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Block, String, QAfterProperty> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Block, int, QAfterProperty> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Block, bool, QAfterProperty> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Block, String, QAfterProperty> streamBufferProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Block, bool, QAfterProperty> streamCompleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<Block, DateTime, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<Block, DateTime, QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<Block, int, QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}

extension BlockQueryProperty2<R> on QueryBuilder<Block, R, QAfterProperty> {
  QueryBuilder<Block, (R, String), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Block, (R, String), QAfterProperty> diaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Block, (R, BlockType), QAfterProperty> blockTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Block, (R, String), QAfterProperty> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Block, (R, int), QAfterProperty> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Block, (R, bool), QAfterProperty> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Block, (R, String), QAfterProperty> streamBufferProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Block, (R, bool), QAfterProperty> streamCompleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<Block, (R, DateTime), QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<Block, (R, DateTime), QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<Block, (R, int), QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}

extension BlockQueryProperty3<R1, R2>
    on QueryBuilder<Block, (R1, R2), QAfterProperty> {
  QueryBuilder<Block, (R1, R2, String), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Block, (R1, R2, String), QOperations> diaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Block, (R1, R2, BlockType), QOperations> blockTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Block, (R1, R2, String), QOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Block, (R1, R2, int), QOperations> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Block, (R1, R2, bool), QOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Block, (R1, R2, String), QOperations> streamBufferProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Block, (R1, R2, bool), QOperations> streamCompleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<Block, (R1, R2, DateTime), QOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<Block, (R1, R2, DateTime), QOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<Block, (R1, R2, int), QOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}
