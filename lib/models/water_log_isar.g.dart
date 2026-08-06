// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_log_isar.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWaterLogIsarCollection on Isar {
  IsarCollection<WaterLogIsar> get waterLogIsars => this.collection();
}

const WaterLogIsarSchema = CollectionSchema(
  name: r'WaterLogIsar',
  id: -1485680163300052593,
  properties: {
    r'amountMl': PropertySchema(
      id: 0,
      name: r'amountMl',
      type: IsarType.long,
    ),
    r'dayKey': PropertySchema(
      id: 1,
      name: r'dayKey',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 2,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _waterLogIsarEstimateSize,
  serialize: _waterLogIsarSerialize,
  deserialize: _waterLogIsarDeserialize,
  deserializeProp: _waterLogIsarDeserializeProp,
  idName: r'id',
  indexes: {
    r'dayKey': IndexSchema(
      id: -3264092797330672150,
      name: r'dayKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'dayKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _waterLogIsarGetId,
  getLinks: _waterLogIsarGetLinks,
  attach: _waterLogIsarAttach,
  version: '3.1.0+1',
);

int _waterLogIsarEstimateSize(
  WaterLogIsar object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.dayKey.length * 3;
  return bytesCount;
}

void _waterLogIsarSerialize(
  WaterLogIsar object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.amountMl);
  writer.writeString(offsets[1], object.dayKey);
  writer.writeDateTime(offsets[2], object.updatedAt);
}

WaterLogIsar _waterLogIsarDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WaterLogIsar();
  object.amountMl = reader.readLong(offsets[0]);
  object.dayKey = reader.readString(offsets[1]);
  object.id = id;
  object.updatedAt = reader.readDateTime(offsets[2]);
  return object;
}

P _waterLogIsarDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _waterLogIsarGetId(WaterLogIsar object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _waterLogIsarGetLinks(WaterLogIsar object) {
  return [];
}

void _waterLogIsarAttach(
    IsarCollection<dynamic> col, Id id, WaterLogIsar object) {
  object.id = id;
}

extension WaterLogIsarByIndex on IsarCollection<WaterLogIsar> {
  Future<WaterLogIsar?> getByDayKey(String dayKey) {
    return getByIndex(r'dayKey', [dayKey]);
  }

  WaterLogIsar? getByDayKeySync(String dayKey) {
    return getByIndexSync(r'dayKey', [dayKey]);
  }

  Future<bool> deleteByDayKey(String dayKey) {
    return deleteByIndex(r'dayKey', [dayKey]);
  }

  bool deleteByDayKeySync(String dayKey) {
    return deleteByIndexSync(r'dayKey', [dayKey]);
  }

  Future<List<WaterLogIsar?>> getAllByDayKey(List<String> dayKeyValues) {
    final values = dayKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'dayKey', values);
  }

  List<WaterLogIsar?> getAllByDayKeySync(List<String> dayKeyValues) {
    final values = dayKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'dayKey', values);
  }

  Future<int> deleteAllByDayKey(List<String> dayKeyValues) {
    final values = dayKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'dayKey', values);
  }

  int deleteAllByDayKeySync(List<String> dayKeyValues) {
    final values = dayKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'dayKey', values);
  }

  Future<Id> putByDayKey(WaterLogIsar object) {
    return putByIndex(r'dayKey', object);
  }

  Id putByDayKeySync(WaterLogIsar object, {bool saveLinks = true}) {
    return putByIndexSync(r'dayKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDayKey(List<WaterLogIsar> objects) {
    return putAllByIndex(r'dayKey', objects);
  }

  List<Id> putAllByDayKeySync(List<WaterLogIsar> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'dayKey', objects, saveLinks: saveLinks);
  }
}

extension WaterLogIsarQueryWhereSort
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QWhere> {
  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WaterLogIsarQueryWhere
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QWhereClause> {
  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterWhereClause> dayKeyEqualTo(
      String dayKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'dayKey',
        value: [dayKey],
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterWhereClause> dayKeyNotEqualTo(
      String dayKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'dayKey',
              lower: [],
              upper: [dayKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'dayKey',
              lower: [dayKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'dayKey',
              lower: [dayKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'dayKey',
              lower: [],
              upper: [dayKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension WaterLogIsarQueryFilter
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QFilterCondition> {
  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      amountMlEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'amountMl',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      amountMlGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'amountMl',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      amountMlLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'amountMl',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      amountMlBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'amountMl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition> dayKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      dayKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      dayKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition> dayKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dayKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      dayKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      dayKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      dayKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dayKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition> dayKeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dayKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      dayKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dayKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      dayKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dayKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension WaterLogIsarQueryObject
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QFilterCondition> {}

extension WaterLogIsarQueryLinks
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QFilterCondition> {}

extension WaterLogIsarQuerySortBy
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QSortBy> {
  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> sortByAmountMl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountMl', Sort.asc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> sortByAmountMlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountMl', Sort.desc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> sortByDayKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dayKey', Sort.asc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> sortByDayKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dayKey', Sort.desc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension WaterLogIsarQuerySortThenBy
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QSortThenBy> {
  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> thenByAmountMl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountMl', Sort.asc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> thenByAmountMlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountMl', Sort.desc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> thenByDayKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dayKey', Sort.asc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> thenByDayKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dayKey', Sort.desc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension WaterLogIsarQueryWhereDistinct
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QDistinct> {
  QueryBuilder<WaterLogIsar, WaterLogIsar, QDistinct> distinctByAmountMl() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amountMl');
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QDistinct> distinctByDayKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dayKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WaterLogIsar, WaterLogIsar, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension WaterLogIsarQueryProperty
    on QueryBuilder<WaterLogIsar, WaterLogIsar, QQueryProperty> {
  QueryBuilder<WaterLogIsar, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WaterLogIsar, int, QQueryOperations> amountMlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amountMl');
    });
  }

  QueryBuilder<WaterLogIsar, String, QQueryOperations> dayKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dayKey');
    });
  }

  QueryBuilder<WaterLogIsar, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
