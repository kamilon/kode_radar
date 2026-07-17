// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MetricSnapshotsTable extends MetricSnapshots
    with TableInfo<$MetricSnapshotsTable, MetricSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetricSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _repoKeyMeta = const VerificationMeta(
    'repoKey',
  );
  @override
  late final GeneratedColumn<String> repoKey = GeneratedColumn<String>(
    'repo_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openPrsMeta = const VerificationMeta(
    'openPrs',
  );
  @override
  late final GeneratedColumn<int> openPrs = GeneratedColumn<int>(
    'open_prs',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _needsReviewMeta = const VerificationMeta(
    'needsReview',
  );
  @override
  late final GeneratedColumn<int> needsReview = GeneratedColumn<int>(
    'needs_review',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityScoreMeta = const VerificationMeta(
    'activityScore',
  );
  @override
  late final GeneratedColumn<double> activityScore = GeneratedColumn<double>(
    'activity_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repoKey,
    capturedAt,
    openPrs,
    needsReview,
    activityScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'metric_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetricSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('repo_key')) {
      context.handle(
        _repoKeyMeta,
        repoKey.isAcceptableOrUnknown(data['repo_key']!, _repoKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_repoKeyMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('open_prs')) {
      context.handle(
        _openPrsMeta,
        openPrs.isAcceptableOrUnknown(data['open_prs']!, _openPrsMeta),
      );
    } else if (isInserting) {
      context.missing(_openPrsMeta);
    }
    if (data.containsKey('needs_review')) {
      context.handle(
        _needsReviewMeta,
        needsReview.isAcceptableOrUnknown(
          data['needs_review']!,
          _needsReviewMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_needsReviewMeta);
    }
    if (data.containsKey('activity_score')) {
      context.handle(
        _activityScoreMeta,
        activityScore.isAcceptableOrUnknown(
          data['activity_score']!,
          _activityScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityScoreMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MetricSnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetricSnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_key'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      )!,
      openPrs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}open_prs'],
      )!,
      needsReview: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}needs_review'],
      )!,
      activityScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}activity_score'],
      )!,
    );
  }

  @override
  $MetricSnapshotsTable createAlias(String alias) {
    return $MetricSnapshotsTable(attachedDatabase, alias);
  }
}

class MetricSnapshotRow extends DataClass
    implements Insertable<MetricSnapshotRow> {
  final int id;
  final String repoKey;
  final int capturedAt;
  final int openPrs;
  final int needsReview;
  final double activityScore;
  const MetricSnapshotRow({
    required this.id,
    required this.repoKey,
    required this.capturedAt,
    required this.openPrs,
    required this.needsReview,
    required this.activityScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['repo_key'] = Variable<String>(repoKey);
    map['captured_at'] = Variable<int>(capturedAt);
    map['open_prs'] = Variable<int>(openPrs);
    map['needs_review'] = Variable<int>(needsReview);
    map['activity_score'] = Variable<double>(activityScore);
    return map;
  }

  MetricSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return MetricSnapshotsCompanion(
      id: Value(id),
      repoKey: Value(repoKey),
      capturedAt: Value(capturedAt),
      openPrs: Value(openPrs),
      needsReview: Value(needsReview),
      activityScore: Value(activityScore),
    );
  }

  factory MetricSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetricSnapshotRow(
      id: serializer.fromJson<int>(json['id']),
      repoKey: serializer.fromJson<String>(json['repoKey']),
      capturedAt: serializer.fromJson<int>(json['capturedAt']),
      openPrs: serializer.fromJson<int>(json['openPrs']),
      needsReview: serializer.fromJson<int>(json['needsReview']),
      activityScore: serializer.fromJson<double>(json['activityScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repoKey': serializer.toJson<String>(repoKey),
      'capturedAt': serializer.toJson<int>(capturedAt),
      'openPrs': serializer.toJson<int>(openPrs),
      'needsReview': serializer.toJson<int>(needsReview),
      'activityScore': serializer.toJson<double>(activityScore),
    };
  }

  MetricSnapshotRow copyWith({
    int? id,
    String? repoKey,
    int? capturedAt,
    int? openPrs,
    int? needsReview,
    double? activityScore,
  }) => MetricSnapshotRow(
    id: id ?? this.id,
    repoKey: repoKey ?? this.repoKey,
    capturedAt: capturedAt ?? this.capturedAt,
    openPrs: openPrs ?? this.openPrs,
    needsReview: needsReview ?? this.needsReview,
    activityScore: activityScore ?? this.activityScore,
  );
  MetricSnapshotRow copyWithCompanion(MetricSnapshotsCompanion data) {
    return MetricSnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      repoKey: data.repoKey.present ? data.repoKey.value : this.repoKey,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      openPrs: data.openPrs.present ? data.openPrs.value : this.openPrs,
      needsReview: data.needsReview.present
          ? data.needsReview.value
          : this.needsReview,
      activityScore: data.activityScore.present
          ? data.activityScore.value
          : this.activityScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetricSnapshotRow(')
          ..write('id: $id, ')
          ..write('repoKey: $repoKey, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('openPrs: $openPrs, ')
          ..write('needsReview: $needsReview, ')
          ..write('activityScore: $activityScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, repoKey, capturedAt, openPrs, needsReview, activityScore);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetricSnapshotRow &&
          other.id == this.id &&
          other.repoKey == this.repoKey &&
          other.capturedAt == this.capturedAt &&
          other.openPrs == this.openPrs &&
          other.needsReview == this.needsReview &&
          other.activityScore == this.activityScore);
}

class MetricSnapshotsCompanion extends UpdateCompanion<MetricSnapshotRow> {
  final Value<int> id;
  final Value<String> repoKey;
  final Value<int> capturedAt;
  final Value<int> openPrs;
  final Value<int> needsReview;
  final Value<double> activityScore;
  const MetricSnapshotsCompanion({
    this.id = const Value.absent(),
    this.repoKey = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.openPrs = const Value.absent(),
    this.needsReview = const Value.absent(),
    this.activityScore = const Value.absent(),
  });
  MetricSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required String repoKey,
    required int capturedAt,
    required int openPrs,
    required int needsReview,
    required double activityScore,
  }) : repoKey = Value(repoKey),
       capturedAt = Value(capturedAt),
       openPrs = Value(openPrs),
       needsReview = Value(needsReview),
       activityScore = Value(activityScore);
  static Insertable<MetricSnapshotRow> custom({
    Expression<int>? id,
    Expression<String>? repoKey,
    Expression<int>? capturedAt,
    Expression<int>? openPrs,
    Expression<int>? needsReview,
    Expression<double>? activityScore,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repoKey != null) 'repo_key': repoKey,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (openPrs != null) 'open_prs': openPrs,
      if (needsReview != null) 'needs_review': needsReview,
      if (activityScore != null) 'activity_score': activityScore,
    });
  }

  MetricSnapshotsCompanion copyWith({
    Value<int>? id,
    Value<String>? repoKey,
    Value<int>? capturedAt,
    Value<int>? openPrs,
    Value<int>? needsReview,
    Value<double>? activityScore,
  }) {
    return MetricSnapshotsCompanion(
      id: id ?? this.id,
      repoKey: repoKey ?? this.repoKey,
      capturedAt: capturedAt ?? this.capturedAt,
      openPrs: openPrs ?? this.openPrs,
      needsReview: needsReview ?? this.needsReview,
      activityScore: activityScore ?? this.activityScore,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repoKey.present) {
      map['repo_key'] = Variable<String>(repoKey.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (openPrs.present) {
      map['open_prs'] = Variable<int>(openPrs.value);
    }
    if (needsReview.present) {
      map['needs_review'] = Variable<int>(needsReview.value);
    }
    if (activityScore.present) {
      map['activity_score'] = Variable<double>(activityScore.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetricSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('repoKey: $repoKey, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('openPrs: $openPrs, ')
          ..write('needsReview: $needsReview, ')
          ..write('activityScore: $activityScore')
          ..write(')'))
        .toString();
  }
}

class $AppMetaTable extends AppMeta with TableInfo<$AppMetaTable, AppMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class AppMetaRow extends DataClass implements Insertable<AppMetaRow> {
  final String key;
  final String value;
  const AppMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetaRow copyWith({String? key, String? value}) =>
      AppMetaRow(key: key ?? this.key, value: value ?? this.value);
  AppMetaRow copyWithCompanion(AppMetaCompanion data) {
    return AppMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MetricSnapshotsTable metricSnapshots = $MetricSnapshotsTable(
    this,
  );
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final Index idxMetricSnapshotsRepoKey = Index(
    'idx_metric_snapshots_repo_key',
    'CREATE INDEX idx_metric_snapshots_repo_key ON metric_snapshots (repo_key)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    metricSnapshots,
    appMeta,
    idxMetricSnapshotsRepoKey,
  ];
}

typedef $$MetricSnapshotsTableCreateCompanionBuilder =
    MetricSnapshotsCompanion Function({
      Value<int> id,
      required String repoKey,
      required int capturedAt,
      required int openPrs,
      required int needsReview,
      required double activityScore,
    });
typedef $$MetricSnapshotsTableUpdateCompanionBuilder =
    MetricSnapshotsCompanion Function({
      Value<int> id,
      Value<String> repoKey,
      Value<int> capturedAt,
      Value<int> openPrs,
      Value<int> needsReview,
      Value<double> activityScore,
    });

class $$MetricSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $MetricSnapshotsTable> {
  $$MetricSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoKey => $composableBuilder(
    column: $table.repoKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openPrs => $composableBuilder(
    column: $table.openPrs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get activityScore => $composableBuilder(
    column: $table.activityScore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetricSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $MetricSnapshotsTable> {
  $$MetricSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoKey => $composableBuilder(
    column: $table.repoKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openPrs => $composableBuilder(
    column: $table.openPrs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get activityScore => $composableBuilder(
    column: $table.activityScore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetricSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetricSnapshotsTable> {
  $$MetricSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get repoKey =>
      $composableBuilder(column: $table.repoKey, builder: (column) => column);

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get openPrs =>
      $composableBuilder(column: $table.openPrs, builder: (column) => column);

  GeneratedColumn<int> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => column,
  );

  GeneratedColumn<double> get activityScore => $composableBuilder(
    column: $table.activityScore,
    builder: (column) => column,
  );
}

class $$MetricSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetricSnapshotsTable,
          MetricSnapshotRow,
          $$MetricSnapshotsTableFilterComposer,
          $$MetricSnapshotsTableOrderingComposer,
          $$MetricSnapshotsTableAnnotationComposer,
          $$MetricSnapshotsTableCreateCompanionBuilder,
          $$MetricSnapshotsTableUpdateCompanionBuilder,
          (
            MetricSnapshotRow,
            BaseReferences<
              _$AppDatabase,
              $MetricSnapshotsTable,
              MetricSnapshotRow
            >,
          ),
          MetricSnapshotRow,
          PrefetchHooks Function()
        > {
  $$MetricSnapshotsTableTableManager(
    _$AppDatabase db,
    $MetricSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetricSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetricSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetricSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> repoKey = const Value.absent(),
                Value<int> capturedAt = const Value.absent(),
                Value<int> openPrs = const Value.absent(),
                Value<int> needsReview = const Value.absent(),
                Value<double> activityScore = const Value.absent(),
              }) => MetricSnapshotsCompanion(
                id: id,
                repoKey: repoKey,
                capturedAt: capturedAt,
                openPrs: openPrs,
                needsReview: needsReview,
                activityScore: activityScore,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String repoKey,
                required int capturedAt,
                required int openPrs,
                required int needsReview,
                required double activityScore,
              }) => MetricSnapshotsCompanion.insert(
                id: id,
                repoKey: repoKey,
                capturedAt: capturedAt,
                openPrs: openPrs,
                needsReview: needsReview,
                activityScore: activityScore,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetricSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetricSnapshotsTable,
      MetricSnapshotRow,
      $$MetricSnapshotsTableFilterComposer,
      $$MetricSnapshotsTableOrderingComposer,
      $$MetricSnapshotsTableAnnotationComposer,
      $$MetricSnapshotsTableCreateCompanionBuilder,
      $$MetricSnapshotsTableUpdateCompanionBuilder,
      (
        MetricSnapshotRow,
        BaseReferences<_$AppDatabase, $MetricSnapshotsTable, MetricSnapshotRow>,
      ),
      MetricSnapshotRow,
      PrefetchHooks Function()
    >;
typedef $$AppMetaTableCreateCompanionBuilder =
    AppMetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppMetaTableUpdateCompanionBuilder =
    AppMetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppMetaTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetaTable,
          AppMetaRow,
          $$AppMetaTableFilterComposer,
          $$AppMetaTableOrderingComposer,
          $$AppMetaTableAnnotationComposer,
          $$AppMetaTableCreateCompanionBuilder,
          $$AppMetaTableUpdateCompanionBuilder,
          (
            AppMetaRow,
            BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaRow>,
          ),
          AppMetaRow,
          PrefetchHooks Function()
        > {
  $$AppMetaTableTableManager(_$AppDatabase db, $AppMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) =>
                  AppMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetaTable,
      AppMetaRow,
      $$AppMetaTableFilterComposer,
      $$AppMetaTableOrderingComposer,
      $$AppMetaTableAnnotationComposer,
      $$AppMetaTableCreateCompanionBuilder,
      $$AppMetaTableUpdateCompanionBuilder,
      (AppMetaRow, BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaRow>),
      AppMetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MetricSnapshotsTableTableManager get metricSnapshots =>
      $$MetricSnapshotsTableTableManager(_db, _db.metricSnapshots);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
}
