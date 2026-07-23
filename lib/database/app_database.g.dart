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

class $ActivityEventsTable extends ActivityEvents
    with TableInfo<$ActivityEventsTable, ActivityEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _repoDisplayMeta = const VerificationMeta(
    'repoDisplay',
  );
  @override
  late final GeneratedColumn<String> repoDisplay = GeneratedColumn<String>(
    'repo_display',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorMeta = const VerificationMeta('actor');
  @override
  late final GeneratedColumn<String> actor = GeneratedColumn<String>(
    'actor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isMineMeta = const VerificationMeta('isMine');
  @override
  late final GeneratedColumn<bool> isMine = GeneratedColumn<bool>(
    'is_mine',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_mine" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    type,
    provider,
    repoKey,
    repoDisplay,
    actor,
    title,
    subtitle,
    occurredAt,
    url,
    isMine,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('repo_key')) {
      context.handle(
        _repoKeyMeta,
        repoKey.isAcceptableOrUnknown(data['repo_key']!, _repoKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_repoKeyMeta);
    }
    if (data.containsKey('repo_display')) {
      context.handle(
        _repoDisplayMeta,
        repoDisplay.isAcceptableOrUnknown(
          data['repo_display']!,
          _repoDisplayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repoDisplayMeta);
    }
    if (data.containsKey('actor')) {
      context.handle(
        _actorMeta,
        actor.isAcceptableOrUnknown(data['actor']!, _actorMeta),
      );
    } else if (isInserting) {
      context.missing(_actorMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    } else if (isInserting) {
      context.missing(_subtitleMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('is_mine')) {
      context.handle(
        _isMineMeta,
        isMine.isAcceptableOrUnknown(data['is_mine']!, _isMineMeta),
      );
    } else if (isInserting) {
      context.missing(_isMineMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      repoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_key'],
      )!,
      repoDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_display'],
      )!,
      actor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      isMine: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_mine'],
      )!,
    );
  }

  @override
  $ActivityEventsTable createAlias(String alias) {
    return $ActivityEventsTable(attachedDatabase, alias);
  }
}

class ActivityEventRow extends DataClass
    implements Insertable<ActivityEventRow> {
  final int id;
  final String eventId;
  final String type;
  final String provider;
  final String repoKey;
  final String repoDisplay;
  final String actor;
  final String title;
  final String subtitle;
  final int occurredAt;
  final String? url;
  final bool isMine;
  const ActivityEventRow({
    required this.id,
    required this.eventId,
    required this.type,
    required this.provider,
    required this.repoKey,
    required this.repoDisplay,
    required this.actor,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    this.url,
    required this.isMine,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<String>(eventId);
    map['type'] = Variable<String>(type);
    map['provider'] = Variable<String>(provider);
    map['repo_key'] = Variable<String>(repoKey);
    map['repo_display'] = Variable<String>(repoDisplay);
    map['actor'] = Variable<String>(actor);
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['occurred_at'] = Variable<int>(occurredAt);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    map['is_mine'] = Variable<bool>(isMine);
    return map;
  }

  ActivityEventsCompanion toCompanion(bool nullToAbsent) {
    return ActivityEventsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      type: Value(type),
      provider: Value(provider),
      repoKey: Value(repoKey),
      repoDisplay: Value(repoDisplay),
      actor: Value(actor),
      title: Value(title),
      subtitle: Value(subtitle),
      occurredAt: Value(occurredAt),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      isMine: Value(isMine),
    );
  }

  factory ActivityEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityEventRow(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      type: serializer.fromJson<String>(json['type']),
      provider: serializer.fromJson<String>(json['provider']),
      repoKey: serializer.fromJson<String>(json['repoKey']),
      repoDisplay: serializer.fromJson<String>(json['repoDisplay']),
      actor: serializer.fromJson<String>(json['actor']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      url: serializer.fromJson<String?>(json['url']),
      isMine: serializer.fromJson<bool>(json['isMine']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<String>(eventId),
      'type': serializer.toJson<String>(type),
      'provider': serializer.toJson<String>(provider),
      'repoKey': serializer.toJson<String>(repoKey),
      'repoDisplay': serializer.toJson<String>(repoDisplay),
      'actor': serializer.toJson<String>(actor),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'url': serializer.toJson<String?>(url),
      'isMine': serializer.toJson<bool>(isMine),
    };
  }

  ActivityEventRow copyWith({
    int? id,
    String? eventId,
    String? type,
    String? provider,
    String? repoKey,
    String? repoDisplay,
    String? actor,
    String? title,
    String? subtitle,
    int? occurredAt,
    Value<String?> url = const Value.absent(),
    bool? isMine,
  }) => ActivityEventRow(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    type: type ?? this.type,
    provider: provider ?? this.provider,
    repoKey: repoKey ?? this.repoKey,
    repoDisplay: repoDisplay ?? this.repoDisplay,
    actor: actor ?? this.actor,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    occurredAt: occurredAt ?? this.occurredAt,
    url: url.present ? url.value : this.url,
    isMine: isMine ?? this.isMine,
  );
  ActivityEventRow copyWithCompanion(ActivityEventsCompanion data) {
    return ActivityEventRow(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      type: data.type.present ? data.type.value : this.type,
      provider: data.provider.present ? data.provider.value : this.provider,
      repoKey: data.repoKey.present ? data.repoKey.value : this.repoKey,
      repoDisplay: data.repoDisplay.present
          ? data.repoDisplay.value
          : this.repoDisplay,
      actor: data.actor.present ? data.actor.value : this.actor,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      url: data.url.present ? data.url.value : this.url,
      isMine: data.isMine.present ? data.isMine.value : this.isMine,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventRow(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('type: $type, ')
          ..write('provider: $provider, ')
          ..write('repoKey: $repoKey, ')
          ..write('repoDisplay: $repoDisplay, ')
          ..write('actor: $actor, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('url: $url, ')
          ..write('isMine: $isMine')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    type,
    provider,
    repoKey,
    repoDisplay,
    actor,
    title,
    subtitle,
    occurredAt,
    url,
    isMine,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityEventRow &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.type == this.type &&
          other.provider == this.provider &&
          other.repoKey == this.repoKey &&
          other.repoDisplay == this.repoDisplay &&
          other.actor == this.actor &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.occurredAt == this.occurredAt &&
          other.url == this.url &&
          other.isMine == this.isMine);
}

class ActivityEventsCompanion extends UpdateCompanion<ActivityEventRow> {
  final Value<int> id;
  final Value<String> eventId;
  final Value<String> type;
  final Value<String> provider;
  final Value<String> repoKey;
  final Value<String> repoDisplay;
  final Value<String> actor;
  final Value<String> title;
  final Value<String> subtitle;
  final Value<int> occurredAt;
  final Value<String?> url;
  final Value<bool> isMine;
  const ActivityEventsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.type = const Value.absent(),
    this.provider = const Value.absent(),
    this.repoKey = const Value.absent(),
    this.repoDisplay = const Value.absent(),
    this.actor = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.url = const Value.absent(),
    this.isMine = const Value.absent(),
  });
  ActivityEventsCompanion.insert({
    this.id = const Value.absent(),
    required String eventId,
    required String type,
    required String provider,
    required String repoKey,
    required String repoDisplay,
    required String actor,
    required String title,
    required String subtitle,
    required int occurredAt,
    this.url = const Value.absent(),
    required bool isMine,
  }) : eventId = Value(eventId),
       type = Value(type),
       provider = Value(provider),
       repoKey = Value(repoKey),
       repoDisplay = Value(repoDisplay),
       actor = Value(actor),
       title = Value(title),
       subtitle = Value(subtitle),
       occurredAt = Value(occurredAt),
       isMine = Value(isMine);
  static Insertable<ActivityEventRow> custom({
    Expression<int>? id,
    Expression<String>? eventId,
    Expression<String>? type,
    Expression<String>? provider,
    Expression<String>? repoKey,
    Expression<String>? repoDisplay,
    Expression<String>? actor,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<int>? occurredAt,
    Expression<String>? url,
    Expression<bool>? isMine,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (type != null) 'type': type,
      if (provider != null) 'provider': provider,
      if (repoKey != null) 'repo_key': repoKey,
      if (repoDisplay != null) 'repo_display': repoDisplay,
      if (actor != null) 'actor': actor,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (url != null) 'url': url,
      if (isMine != null) 'is_mine': isMine,
    });
  }

  ActivityEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? eventId,
    Value<String>? type,
    Value<String>? provider,
    Value<String>? repoKey,
    Value<String>? repoDisplay,
    Value<String>? actor,
    Value<String>? title,
    Value<String>? subtitle,
    Value<int>? occurredAt,
    Value<String?>? url,
    Value<bool>? isMine,
  }) {
    return ActivityEventsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      provider: provider ?? this.provider,
      repoKey: repoKey ?? this.repoKey,
      repoDisplay: repoDisplay ?? this.repoDisplay,
      actor: actor ?? this.actor,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      occurredAt: occurredAt ?? this.occurredAt,
      url: url ?? this.url,
      isMine: isMine ?? this.isMine,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (repoKey.present) {
      map['repo_key'] = Variable<String>(repoKey.value);
    }
    if (repoDisplay.present) {
      map['repo_display'] = Variable<String>(repoDisplay.value);
    }
    if (actor.present) {
      map['actor'] = Variable<String>(actor.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (isMine.present) {
      map['is_mine'] = Variable<bool>(isMine.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('type: $type, ')
          ..write('provider: $provider, ')
          ..write('repoKey: $repoKey, ')
          ..write('repoDisplay: $repoDisplay, ')
          ..write('actor: $actor, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('url: $url, ')
          ..write('isMine: $isMine')
          ..write(')'))
        .toString();
  }
}

class $AttentionItemsTable extends AttentionItems
    with TableInfo<$AttentionItemsTable, AttentionItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttentionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<int> severity = GeneratedColumn<int>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoDisplayMeta = const VerificationMeta(
    'repoDisplay',
  );
  @override
  late final GeneratedColumn<String> repoDisplay = GeneratedColumn<String>(
    'repo_display',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageDaysMeta = const VerificationMeta(
    'ageDays',
  );
  @override
  late final GeneratedColumn<int> ageDays = GeneratedColumn<int>(
    'age_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isMineMeta = const VerificationMeta('isMine');
  @override
  late final GeneratedColumn<bool> isMine = GeneratedColumn<bool>(
    'is_mine',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_mine" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    severity,
    title,
    subtitle,
    repoDisplay,
    url,
    ageDays,
    createdAt,
    isMine,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attention_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttentionItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    } else if (isInserting) {
      context.missing(_subtitleMeta);
    }
    if (data.containsKey('repo_display')) {
      context.handle(
        _repoDisplayMeta,
        repoDisplay.isAcceptableOrUnknown(
          data['repo_display']!,
          _repoDisplayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repoDisplayMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('age_days')) {
      context.handle(
        _ageDaysMeta,
        ageDays.isAcceptableOrUnknown(data['age_days']!, _ageDaysMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('is_mine')) {
      context.handle(
        _isMineMeta,
        isMine.isAcceptableOrUnknown(data['is_mine']!, _isMineMeta),
      );
    } else if (isInserting) {
      context.missing(_isMineMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttentionItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttentionItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}severity'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      repoDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_display'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      ageDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age_days'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      isMine: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_mine'],
      )!,
    );
  }

  @override
  $AttentionItemsTable createAlias(String alias) {
    return $AttentionItemsTable(attachedDatabase, alias);
  }
}

class AttentionItemRow extends DataClass
    implements Insertable<AttentionItemRow> {
  final String id;
  final String category;
  final int severity;
  final String title;
  final String subtitle;
  final String repoDisplay;
  final String? url;
  final int? ageDays;
  final int? createdAt;
  final bool isMine;
  const AttentionItemRow({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.repoDisplay,
    this.url,
    this.ageDays,
    this.createdAt,
    required this.isMine,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['severity'] = Variable<int>(severity);
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['repo_display'] = Variable<String>(repoDisplay);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || ageDays != null) {
      map['age_days'] = Variable<int>(ageDays);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    map['is_mine'] = Variable<bool>(isMine);
    return map;
  }

  AttentionItemsCompanion toCompanion(bool nullToAbsent) {
    return AttentionItemsCompanion(
      id: Value(id),
      category: Value(category),
      severity: Value(severity),
      title: Value(title),
      subtitle: Value(subtitle),
      repoDisplay: Value(repoDisplay),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      ageDays: ageDays == null && nullToAbsent
          ? const Value.absent()
          : Value(ageDays),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      isMine: Value(isMine),
    );
  }

  factory AttentionItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttentionItemRow(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      severity: serializer.fromJson<int>(json['severity']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      repoDisplay: serializer.fromJson<String>(json['repoDisplay']),
      url: serializer.fromJson<String?>(json['url']),
      ageDays: serializer.fromJson<int?>(json['ageDays']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      isMine: serializer.fromJson<bool>(json['isMine']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'severity': serializer.toJson<int>(severity),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'repoDisplay': serializer.toJson<String>(repoDisplay),
      'url': serializer.toJson<String?>(url),
      'ageDays': serializer.toJson<int?>(ageDays),
      'createdAt': serializer.toJson<int?>(createdAt),
      'isMine': serializer.toJson<bool>(isMine),
    };
  }

  AttentionItemRow copyWith({
    String? id,
    String? category,
    int? severity,
    String? title,
    String? subtitle,
    String? repoDisplay,
    Value<String?> url = const Value.absent(),
    Value<int?> ageDays = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
    bool? isMine,
  }) => AttentionItemRow(
    id: id ?? this.id,
    category: category ?? this.category,
    severity: severity ?? this.severity,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    repoDisplay: repoDisplay ?? this.repoDisplay,
    url: url.present ? url.value : this.url,
    ageDays: ageDays.present ? ageDays.value : this.ageDays,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    isMine: isMine ?? this.isMine,
  );
  AttentionItemRow copyWithCompanion(AttentionItemsCompanion data) {
    return AttentionItemRow(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      severity: data.severity.present ? data.severity.value : this.severity,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      repoDisplay: data.repoDisplay.present
          ? data.repoDisplay.value
          : this.repoDisplay,
      url: data.url.present ? data.url.value : this.url,
      ageDays: data.ageDays.present ? data.ageDays.value : this.ageDays,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isMine: data.isMine.present ? data.isMine.value : this.isMine,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttentionItemRow(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('severity: $severity, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('repoDisplay: $repoDisplay, ')
          ..write('url: $url, ')
          ..write('ageDays: $ageDays, ')
          ..write('createdAt: $createdAt, ')
          ..write('isMine: $isMine')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    severity,
    title,
    subtitle,
    repoDisplay,
    url,
    ageDays,
    createdAt,
    isMine,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttentionItemRow &&
          other.id == this.id &&
          other.category == this.category &&
          other.severity == this.severity &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.repoDisplay == this.repoDisplay &&
          other.url == this.url &&
          other.ageDays == this.ageDays &&
          other.createdAt == this.createdAt &&
          other.isMine == this.isMine);
}

class AttentionItemsCompanion extends UpdateCompanion<AttentionItemRow> {
  final Value<String> id;
  final Value<String> category;
  final Value<int> severity;
  final Value<String> title;
  final Value<String> subtitle;
  final Value<String> repoDisplay;
  final Value<String?> url;
  final Value<int?> ageDays;
  final Value<int?> createdAt;
  final Value<bool> isMine;
  final Value<int> rowid;
  const AttentionItemsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.severity = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.repoDisplay = const Value.absent(),
    this.url = const Value.absent(),
    this.ageDays = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isMine = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttentionItemsCompanion.insert({
    required String id,
    required String category,
    required int severity,
    required String title,
    required String subtitle,
    required String repoDisplay,
    this.url = const Value.absent(),
    this.ageDays = const Value.absent(),
    this.createdAt = const Value.absent(),
    required bool isMine,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       severity = Value(severity),
       title = Value(title),
       subtitle = Value(subtitle),
       repoDisplay = Value(repoDisplay),
       isMine = Value(isMine);
  static Insertable<AttentionItemRow> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<int>? severity,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? repoDisplay,
    Expression<String>? url,
    Expression<int>? ageDays,
    Expression<int>? createdAt,
    Expression<bool>? isMine,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (severity != null) 'severity': severity,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (repoDisplay != null) 'repo_display': repoDisplay,
      if (url != null) 'url': url,
      if (ageDays != null) 'age_days': ageDays,
      if (createdAt != null) 'created_at': createdAt,
      if (isMine != null) 'is_mine': isMine,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttentionItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<int>? severity,
    Value<String>? title,
    Value<String>? subtitle,
    Value<String>? repoDisplay,
    Value<String?>? url,
    Value<int?>? ageDays,
    Value<int?>? createdAt,
    Value<bool>? isMine,
    Value<int>? rowid,
  }) {
    return AttentionItemsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      repoDisplay: repoDisplay ?? this.repoDisplay,
      url: url ?? this.url,
      ageDays: ageDays ?? this.ageDays,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (severity.present) {
      map['severity'] = Variable<int>(severity.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (repoDisplay.present) {
      map['repo_display'] = Variable<String>(repoDisplay.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (ageDays.present) {
      map['age_days'] = Variable<int>(ageDays.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (isMine.present) {
      map['is_mine'] = Variable<bool>(isMine.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttentionItemsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('severity: $severity, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('repoDisplay: $repoDisplay, ')
          ..write('url: $url, ')
          ..write('ageDays: $ageDays, ')
          ..write('createdAt: $createdAt, ')
          ..write('isMine: $isMine, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RepoPullsTable extends RepoPulls
    with TableInfo<$RepoPullsTable, RepoPrRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepoPullsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewStateMeta = const VerificationMeta(
    'reviewState',
  );
  @override
  late final GeneratedColumn<String> reviewState = GeneratedColumn<String>(
    'review_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageDaysMeta = const VerificationMeta(
    'ageDays',
  );
  @override
  late final GeneratedColumn<int> ageDays = GeneratedColumn<int>(
    'age_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _draftMeta = const VerificationMeta('draft');
  @override
  late final GeneratedColumn<bool> draft = GeneratedColumn<bool>(
    'draft',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("draft" IN (0, 1))',
    ),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mergeableMeta = const VerificationMeta(
    'mergeable',
  );
  @override
  late final GeneratedColumn<String> mergeable = GeneratedColumn<String>(
    'mergeable',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _additionsMeta = const VerificationMeta(
    'additions',
  );
  @override
  late final GeneratedColumn<int> additions = GeneratedColumn<int>(
    'additions',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletionsMeta = const VerificationMeta(
    'deletions',
  );
  @override
  late final GeneratedColumn<int> deletions = GeneratedColumn<int>(
    'deletions',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changedFilesMeta = const VerificationMeta(
    'changedFiles',
  );
  @override
  late final GeneratedColumn<int> changedFiles = GeneratedColumn<int>(
    'changed_files',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repoKey,
    label,
    title,
    author,
    reviewState,
    ageDays,
    createdAt,
    draft,
    url,
    mergeable,
    additions,
    deletions,
    changedFiles,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repo_pulls';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepoPrRow> instance, {
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
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('review_state')) {
      context.handle(
        _reviewStateMeta,
        reviewState.isAcceptableOrUnknown(
          data['review_state']!,
          _reviewStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reviewStateMeta);
    }
    if (data.containsKey('age_days')) {
      context.handle(
        _ageDaysMeta,
        ageDays.isAcceptableOrUnknown(data['age_days']!, _ageDaysMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('draft')) {
      context.handle(
        _draftMeta,
        draft.isAcceptableOrUnknown(data['draft']!, _draftMeta),
      );
    } else if (isInserting) {
      context.missing(_draftMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('mergeable')) {
      context.handle(
        _mergeableMeta,
        mergeable.isAcceptableOrUnknown(data['mergeable']!, _mergeableMeta),
      );
    }
    if (data.containsKey('additions')) {
      context.handle(
        _additionsMeta,
        additions.isAcceptableOrUnknown(data['additions']!, _additionsMeta),
      );
    }
    if (data.containsKey('deletions')) {
      context.handle(
        _deletionsMeta,
        deletions.isAcceptableOrUnknown(data['deletions']!, _deletionsMeta),
      );
    }
    if (data.containsKey('changed_files')) {
      context.handle(
        _changedFilesMeta,
        changedFiles.isAcceptableOrUnknown(
          data['changed_files']!,
          _changedFilesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepoPrRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepoPrRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_key'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      reviewState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review_state'],
      )!,
      ageDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age_days'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      draft: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}draft'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      mergeable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mergeable'],
      ),
      additions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}additions'],
      ),
      deletions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deletions'],
      ),
      changedFiles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}changed_files'],
      ),
    );
  }

  @override
  $RepoPullsTable createAlias(String alias) {
    return $RepoPullsTable(attachedDatabase, alias);
  }
}

class RepoPrRow extends DataClass implements Insertable<RepoPrRow> {
  final int id;
  final String repoKey;
  final String label;
  final String title;
  final String author;
  final String reviewState;
  final int? ageDays;
  final int? createdAt;
  final bool draft;
  final String? url;
  final String? mergeable;
  final int? additions;
  final int? deletions;
  final int? changedFiles;
  const RepoPrRow({
    required this.id,
    required this.repoKey,
    required this.label,
    required this.title,
    required this.author,
    required this.reviewState,
    this.ageDays,
    this.createdAt,
    required this.draft,
    this.url,
    this.mergeable,
    this.additions,
    this.deletions,
    this.changedFiles,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['repo_key'] = Variable<String>(repoKey);
    map['label'] = Variable<String>(label);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['review_state'] = Variable<String>(reviewState);
    if (!nullToAbsent || ageDays != null) {
      map['age_days'] = Variable<int>(ageDays);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    map['draft'] = Variable<bool>(draft);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || mergeable != null) {
      map['mergeable'] = Variable<String>(mergeable);
    }
    if (!nullToAbsent || additions != null) {
      map['additions'] = Variable<int>(additions);
    }
    if (!nullToAbsent || deletions != null) {
      map['deletions'] = Variable<int>(deletions);
    }
    if (!nullToAbsent || changedFiles != null) {
      map['changed_files'] = Variable<int>(changedFiles);
    }
    return map;
  }

  RepoPullsCompanion toCompanion(bool nullToAbsent) {
    return RepoPullsCompanion(
      id: Value(id),
      repoKey: Value(repoKey),
      label: Value(label),
      title: Value(title),
      author: Value(author),
      reviewState: Value(reviewState),
      ageDays: ageDays == null && nullToAbsent
          ? const Value.absent()
          : Value(ageDays),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      draft: Value(draft),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      mergeable: mergeable == null && nullToAbsent
          ? const Value.absent()
          : Value(mergeable),
      additions: additions == null && nullToAbsent
          ? const Value.absent()
          : Value(additions),
      deletions: deletions == null && nullToAbsent
          ? const Value.absent()
          : Value(deletions),
      changedFiles: changedFiles == null && nullToAbsent
          ? const Value.absent()
          : Value(changedFiles),
    );
  }

  factory RepoPrRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepoPrRow(
      id: serializer.fromJson<int>(json['id']),
      repoKey: serializer.fromJson<String>(json['repoKey']),
      label: serializer.fromJson<String>(json['label']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      reviewState: serializer.fromJson<String>(json['reviewState']),
      ageDays: serializer.fromJson<int?>(json['ageDays']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      draft: serializer.fromJson<bool>(json['draft']),
      url: serializer.fromJson<String?>(json['url']),
      mergeable: serializer.fromJson<String?>(json['mergeable']),
      additions: serializer.fromJson<int?>(json['additions']),
      deletions: serializer.fromJson<int?>(json['deletions']),
      changedFiles: serializer.fromJson<int?>(json['changedFiles']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repoKey': serializer.toJson<String>(repoKey),
      'label': serializer.toJson<String>(label),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'reviewState': serializer.toJson<String>(reviewState),
      'ageDays': serializer.toJson<int?>(ageDays),
      'createdAt': serializer.toJson<int?>(createdAt),
      'draft': serializer.toJson<bool>(draft),
      'url': serializer.toJson<String?>(url),
      'mergeable': serializer.toJson<String?>(mergeable),
      'additions': serializer.toJson<int?>(additions),
      'deletions': serializer.toJson<int?>(deletions),
      'changedFiles': serializer.toJson<int?>(changedFiles),
    };
  }

  RepoPrRow copyWith({
    int? id,
    String? repoKey,
    String? label,
    String? title,
    String? author,
    String? reviewState,
    Value<int?> ageDays = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
    bool? draft,
    Value<String?> url = const Value.absent(),
    Value<String?> mergeable = const Value.absent(),
    Value<int?> additions = const Value.absent(),
    Value<int?> deletions = const Value.absent(),
    Value<int?> changedFiles = const Value.absent(),
  }) => RepoPrRow(
    id: id ?? this.id,
    repoKey: repoKey ?? this.repoKey,
    label: label ?? this.label,
    title: title ?? this.title,
    author: author ?? this.author,
    reviewState: reviewState ?? this.reviewState,
    ageDays: ageDays.present ? ageDays.value : this.ageDays,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    draft: draft ?? this.draft,
    url: url.present ? url.value : this.url,
    mergeable: mergeable.present ? mergeable.value : this.mergeable,
    additions: additions.present ? additions.value : this.additions,
    deletions: deletions.present ? deletions.value : this.deletions,
    changedFiles: changedFiles.present ? changedFiles.value : this.changedFiles,
  );
  RepoPrRow copyWithCompanion(RepoPullsCompanion data) {
    return RepoPrRow(
      id: data.id.present ? data.id.value : this.id,
      repoKey: data.repoKey.present ? data.repoKey.value : this.repoKey,
      label: data.label.present ? data.label.value : this.label,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      reviewState: data.reviewState.present
          ? data.reviewState.value
          : this.reviewState,
      ageDays: data.ageDays.present ? data.ageDays.value : this.ageDays,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      draft: data.draft.present ? data.draft.value : this.draft,
      url: data.url.present ? data.url.value : this.url,
      mergeable: data.mergeable.present ? data.mergeable.value : this.mergeable,
      additions: data.additions.present ? data.additions.value : this.additions,
      deletions: data.deletions.present ? data.deletions.value : this.deletions,
      changedFiles: data.changedFiles.present
          ? data.changedFiles.value
          : this.changedFiles,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepoPrRow(')
          ..write('id: $id, ')
          ..write('repoKey: $repoKey, ')
          ..write('label: $label, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('reviewState: $reviewState, ')
          ..write('ageDays: $ageDays, ')
          ..write('createdAt: $createdAt, ')
          ..write('draft: $draft, ')
          ..write('url: $url, ')
          ..write('mergeable: $mergeable, ')
          ..write('additions: $additions, ')
          ..write('deletions: $deletions, ')
          ..write('changedFiles: $changedFiles')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repoKey,
    label,
    title,
    author,
    reviewState,
    ageDays,
    createdAt,
    draft,
    url,
    mergeable,
    additions,
    deletions,
    changedFiles,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepoPrRow &&
          other.id == this.id &&
          other.repoKey == this.repoKey &&
          other.label == this.label &&
          other.title == this.title &&
          other.author == this.author &&
          other.reviewState == this.reviewState &&
          other.ageDays == this.ageDays &&
          other.createdAt == this.createdAt &&
          other.draft == this.draft &&
          other.url == this.url &&
          other.mergeable == this.mergeable &&
          other.additions == this.additions &&
          other.deletions == this.deletions &&
          other.changedFiles == this.changedFiles);
}

class RepoPullsCompanion extends UpdateCompanion<RepoPrRow> {
  final Value<int> id;
  final Value<String> repoKey;
  final Value<String> label;
  final Value<String> title;
  final Value<String> author;
  final Value<String> reviewState;
  final Value<int?> ageDays;
  final Value<int?> createdAt;
  final Value<bool> draft;
  final Value<String?> url;
  final Value<String?> mergeable;
  final Value<int?> additions;
  final Value<int?> deletions;
  final Value<int?> changedFiles;
  const RepoPullsCompanion({
    this.id = const Value.absent(),
    this.repoKey = const Value.absent(),
    this.label = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.reviewState = const Value.absent(),
    this.ageDays = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.draft = const Value.absent(),
    this.url = const Value.absent(),
    this.mergeable = const Value.absent(),
    this.additions = const Value.absent(),
    this.deletions = const Value.absent(),
    this.changedFiles = const Value.absent(),
  });
  RepoPullsCompanion.insert({
    this.id = const Value.absent(),
    required String repoKey,
    required String label,
    required String title,
    required String author,
    required String reviewState,
    this.ageDays = const Value.absent(),
    this.createdAt = const Value.absent(),
    required bool draft,
    this.url = const Value.absent(),
    this.mergeable = const Value.absent(),
    this.additions = const Value.absent(),
    this.deletions = const Value.absent(),
    this.changedFiles = const Value.absent(),
  }) : repoKey = Value(repoKey),
       label = Value(label),
       title = Value(title),
       author = Value(author),
       reviewState = Value(reviewState),
       draft = Value(draft);
  static Insertable<RepoPrRow> custom({
    Expression<int>? id,
    Expression<String>? repoKey,
    Expression<String>? label,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? reviewState,
    Expression<int>? ageDays,
    Expression<int>? createdAt,
    Expression<bool>? draft,
    Expression<String>? url,
    Expression<String>? mergeable,
    Expression<int>? additions,
    Expression<int>? deletions,
    Expression<int>? changedFiles,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repoKey != null) 'repo_key': repoKey,
      if (label != null) 'label': label,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (reviewState != null) 'review_state': reviewState,
      if (ageDays != null) 'age_days': ageDays,
      if (createdAt != null) 'created_at': createdAt,
      if (draft != null) 'draft': draft,
      if (url != null) 'url': url,
      if (mergeable != null) 'mergeable': mergeable,
      if (additions != null) 'additions': additions,
      if (deletions != null) 'deletions': deletions,
      if (changedFiles != null) 'changed_files': changedFiles,
    });
  }

  RepoPullsCompanion copyWith({
    Value<int>? id,
    Value<String>? repoKey,
    Value<String>? label,
    Value<String>? title,
    Value<String>? author,
    Value<String>? reviewState,
    Value<int?>? ageDays,
    Value<int?>? createdAt,
    Value<bool>? draft,
    Value<String?>? url,
    Value<String?>? mergeable,
    Value<int?>? additions,
    Value<int?>? deletions,
    Value<int?>? changedFiles,
  }) {
    return RepoPullsCompanion(
      id: id ?? this.id,
      repoKey: repoKey ?? this.repoKey,
      label: label ?? this.label,
      title: title ?? this.title,
      author: author ?? this.author,
      reviewState: reviewState ?? this.reviewState,
      ageDays: ageDays ?? this.ageDays,
      createdAt: createdAt ?? this.createdAt,
      draft: draft ?? this.draft,
      url: url ?? this.url,
      mergeable: mergeable ?? this.mergeable,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      changedFiles: changedFiles ?? this.changedFiles,
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
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (reviewState.present) {
      map['review_state'] = Variable<String>(reviewState.value);
    }
    if (ageDays.present) {
      map['age_days'] = Variable<int>(ageDays.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (draft.present) {
      map['draft'] = Variable<bool>(draft.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (mergeable.present) {
      map['mergeable'] = Variable<String>(mergeable.value);
    }
    if (additions.present) {
      map['additions'] = Variable<int>(additions.value);
    }
    if (deletions.present) {
      map['deletions'] = Variable<int>(deletions.value);
    }
    if (changedFiles.present) {
      map['changed_files'] = Variable<int>(changedFiles.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepoPullsCompanion(')
          ..write('id: $id, ')
          ..write('repoKey: $repoKey, ')
          ..write('label: $label, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('reviewState: $reviewState, ')
          ..write('ageDays: $ageDays, ')
          ..write('createdAt: $createdAt, ')
          ..write('draft: $draft, ')
          ..write('url: $url, ')
          ..write('mergeable: $mergeable, ')
          ..write('additions: $additions, ')
          ..write('deletions: $deletions, ')
          ..write('changedFiles: $changedFiles')
          ..write(')'))
        .toString();
  }
}

class $RepoRunsTable extends RepoRuns
    with TableInfo<$RepoRunsTable, RepoRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepoRunsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conclusionMeta = const VerificationMeta(
    'conclusion',
  );
  @override
  late final GeneratedColumn<String> conclusion = GeneratedColumn<String>(
    'conclusion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
    'branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<int> finishedAt = GeneratedColumn<int>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repoKey,
    name,
    status,
    conclusion,
    branch,
    finishedAt,
    url,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repo_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepoRunRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('conclusion')) {
      context.handle(
        _conclusionMeta,
        conclusion.isAcceptableOrUnknown(data['conclusion']!, _conclusionMeta),
      );
    } else if (isInserting) {
      context.missing(_conclusionMeta);
    }
    if (data.containsKey('branch')) {
      context.handle(
        _branchMeta,
        branch.isAcceptableOrUnknown(data['branch']!, _branchMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepoRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepoRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      conclusion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conclusion'],
      )!,
      branch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished_at'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
    );
  }

  @override
  $RepoRunsTable createAlias(String alias) {
    return $RepoRunsTable(attachedDatabase, alias);
  }
}

class RepoRunRow extends DataClass implements Insertable<RepoRunRow> {
  final int id;
  final String repoKey;
  final String name;
  final String status;
  final String conclusion;
  final String? branch;
  final int? finishedAt;
  final String? url;
  const RepoRunRow({
    required this.id,
    required this.repoKey,
    required this.name,
    required this.status,
    required this.conclusion,
    this.branch,
    this.finishedAt,
    this.url,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['repo_key'] = Variable<String>(repoKey);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['conclusion'] = Variable<String>(conclusion);
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(finishedAt);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    return map;
  }

  RepoRunsCompanion toCompanion(bool nullToAbsent) {
    return RepoRunsCompanion(
      id: Value(id),
      repoKey: Value(repoKey),
      name: Value(name),
      status: Value(status),
      conclusion: Value(conclusion),
      branch: branch == null && nullToAbsent
          ? const Value.absent()
          : Value(branch),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
    );
  }

  factory RepoRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepoRunRow(
      id: serializer.fromJson<int>(json['id']),
      repoKey: serializer.fromJson<String>(json['repoKey']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      conclusion: serializer.fromJson<String>(json['conclusion']),
      branch: serializer.fromJson<String?>(json['branch']),
      finishedAt: serializer.fromJson<int?>(json['finishedAt']),
      url: serializer.fromJson<String?>(json['url']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repoKey': serializer.toJson<String>(repoKey),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'conclusion': serializer.toJson<String>(conclusion),
      'branch': serializer.toJson<String?>(branch),
      'finishedAt': serializer.toJson<int?>(finishedAt),
      'url': serializer.toJson<String?>(url),
    };
  }

  RepoRunRow copyWith({
    int? id,
    String? repoKey,
    String? name,
    String? status,
    String? conclusion,
    Value<String?> branch = const Value.absent(),
    Value<int?> finishedAt = const Value.absent(),
    Value<String?> url = const Value.absent(),
  }) => RepoRunRow(
    id: id ?? this.id,
    repoKey: repoKey ?? this.repoKey,
    name: name ?? this.name,
    status: status ?? this.status,
    conclusion: conclusion ?? this.conclusion,
    branch: branch.present ? branch.value : this.branch,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    url: url.present ? url.value : this.url,
  );
  RepoRunRow copyWithCompanion(RepoRunsCompanion data) {
    return RepoRunRow(
      id: data.id.present ? data.id.value : this.id,
      repoKey: data.repoKey.present ? data.repoKey.value : this.repoKey,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      conclusion: data.conclusion.present
          ? data.conclusion.value
          : this.conclusion,
      branch: data.branch.present ? data.branch.value : this.branch,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      url: data.url.present ? data.url.value : this.url,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepoRunRow(')
          ..write('id: $id, ')
          ..write('repoKey: $repoKey, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('conclusion: $conclusion, ')
          ..write('branch: $branch, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('url: $url')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repoKey,
    name,
    status,
    conclusion,
    branch,
    finishedAt,
    url,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepoRunRow &&
          other.id == this.id &&
          other.repoKey == this.repoKey &&
          other.name == this.name &&
          other.status == this.status &&
          other.conclusion == this.conclusion &&
          other.branch == this.branch &&
          other.finishedAt == this.finishedAt &&
          other.url == this.url);
}

class RepoRunsCompanion extends UpdateCompanion<RepoRunRow> {
  final Value<int> id;
  final Value<String> repoKey;
  final Value<String> name;
  final Value<String> status;
  final Value<String> conclusion;
  final Value<String?> branch;
  final Value<int?> finishedAt;
  final Value<String?> url;
  const RepoRunsCompanion({
    this.id = const Value.absent(),
    this.repoKey = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.conclusion = const Value.absent(),
    this.branch = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.url = const Value.absent(),
  });
  RepoRunsCompanion.insert({
    this.id = const Value.absent(),
    required String repoKey,
    required String name,
    required String status,
    required String conclusion,
    this.branch = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.url = const Value.absent(),
  }) : repoKey = Value(repoKey),
       name = Value(name),
       status = Value(status),
       conclusion = Value(conclusion);
  static Insertable<RepoRunRow> custom({
    Expression<int>? id,
    Expression<String>? repoKey,
    Expression<String>? name,
    Expression<String>? status,
    Expression<String>? conclusion,
    Expression<String>? branch,
    Expression<int>? finishedAt,
    Expression<String>? url,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repoKey != null) 'repo_key': repoKey,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (conclusion != null) 'conclusion': conclusion,
      if (branch != null) 'branch': branch,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (url != null) 'url': url,
    });
  }

  RepoRunsCompanion copyWith({
    Value<int>? id,
    Value<String>? repoKey,
    Value<String>? name,
    Value<String>? status,
    Value<String>? conclusion,
    Value<String?>? branch,
    Value<int?>? finishedAt,
    Value<String?>? url,
  }) {
    return RepoRunsCompanion(
      id: id ?? this.id,
      repoKey: repoKey ?? this.repoKey,
      name: name ?? this.name,
      status: status ?? this.status,
      conclusion: conclusion ?? this.conclusion,
      branch: branch ?? this.branch,
      finishedAt: finishedAt ?? this.finishedAt,
      url: url ?? this.url,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (conclusion.present) {
      map['conclusion'] = Variable<String>(conclusion.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(finishedAt.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepoRunsCompanion(')
          ..write('id: $id, ')
          ..write('repoKey: $repoKey, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('conclusion: $conclusion, ')
          ..write('branch: $branch, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('url: $url')
          ..write(')'))
        .toString();
  }
}

class $RepoReleasesTable extends RepoReleases
    with TableInfo<$RepoReleasesTable, RepoReleaseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepoReleasesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<int> publishedAt = GeneratedColumn<int>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repoKey,
    tag,
    name,
    author,
    publishedAt,
    url,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repo_releases';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepoReleaseRow> instance, {
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
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepoReleaseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepoReleaseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_key'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_at'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
    );
  }

  @override
  $RepoReleasesTable createAlias(String alias) {
    return $RepoReleasesTable(attachedDatabase, alias);
  }
}

class RepoReleaseRow extends DataClass implements Insertable<RepoReleaseRow> {
  final int id;
  final String repoKey;
  final String tag;
  final String? name;
  final String? author;
  final int? publishedAt;
  final String? url;
  const RepoReleaseRow({
    required this.id,
    required this.repoKey,
    required this.tag,
    this.name,
    this.author,
    this.publishedAt,
    this.url,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['repo_key'] = Variable<String>(repoKey);
    map['tag'] = Variable<String>(tag);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<int>(publishedAt);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    return map;
  }

  RepoReleasesCompanion toCompanion(bool nullToAbsent) {
    return RepoReleasesCompanion(
      id: Value(id),
      repoKey: Value(repoKey),
      tag: Value(tag),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
    );
  }

  factory RepoReleaseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepoReleaseRow(
      id: serializer.fromJson<int>(json['id']),
      repoKey: serializer.fromJson<String>(json['repoKey']),
      tag: serializer.fromJson<String>(json['tag']),
      name: serializer.fromJson<String?>(json['name']),
      author: serializer.fromJson<String?>(json['author']),
      publishedAt: serializer.fromJson<int?>(json['publishedAt']),
      url: serializer.fromJson<String?>(json['url']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repoKey': serializer.toJson<String>(repoKey),
      'tag': serializer.toJson<String>(tag),
      'name': serializer.toJson<String?>(name),
      'author': serializer.toJson<String?>(author),
      'publishedAt': serializer.toJson<int?>(publishedAt),
      'url': serializer.toJson<String?>(url),
    };
  }

  RepoReleaseRow copyWith({
    int? id,
    String? repoKey,
    String? tag,
    Value<String?> name = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<int?> publishedAt = const Value.absent(),
    Value<String?> url = const Value.absent(),
  }) => RepoReleaseRow(
    id: id ?? this.id,
    repoKey: repoKey ?? this.repoKey,
    tag: tag ?? this.tag,
    name: name.present ? name.value : this.name,
    author: author.present ? author.value : this.author,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    url: url.present ? url.value : this.url,
  );
  RepoReleaseRow copyWithCompanion(RepoReleasesCompanion data) {
    return RepoReleaseRow(
      id: data.id.present ? data.id.value : this.id,
      repoKey: data.repoKey.present ? data.repoKey.value : this.repoKey,
      tag: data.tag.present ? data.tag.value : this.tag,
      name: data.name.present ? data.name.value : this.name,
      author: data.author.present ? data.author.value : this.author,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      url: data.url.present ? data.url.value : this.url,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepoReleaseRow(')
          ..write('id: $id, ')
          ..write('repoKey: $repoKey, ')
          ..write('tag: $tag, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('url: $url')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, repoKey, tag, name, author, publishedAt, url);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepoReleaseRow &&
          other.id == this.id &&
          other.repoKey == this.repoKey &&
          other.tag == this.tag &&
          other.name == this.name &&
          other.author == this.author &&
          other.publishedAt == this.publishedAt &&
          other.url == this.url);
}

class RepoReleasesCompanion extends UpdateCompanion<RepoReleaseRow> {
  final Value<int> id;
  final Value<String> repoKey;
  final Value<String> tag;
  final Value<String?> name;
  final Value<String?> author;
  final Value<int?> publishedAt;
  final Value<String?> url;
  const RepoReleasesCompanion({
    this.id = const Value.absent(),
    this.repoKey = const Value.absent(),
    this.tag = const Value.absent(),
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.url = const Value.absent(),
  });
  RepoReleasesCompanion.insert({
    this.id = const Value.absent(),
    required String repoKey,
    required String tag,
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.url = const Value.absent(),
  }) : repoKey = Value(repoKey),
       tag = Value(tag);
  static Insertable<RepoReleaseRow> custom({
    Expression<int>? id,
    Expression<String>? repoKey,
    Expression<String>? tag,
    Expression<String>? name,
    Expression<String>? author,
    Expression<int>? publishedAt,
    Expression<String>? url,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repoKey != null) 'repo_key': repoKey,
      if (tag != null) 'tag': tag,
      if (name != null) 'name': name,
      if (author != null) 'author': author,
      if (publishedAt != null) 'published_at': publishedAt,
      if (url != null) 'url': url,
    });
  }

  RepoReleasesCompanion copyWith({
    Value<int>? id,
    Value<String>? repoKey,
    Value<String>? tag,
    Value<String?>? name,
    Value<String?>? author,
    Value<int?>? publishedAt,
    Value<String?>? url,
  }) {
    return RepoReleasesCompanion(
      id: id ?? this.id,
      repoKey: repoKey ?? this.repoKey,
      tag: tag ?? this.tag,
      name: name ?? this.name,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      url: url ?? this.url,
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
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(publishedAt.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepoReleasesCompanion(')
          ..write('id: $id, ')
          ..write('repoKey: $repoKey, ')
          ..write('tag: $tag, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('url: $url')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSuccessAtMeta = const VerificationMeta(
    'lastSuccessAt',
  );
  @override
  late final GeneratedColumn<int> lastSuccessAt = GeneratedColumn<int>(
    'last_success_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [scope, lastSuccessAt, etag, cursor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('last_success_at')) {
      context.handle(
        _lastSuccessAtMeta,
        lastSuccessAt.isAcceptableOrUnknown(
          data['last_success_at']!,
          _lastSuccessAtMeta,
        ),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      lastSuccessAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_success_at'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String scope;
  final int? lastSuccessAt;
  final String? etag;
  final String? cursor;
  const SyncStateRow({
    required this.scope,
    this.lastSuccessAt,
    this.etag,
    this.cursor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<int>(lastSuccessAt);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      scope: Value(scope),
      lastSuccessAt: lastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessAt),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      scope: serializer.fromJson<String>(json['scope']),
      lastSuccessAt: serializer.fromJson<int?>(json['lastSuccessAt']),
      etag: serializer.fromJson<String?>(json['etag']),
      cursor: serializer.fromJson<String?>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'lastSuccessAt': serializer.toJson<int?>(lastSuccessAt),
      'etag': serializer.toJson<String?>(etag),
      'cursor': serializer.toJson<String?>(cursor),
    };
  }

  SyncStateRow copyWith({
    String? scope,
    Value<int?> lastSuccessAt = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    Value<String?> cursor = const Value.absent(),
  }) => SyncStateRow(
    scope: scope ?? this.scope,
    lastSuccessAt: lastSuccessAt.present
        ? lastSuccessAt.value
        : this.lastSuccessAt,
    etag: etag.present ? etag.value : this.etag,
    cursor: cursor.present ? cursor.value : this.cursor,
  );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
      etag: data.etag.present ? data.etag.value : this.etag,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('scope: $scope, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('etag: $etag, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, lastSuccessAt, etag, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.scope == this.scope &&
          other.lastSuccessAt == this.lastSuccessAt &&
          other.etag == this.etag &&
          other.cursor == this.cursor);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> scope;
  final Value<int?> lastSuccessAt;
  final Value<String?> etag;
  final Value<String?> cursor;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.scope = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.etag = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String scope,
    this.lastSuccessAt = const Value.absent(),
    this.etag = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope);
  static Insertable<SyncStateRow> custom({
    Expression<String>? scope,
    Expression<int>? lastSuccessAt,
    Expression<String>? etag,
    Expression<String>? cursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (etag != null) 'etag': etag,
      if (cursor != null) 'cursor': cursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? scope,
    Value<int?>? lastSuccessAt,
    Value<String?>? etag,
    Value<String?>? cursor,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      scope: scope ?? this.scope,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      etag: etag ?? this.etag,
      cursor: cursor ?? this.cursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<int>(lastSuccessAt.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('scope: $scope, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('etag: $etag, ')
          ..write('cursor: $cursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationSeenTable extends NotificationSeen
    with TableInfo<$NotificationSeenTable, NotificationSeenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationSeenTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _seenIdMeta = const VerificationMeta('seenId');
  @override
  late final GeneratedColumn<String> seenId = GeneratedColumn<String>(
    'seen_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, seenId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_seen';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationSeenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('seen_id')) {
      context.handle(
        _seenIdMeta,
        seenId.isAcceptableOrUnknown(data['seen_id']!, _seenIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seenIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationSeenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationSeenRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      seenId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seen_id'],
      )!,
    );
  }

  @override
  $NotificationSeenTable createAlias(String alias) {
    return $NotificationSeenTable(attachedDatabase, alias);
  }
}

class NotificationSeenRow extends DataClass
    implements Insertable<NotificationSeenRow> {
  final int id;
  final String seenId;
  const NotificationSeenRow({required this.id, required this.seenId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['seen_id'] = Variable<String>(seenId);
    return map;
  }

  NotificationSeenCompanion toCompanion(bool nullToAbsent) {
    return NotificationSeenCompanion(id: Value(id), seenId: Value(seenId));
  }

  factory NotificationSeenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationSeenRow(
      id: serializer.fromJson<int>(json['id']),
      seenId: serializer.fromJson<String>(json['seenId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'seenId': serializer.toJson<String>(seenId),
    };
  }

  NotificationSeenRow copyWith({int? id, String? seenId}) =>
      NotificationSeenRow(id: id ?? this.id, seenId: seenId ?? this.seenId);
  NotificationSeenRow copyWithCompanion(NotificationSeenCompanion data) {
    return NotificationSeenRow(
      id: data.id.present ? data.id.value : this.id,
      seenId: data.seenId.present ? data.seenId.value : this.seenId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSeenRow(')
          ..write('id: $id, ')
          ..write('seenId: $seenId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, seenId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationSeenRow &&
          other.id == this.id &&
          other.seenId == this.seenId);
}

class NotificationSeenCompanion extends UpdateCompanion<NotificationSeenRow> {
  final Value<int> id;
  final Value<String> seenId;
  const NotificationSeenCompanion({
    this.id = const Value.absent(),
    this.seenId = const Value.absent(),
  });
  NotificationSeenCompanion.insert({
    this.id = const Value.absent(),
    required String seenId,
  }) : seenId = Value(seenId);
  static Insertable<NotificationSeenRow> custom({
    Expression<int>? id,
    Expression<String>? seenId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seenId != null) 'seen_id': seenId,
    });
  }

  NotificationSeenCompanion copyWith({Value<int>? id, Value<String>? seenId}) {
    return NotificationSeenCompanion(
      id: id ?? this.id,
      seenId: seenId ?? this.seenId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (seenId.present) {
      map['seen_id'] = Variable<String>(seenId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSeenCompanion(')
          ..write('id: $id, ')
          ..write('seenId: $seenId')
          ..write(')'))
        .toString();
  }
}

class $NotificationKnownReposTable extends NotificationKnownRepos
    with TableInfo<$NotificationKnownReposTable, NotificationKnownRepoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationKnownReposTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _repoDisplayMeta = const VerificationMeta(
    'repoDisplay',
  );
  @override
  late final GeneratedColumn<String> repoDisplay = GeneratedColumn<String>(
    'repo_display',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [repoDisplay];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_known_repos';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationKnownRepoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('repo_display')) {
      context.handle(
        _repoDisplayMeta,
        repoDisplay.isAcceptableOrUnknown(
          data['repo_display']!,
          _repoDisplayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repoDisplayMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {repoDisplay};
  @override
  NotificationKnownRepoRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationKnownRepoRow(
      repoDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_display'],
      )!,
    );
  }

  @override
  $NotificationKnownReposTable createAlias(String alias) {
    return $NotificationKnownReposTable(attachedDatabase, alias);
  }
}

class NotificationKnownRepoRow extends DataClass
    implements Insertable<NotificationKnownRepoRow> {
  final String repoDisplay;
  const NotificationKnownRepoRow({required this.repoDisplay});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['repo_display'] = Variable<String>(repoDisplay);
    return map;
  }

  NotificationKnownReposCompanion toCompanion(bool nullToAbsent) {
    return NotificationKnownReposCompanion(repoDisplay: Value(repoDisplay));
  }

  factory NotificationKnownRepoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationKnownRepoRow(
      repoDisplay: serializer.fromJson<String>(json['repoDisplay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'repoDisplay': serializer.toJson<String>(repoDisplay),
    };
  }

  NotificationKnownRepoRow copyWith({String? repoDisplay}) =>
      NotificationKnownRepoRow(repoDisplay: repoDisplay ?? this.repoDisplay);
  NotificationKnownRepoRow copyWithCompanion(
    NotificationKnownReposCompanion data,
  ) {
    return NotificationKnownRepoRow(
      repoDisplay: data.repoDisplay.present
          ? data.repoDisplay.value
          : this.repoDisplay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationKnownRepoRow(')
          ..write('repoDisplay: $repoDisplay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => repoDisplay.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationKnownRepoRow &&
          other.repoDisplay == this.repoDisplay);
}

class NotificationKnownReposCompanion
    extends UpdateCompanion<NotificationKnownRepoRow> {
  final Value<String> repoDisplay;
  final Value<int> rowid;
  const NotificationKnownReposCompanion({
    this.repoDisplay = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationKnownReposCompanion.insert({
    required String repoDisplay,
    this.rowid = const Value.absent(),
  }) : repoDisplay = Value(repoDisplay);
  static Insertable<NotificationKnownRepoRow> custom({
    Expression<String>? repoDisplay,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (repoDisplay != null) 'repo_display': repoDisplay,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationKnownReposCompanion copyWith({
    Value<String>? repoDisplay,
    Value<int>? rowid,
  }) {
    return NotificationKnownReposCompanion(
      repoDisplay: repoDisplay ?? this.repoDisplay,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (repoDisplay.present) {
      map['repo_display'] = Variable<String>(repoDisplay.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationKnownReposCompanion(')
          ..write('repoDisplay: $repoDisplay, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CiRunHistoryTable extends CiRunHistory
    with TableInfo<$CiRunHistoryTable, CiRunHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CiRunHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _repoDisplayMeta = const VerificationMeta(
    'repoDisplay',
  );
  @override
  late final GeneratedColumn<String> repoDisplay = GeneratedColumn<String>(
    'repo_display',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workflowMeta = const VerificationMeta(
    'workflow',
  );
  @override
  late final GeneratedColumn<String> workflow = GeneratedColumn<String>(
    'workflow',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workflowIdMeta = const VerificationMeta(
    'workflowId',
  );
  @override
  late final GeneratedColumn<String> workflowId = GeneratedColumn<String>(
    'workflow_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runKeyMeta = const VerificationMeta('runKey');
  @override
  late final GeneratedColumn<String> runKey = GeneratedColumn<String>(
    'run_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conclusionMeta = const VerificationMeta(
    'conclusion',
  );
  @override
  late final GeneratedColumn<String> conclusion = GeneratedColumn<String>(
    'conclusion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
    'branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<int> finishedAt = GeneratedColumn<int>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    repoKey,
    repoDisplay,
    workflow,
    workflowId,
    runKey,
    outcome,
    conclusion,
    branch,
    finishedAt,
    durationMs,
    url,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ci_run_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<CiRunHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('repo_key')) {
      context.handle(
        _repoKeyMeta,
        repoKey.isAcceptableOrUnknown(data['repo_key']!, _repoKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_repoKeyMeta);
    }
    if (data.containsKey('repo_display')) {
      context.handle(
        _repoDisplayMeta,
        repoDisplay.isAcceptableOrUnknown(
          data['repo_display']!,
          _repoDisplayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repoDisplayMeta);
    }
    if (data.containsKey('workflow')) {
      context.handle(
        _workflowMeta,
        workflow.isAcceptableOrUnknown(data['workflow']!, _workflowMeta),
      );
    } else if (isInserting) {
      context.missing(_workflowMeta);
    }
    if (data.containsKey('workflow_id')) {
      context.handle(
        _workflowIdMeta,
        workflowId.isAcceptableOrUnknown(data['workflow_id']!, _workflowIdMeta),
      );
    }
    if (data.containsKey('run_key')) {
      context.handle(
        _runKeyMeta,
        runKey.isAcceptableOrUnknown(data['run_key']!, _runKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_runKeyMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('conclusion')) {
      context.handle(
        _conclusionMeta,
        conclusion.isAcceptableOrUnknown(data['conclusion']!, _conclusionMeta),
      );
    } else if (isInserting) {
      context.missing(_conclusionMeta);
    }
    if (data.containsKey('branch')) {
      context.handle(
        _branchMeta,
        branch.isAcceptableOrUnknown(data['branch']!, _branchMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CiRunHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CiRunHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      repoKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_key'],
      )!,
      repoDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_display'],
      )!,
      workflow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow'],
      )!,
      workflowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_id'],
      ),
      runKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_key'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      conclusion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conclusion'],
      )!,
      branch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finished_at'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
    );
  }

  @override
  $CiRunHistoryTable createAlias(String alias) {
    return $CiRunHistoryTable(attachedDatabase, alias);
  }
}

class CiRunHistoryRow extends DataClass implements Insertable<CiRunHistoryRow> {
  final int id;
  final String provider;
  final String repoKey;
  final String repoDisplay;
  final String workflow;
  final String? workflowId;
  final String runKey;
  final String outcome;
  final String conclusion;
  final String? branch;
  final int? finishedAt;
  final int? durationMs;
  final String? url;
  const CiRunHistoryRow({
    required this.id,
    required this.provider,
    required this.repoKey,
    required this.repoDisplay,
    required this.workflow,
    this.workflowId,
    required this.runKey,
    required this.outcome,
    required this.conclusion,
    this.branch,
    this.finishedAt,
    this.durationMs,
    this.url,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider'] = Variable<String>(provider);
    map['repo_key'] = Variable<String>(repoKey);
    map['repo_display'] = Variable<String>(repoDisplay);
    map['workflow'] = Variable<String>(workflow);
    if (!nullToAbsent || workflowId != null) {
      map['workflow_id'] = Variable<String>(workflowId);
    }
    map['run_key'] = Variable<String>(runKey);
    map['outcome'] = Variable<String>(outcome);
    map['conclusion'] = Variable<String>(conclusion);
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(finishedAt);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    return map;
  }

  CiRunHistoryCompanion toCompanion(bool nullToAbsent) {
    return CiRunHistoryCompanion(
      id: Value(id),
      provider: Value(provider),
      repoKey: Value(repoKey),
      repoDisplay: Value(repoDisplay),
      workflow: Value(workflow),
      workflowId: workflowId == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowId),
      runKey: Value(runKey),
      outcome: Value(outcome),
      conclusion: Value(conclusion),
      branch: branch == null && nullToAbsent
          ? const Value.absent()
          : Value(branch),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
    );
  }

  factory CiRunHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CiRunHistoryRow(
      id: serializer.fromJson<int>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      repoKey: serializer.fromJson<String>(json['repoKey']),
      repoDisplay: serializer.fromJson<String>(json['repoDisplay']),
      workflow: serializer.fromJson<String>(json['workflow']),
      workflowId: serializer.fromJson<String?>(json['workflowId']),
      runKey: serializer.fromJson<String>(json['runKey']),
      outcome: serializer.fromJson<String>(json['outcome']),
      conclusion: serializer.fromJson<String>(json['conclusion']),
      branch: serializer.fromJson<String?>(json['branch']),
      finishedAt: serializer.fromJson<int?>(json['finishedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      url: serializer.fromJson<String?>(json['url']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'provider': serializer.toJson<String>(provider),
      'repoKey': serializer.toJson<String>(repoKey),
      'repoDisplay': serializer.toJson<String>(repoDisplay),
      'workflow': serializer.toJson<String>(workflow),
      'workflowId': serializer.toJson<String?>(workflowId),
      'runKey': serializer.toJson<String>(runKey),
      'outcome': serializer.toJson<String>(outcome),
      'conclusion': serializer.toJson<String>(conclusion),
      'branch': serializer.toJson<String?>(branch),
      'finishedAt': serializer.toJson<int?>(finishedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'url': serializer.toJson<String?>(url),
    };
  }

  CiRunHistoryRow copyWith({
    int? id,
    String? provider,
    String? repoKey,
    String? repoDisplay,
    String? workflow,
    Value<String?> workflowId = const Value.absent(),
    String? runKey,
    String? outcome,
    String? conclusion,
    Value<String?> branch = const Value.absent(),
    Value<int?> finishedAt = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> url = const Value.absent(),
  }) => CiRunHistoryRow(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    repoKey: repoKey ?? this.repoKey,
    repoDisplay: repoDisplay ?? this.repoDisplay,
    workflow: workflow ?? this.workflow,
    workflowId: workflowId.present ? workflowId.value : this.workflowId,
    runKey: runKey ?? this.runKey,
    outcome: outcome ?? this.outcome,
    conclusion: conclusion ?? this.conclusion,
    branch: branch.present ? branch.value : this.branch,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    url: url.present ? url.value : this.url,
  );
  CiRunHistoryRow copyWithCompanion(CiRunHistoryCompanion data) {
    return CiRunHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      repoKey: data.repoKey.present ? data.repoKey.value : this.repoKey,
      repoDisplay: data.repoDisplay.present
          ? data.repoDisplay.value
          : this.repoDisplay,
      workflow: data.workflow.present ? data.workflow.value : this.workflow,
      workflowId: data.workflowId.present
          ? data.workflowId.value
          : this.workflowId,
      runKey: data.runKey.present ? data.runKey.value : this.runKey,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      conclusion: data.conclusion.present
          ? data.conclusion.value
          : this.conclusion,
      branch: data.branch.present ? data.branch.value : this.branch,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      url: data.url.present ? data.url.value : this.url,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CiRunHistoryRow(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('repoKey: $repoKey, ')
          ..write('repoDisplay: $repoDisplay, ')
          ..write('workflow: $workflow, ')
          ..write('workflowId: $workflowId, ')
          ..write('runKey: $runKey, ')
          ..write('outcome: $outcome, ')
          ..write('conclusion: $conclusion, ')
          ..write('branch: $branch, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('url: $url')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    repoKey,
    repoDisplay,
    workflow,
    workflowId,
    runKey,
    outcome,
    conclusion,
    branch,
    finishedAt,
    durationMs,
    url,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CiRunHistoryRow &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.repoKey == this.repoKey &&
          other.repoDisplay == this.repoDisplay &&
          other.workflow == this.workflow &&
          other.workflowId == this.workflowId &&
          other.runKey == this.runKey &&
          other.outcome == this.outcome &&
          other.conclusion == this.conclusion &&
          other.branch == this.branch &&
          other.finishedAt == this.finishedAt &&
          other.durationMs == this.durationMs &&
          other.url == this.url);
}

class CiRunHistoryCompanion extends UpdateCompanion<CiRunHistoryRow> {
  final Value<int> id;
  final Value<String> provider;
  final Value<String> repoKey;
  final Value<String> repoDisplay;
  final Value<String> workflow;
  final Value<String?> workflowId;
  final Value<String> runKey;
  final Value<String> outcome;
  final Value<String> conclusion;
  final Value<String?> branch;
  final Value<int?> finishedAt;
  final Value<int?> durationMs;
  final Value<String?> url;
  const CiRunHistoryCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.repoKey = const Value.absent(),
    this.repoDisplay = const Value.absent(),
    this.workflow = const Value.absent(),
    this.workflowId = const Value.absent(),
    this.runKey = const Value.absent(),
    this.outcome = const Value.absent(),
    this.conclusion = const Value.absent(),
    this.branch = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.url = const Value.absent(),
  });
  CiRunHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String provider,
    required String repoKey,
    required String repoDisplay,
    required String workflow,
    this.workflowId = const Value.absent(),
    required String runKey,
    required String outcome,
    required String conclusion,
    this.branch = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.url = const Value.absent(),
  }) : provider = Value(provider),
       repoKey = Value(repoKey),
       repoDisplay = Value(repoDisplay),
       workflow = Value(workflow),
       runKey = Value(runKey),
       outcome = Value(outcome),
       conclusion = Value(conclusion);
  static Insertable<CiRunHistoryRow> custom({
    Expression<int>? id,
    Expression<String>? provider,
    Expression<String>? repoKey,
    Expression<String>? repoDisplay,
    Expression<String>? workflow,
    Expression<String>? workflowId,
    Expression<String>? runKey,
    Expression<String>? outcome,
    Expression<String>? conclusion,
    Expression<String>? branch,
    Expression<int>? finishedAt,
    Expression<int>? durationMs,
    Expression<String>? url,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (repoKey != null) 'repo_key': repoKey,
      if (repoDisplay != null) 'repo_display': repoDisplay,
      if (workflow != null) 'workflow': workflow,
      if (workflowId != null) 'workflow_id': workflowId,
      if (runKey != null) 'run_key': runKey,
      if (outcome != null) 'outcome': outcome,
      if (conclusion != null) 'conclusion': conclusion,
      if (branch != null) 'branch': branch,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (url != null) 'url': url,
    });
  }

  CiRunHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? provider,
    Value<String>? repoKey,
    Value<String>? repoDisplay,
    Value<String>? workflow,
    Value<String?>? workflowId,
    Value<String>? runKey,
    Value<String>? outcome,
    Value<String>? conclusion,
    Value<String?>? branch,
    Value<int?>? finishedAt,
    Value<int?>? durationMs,
    Value<String?>? url,
  }) {
    return CiRunHistoryCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      repoKey: repoKey ?? this.repoKey,
      repoDisplay: repoDisplay ?? this.repoDisplay,
      workflow: workflow ?? this.workflow,
      workflowId: workflowId ?? this.workflowId,
      runKey: runKey ?? this.runKey,
      outcome: outcome ?? this.outcome,
      conclusion: conclusion ?? this.conclusion,
      branch: branch ?? this.branch,
      finishedAt: finishedAt ?? this.finishedAt,
      durationMs: durationMs ?? this.durationMs,
      url: url ?? this.url,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (repoKey.present) {
      map['repo_key'] = Variable<String>(repoKey.value);
    }
    if (repoDisplay.present) {
      map['repo_display'] = Variable<String>(repoDisplay.value);
    }
    if (workflow.present) {
      map['workflow'] = Variable<String>(workflow.value);
    }
    if (workflowId.present) {
      map['workflow_id'] = Variable<String>(workflowId.value);
    }
    if (runKey.present) {
      map['run_key'] = Variable<String>(runKey.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (conclusion.present) {
      map['conclusion'] = Variable<String>(conclusion.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(finishedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CiRunHistoryCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('repoKey: $repoKey, ')
          ..write('repoDisplay: $repoDisplay, ')
          ..write('workflow: $workflow, ')
          ..write('workflowId: $workflowId, ')
          ..write('runKey: $runKey, ')
          ..write('outcome: $outcome, ')
          ..write('conclusion: $conclusion, ')
          ..write('branch: $branch, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('url: $url')
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
  late final $ActivityEventsTable activityEvents = $ActivityEventsTable(this);
  late final $AttentionItemsTable attentionItems = $AttentionItemsTable(this);
  late final $RepoPullsTable repoPulls = $RepoPullsTable(this);
  late final $RepoRunsTable repoRuns = $RepoRunsTable(this);
  late final $RepoReleasesTable repoReleases = $RepoReleasesTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $NotificationSeenTable notificationSeen = $NotificationSeenTable(
    this,
  );
  late final $NotificationKnownReposTable notificationKnownRepos =
      $NotificationKnownReposTable(this);
  late final $CiRunHistoryTable ciRunHistory = $CiRunHistoryTable(this);
  late final Index idxMetricSnapshotsRepoKey = Index(
    'idx_metric_snapshots_repo_key',
    'CREATE INDEX idx_metric_snapshots_repo_key ON metric_snapshots (repo_key)',
  );
  late final Index idxActivityEventsRepoKey = Index(
    'idx_activity_events_repo_key',
    'CREATE INDEX idx_activity_events_repo_key ON activity_events (repo_key)',
  );
  late final Index idxActivityEventsOccurredAt = Index(
    'idx_activity_events_occurred_at',
    'CREATE INDEX idx_activity_events_occurred_at ON activity_events (occurred_at)',
  );
  late final Index idxActivityEventsRepoEvent = Index(
    'idx_activity_events_repo_event',
    'CREATE UNIQUE INDEX idx_activity_events_repo_event ON activity_events (repo_key, event_id)',
  );
  late final Index idxAttentionItemsRepoDisplay = Index(
    'idx_attention_items_repo_display',
    'CREATE INDEX idx_attention_items_repo_display ON attention_items (repo_display)',
  );
  late final Index idxRepoPullsRepoKey = Index(
    'idx_repo_pulls_repo_key',
    'CREATE INDEX idx_repo_pulls_repo_key ON repo_pulls (repo_key)',
  );
  late final Index idxRepoRunsRepoKey = Index(
    'idx_repo_runs_repo_key',
    'CREATE INDEX idx_repo_runs_repo_key ON repo_runs (repo_key)',
  );
  late final Index idxRepoReleasesRepoKey = Index(
    'idx_repo_releases_repo_key',
    'CREATE INDEX idx_repo_releases_repo_key ON repo_releases (repo_key)',
  );
  late final Index idxNotificationSeenSeenId = Index(
    'idx_notification_seen_seen_id',
    'CREATE UNIQUE INDEX idx_notification_seen_seen_id ON notification_seen (seen_id)',
  );
  late final Index idxCiRunHistoryRunKey = Index(
    'idx_ci_run_history_run_key',
    'CREATE UNIQUE INDEX idx_ci_run_history_run_key ON ci_run_history (run_key)',
  );
  late final Index idxCiRunHistoryRepoKey = Index(
    'idx_ci_run_history_repo_key',
    'CREATE INDEX idx_ci_run_history_repo_key ON ci_run_history (repo_key)',
  );
  late final Index idxCiRunHistoryFinishedAt = Index(
    'idx_ci_run_history_finished_at',
    'CREATE INDEX idx_ci_run_history_finished_at ON ci_run_history (finished_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    metricSnapshots,
    appMeta,
    activityEvents,
    attentionItems,
    repoPulls,
    repoRuns,
    repoReleases,
    syncState,
    notificationSeen,
    notificationKnownRepos,
    ciRunHistory,
    idxMetricSnapshotsRepoKey,
    idxActivityEventsRepoKey,
    idxActivityEventsOccurredAt,
    idxActivityEventsRepoEvent,
    idxAttentionItemsRepoDisplay,
    idxRepoPullsRepoKey,
    idxRepoRunsRepoKey,
    idxRepoReleasesRepoKey,
    idxNotificationSeenSeenId,
    idxCiRunHistoryRunKey,
    idxCiRunHistoryRepoKey,
    idxCiRunHistoryFinishedAt,
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
typedef $$ActivityEventsTableCreateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<int> id,
      required String eventId,
      required String type,
      required String provider,
      required String repoKey,
      required String repoDisplay,
      required String actor,
      required String title,
      required String subtitle,
      required int occurredAt,
      Value<String?> url,
      required bool isMine,
    });
typedef $$ActivityEventsTableUpdateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<int> id,
      Value<String> eventId,
      Value<String> type,
      Value<String> provider,
      Value<String> repoKey,
      Value<String> repoDisplay,
      Value<String> actor,
      Value<String> title,
      Value<String> subtitle,
      Value<int> occurredAt,
      Value<String?> url,
      Value<bool> isMine,
    });

class $$ActivityEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableFilterComposer({
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

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoKey => $composableBuilder(
    column: $table.repoKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMine => $composableBuilder(
    column: $table.isMine,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableOrderingComposer({
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

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoKey => $composableBuilder(
    column: $table.repoKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMine => $composableBuilder(
    column: $table.isMine,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get repoKey =>
      $composableBuilder(column: $table.repoKey, builder: (column) => column);

  GeneratedColumn<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actor =>
      $composableBuilder(column: $table.actor, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<bool> get isMine =>
      $composableBuilder(column: $table.isMine, builder: (column) => column);
}

class $$ActivityEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityEventsTable,
          ActivityEventRow,
          $$ActivityEventsTableFilterComposer,
          $$ActivityEventsTableOrderingComposer,
          $$ActivityEventsTableAnnotationComposer,
          $$ActivityEventsTableCreateCompanionBuilder,
          $$ActivityEventsTableUpdateCompanionBuilder,
          (
            ActivityEventRow,
            BaseReferences<
              _$AppDatabase,
              $ActivityEventsTable,
              ActivityEventRow
            >,
          ),
          ActivityEventRow,
          PrefetchHooks Function()
        > {
  $$ActivityEventsTableTableManager(
    _$AppDatabase db,
    $ActivityEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> repoKey = const Value.absent(),
                Value<String> repoDisplay = const Value.absent(),
                Value<String> actor = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<bool> isMine = const Value.absent(),
              }) => ActivityEventsCompanion(
                id: id,
                eventId: eventId,
                type: type,
                provider: provider,
                repoKey: repoKey,
                repoDisplay: repoDisplay,
                actor: actor,
                title: title,
                subtitle: subtitle,
                occurredAt: occurredAt,
                url: url,
                isMine: isMine,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String eventId,
                required String type,
                required String provider,
                required String repoKey,
                required String repoDisplay,
                required String actor,
                required String title,
                required String subtitle,
                required int occurredAt,
                Value<String?> url = const Value.absent(),
                required bool isMine,
              }) => ActivityEventsCompanion.insert(
                id: id,
                eventId: eventId,
                type: type,
                provider: provider,
                repoKey: repoKey,
                repoDisplay: repoDisplay,
                actor: actor,
                title: title,
                subtitle: subtitle,
                occurredAt: occurredAt,
                url: url,
                isMine: isMine,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityEventsTable,
      ActivityEventRow,
      $$ActivityEventsTableFilterComposer,
      $$ActivityEventsTableOrderingComposer,
      $$ActivityEventsTableAnnotationComposer,
      $$ActivityEventsTableCreateCompanionBuilder,
      $$ActivityEventsTableUpdateCompanionBuilder,
      (
        ActivityEventRow,
        BaseReferences<_$AppDatabase, $ActivityEventsTable, ActivityEventRow>,
      ),
      ActivityEventRow,
      PrefetchHooks Function()
    >;
typedef $$AttentionItemsTableCreateCompanionBuilder =
    AttentionItemsCompanion Function({
      required String id,
      required String category,
      required int severity,
      required String title,
      required String subtitle,
      required String repoDisplay,
      Value<String?> url,
      Value<int?> ageDays,
      Value<int?> createdAt,
      required bool isMine,
      Value<int> rowid,
    });
typedef $$AttentionItemsTableUpdateCompanionBuilder =
    AttentionItemsCompanion Function({
      Value<String> id,
      Value<String> category,
      Value<int> severity,
      Value<String> title,
      Value<String> subtitle,
      Value<String> repoDisplay,
      Value<String?> url,
      Value<int?> ageDays,
      Value<int?> createdAt,
      Value<bool> isMine,
      Value<int> rowid,
    });

class $$AttentionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $AttentionItemsTable> {
  $$AttentionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ageDays => $composableBuilder(
    column: $table.ageDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMine => $composableBuilder(
    column: $table.isMine,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttentionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttentionItemsTable> {
  $$AttentionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ageDays => $composableBuilder(
    column: $table.ageDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMine => $composableBuilder(
    column: $table.isMine,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttentionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttentionItemsTable> {
  $$AttentionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<int> get ageDays =>
      $composableBuilder(column: $table.ageDays, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isMine =>
      $composableBuilder(column: $table.isMine, builder: (column) => column);
}

class $$AttentionItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttentionItemsTable,
          AttentionItemRow,
          $$AttentionItemsTableFilterComposer,
          $$AttentionItemsTableOrderingComposer,
          $$AttentionItemsTableAnnotationComposer,
          $$AttentionItemsTableCreateCompanionBuilder,
          $$AttentionItemsTableUpdateCompanionBuilder,
          (
            AttentionItemRow,
            BaseReferences<
              _$AppDatabase,
              $AttentionItemsTable,
              AttentionItemRow
            >,
          ),
          AttentionItemRow,
          PrefetchHooks Function()
        > {
  $$AttentionItemsTableTableManager(
    _$AppDatabase db,
    $AttentionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttentionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttentionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttentionItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> severity = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String> repoDisplay = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<int?> ageDays = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<bool> isMine = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttentionItemsCompanion(
                id: id,
                category: category,
                severity: severity,
                title: title,
                subtitle: subtitle,
                repoDisplay: repoDisplay,
                url: url,
                ageDays: ageDays,
                createdAt: createdAt,
                isMine: isMine,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                required int severity,
                required String title,
                required String subtitle,
                required String repoDisplay,
                Value<String?> url = const Value.absent(),
                Value<int?> ageDays = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                required bool isMine,
                Value<int> rowid = const Value.absent(),
              }) => AttentionItemsCompanion.insert(
                id: id,
                category: category,
                severity: severity,
                title: title,
                subtitle: subtitle,
                repoDisplay: repoDisplay,
                url: url,
                ageDays: ageDays,
                createdAt: createdAt,
                isMine: isMine,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttentionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttentionItemsTable,
      AttentionItemRow,
      $$AttentionItemsTableFilterComposer,
      $$AttentionItemsTableOrderingComposer,
      $$AttentionItemsTableAnnotationComposer,
      $$AttentionItemsTableCreateCompanionBuilder,
      $$AttentionItemsTableUpdateCompanionBuilder,
      (
        AttentionItemRow,
        BaseReferences<_$AppDatabase, $AttentionItemsTable, AttentionItemRow>,
      ),
      AttentionItemRow,
      PrefetchHooks Function()
    >;
typedef $$RepoPullsTableCreateCompanionBuilder =
    RepoPullsCompanion Function({
      Value<int> id,
      required String repoKey,
      required String label,
      required String title,
      required String author,
      required String reviewState,
      Value<int?> ageDays,
      Value<int?> createdAt,
      required bool draft,
      Value<String?> url,
      Value<String?> mergeable,
      Value<int?> additions,
      Value<int?> deletions,
      Value<int?> changedFiles,
    });
typedef $$RepoPullsTableUpdateCompanionBuilder =
    RepoPullsCompanion Function({
      Value<int> id,
      Value<String> repoKey,
      Value<String> label,
      Value<String> title,
      Value<String> author,
      Value<String> reviewState,
      Value<int?> ageDays,
      Value<int?> createdAt,
      Value<bool> draft,
      Value<String?> url,
      Value<String?> mergeable,
      Value<int?> additions,
      Value<int?> deletions,
      Value<int?> changedFiles,
    });

class $$RepoPullsTableFilterComposer
    extends Composer<_$AppDatabase, $RepoPullsTable> {
  $$RepoPullsTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewState => $composableBuilder(
    column: $table.reviewState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ageDays => $composableBuilder(
    column: $table.ageDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get draft => $composableBuilder(
    column: $table.draft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mergeable => $composableBuilder(
    column: $table.mergeable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get additions => $composableBuilder(
    column: $table.additions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletions => $composableBuilder(
    column: $table.deletions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changedFiles => $composableBuilder(
    column: $table.changedFiles,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RepoPullsTableOrderingComposer
    extends Composer<_$AppDatabase, $RepoPullsTable> {
  $$RepoPullsTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewState => $composableBuilder(
    column: $table.reviewState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ageDays => $composableBuilder(
    column: $table.ageDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get draft => $composableBuilder(
    column: $table.draft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mergeable => $composableBuilder(
    column: $table.mergeable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get additions => $composableBuilder(
    column: $table.additions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletions => $composableBuilder(
    column: $table.deletions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changedFiles => $composableBuilder(
    column: $table.changedFiles,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepoPullsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepoPullsTable> {
  $$RepoPullsTableAnnotationComposer({
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

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get reviewState => $composableBuilder(
    column: $table.reviewState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ageDays =>
      $composableBuilder(column: $table.ageDays, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get draft =>
      $composableBuilder(column: $table.draft, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get mergeable =>
      $composableBuilder(column: $table.mergeable, builder: (column) => column);

  GeneratedColumn<int> get additions =>
      $composableBuilder(column: $table.additions, builder: (column) => column);

  GeneratedColumn<int> get deletions =>
      $composableBuilder(column: $table.deletions, builder: (column) => column);

  GeneratedColumn<int> get changedFiles => $composableBuilder(
    column: $table.changedFiles,
    builder: (column) => column,
  );
}

class $$RepoPullsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepoPullsTable,
          RepoPrRow,
          $$RepoPullsTableFilterComposer,
          $$RepoPullsTableOrderingComposer,
          $$RepoPullsTableAnnotationComposer,
          $$RepoPullsTableCreateCompanionBuilder,
          $$RepoPullsTableUpdateCompanionBuilder,
          (
            RepoPrRow,
            BaseReferences<_$AppDatabase, $RepoPullsTable, RepoPrRow>,
          ),
          RepoPrRow,
          PrefetchHooks Function()
        > {
  $$RepoPullsTableTableManager(_$AppDatabase db, $RepoPullsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepoPullsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepoPullsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepoPullsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> repoKey = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> reviewState = const Value.absent(),
                Value<int?> ageDays = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<bool> draft = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> mergeable = const Value.absent(),
                Value<int?> additions = const Value.absent(),
                Value<int?> deletions = const Value.absent(),
                Value<int?> changedFiles = const Value.absent(),
              }) => RepoPullsCompanion(
                id: id,
                repoKey: repoKey,
                label: label,
                title: title,
                author: author,
                reviewState: reviewState,
                ageDays: ageDays,
                createdAt: createdAt,
                draft: draft,
                url: url,
                mergeable: mergeable,
                additions: additions,
                deletions: deletions,
                changedFiles: changedFiles,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String repoKey,
                required String label,
                required String title,
                required String author,
                required String reviewState,
                Value<int?> ageDays = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                required bool draft,
                Value<String?> url = const Value.absent(),
                Value<String?> mergeable = const Value.absent(),
                Value<int?> additions = const Value.absent(),
                Value<int?> deletions = const Value.absent(),
                Value<int?> changedFiles = const Value.absent(),
              }) => RepoPullsCompanion.insert(
                id: id,
                repoKey: repoKey,
                label: label,
                title: title,
                author: author,
                reviewState: reviewState,
                ageDays: ageDays,
                createdAt: createdAt,
                draft: draft,
                url: url,
                mergeable: mergeable,
                additions: additions,
                deletions: deletions,
                changedFiles: changedFiles,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RepoPullsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepoPullsTable,
      RepoPrRow,
      $$RepoPullsTableFilterComposer,
      $$RepoPullsTableOrderingComposer,
      $$RepoPullsTableAnnotationComposer,
      $$RepoPullsTableCreateCompanionBuilder,
      $$RepoPullsTableUpdateCompanionBuilder,
      (RepoPrRow, BaseReferences<_$AppDatabase, $RepoPullsTable, RepoPrRow>),
      RepoPrRow,
      PrefetchHooks Function()
    >;
typedef $$RepoRunsTableCreateCompanionBuilder =
    RepoRunsCompanion Function({
      Value<int> id,
      required String repoKey,
      required String name,
      required String status,
      required String conclusion,
      Value<String?> branch,
      Value<int?> finishedAt,
      Value<String?> url,
    });
typedef $$RepoRunsTableUpdateCompanionBuilder =
    RepoRunsCompanion Function({
      Value<int> id,
      Value<String> repoKey,
      Value<String> name,
      Value<String> status,
      Value<String> conclusion,
      Value<String?> branch,
      Value<int?> finishedAt,
      Value<String?> url,
    });

class $$RepoRunsTableFilterComposer
    extends Composer<_$AppDatabase, $RepoRunsTable> {
  $$RepoRunsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conclusion => $composableBuilder(
    column: $table.conclusion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RepoRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $RepoRunsTable> {
  $$RepoRunsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conclusion => $composableBuilder(
    column: $table.conclusion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepoRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepoRunsTable> {
  $$RepoRunsTableAnnotationComposer({
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get conclusion => $composableBuilder(
    column: $table.conclusion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);
}

class $$RepoRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepoRunsTable,
          RepoRunRow,
          $$RepoRunsTableFilterComposer,
          $$RepoRunsTableOrderingComposer,
          $$RepoRunsTableAnnotationComposer,
          $$RepoRunsTableCreateCompanionBuilder,
          $$RepoRunsTableUpdateCompanionBuilder,
          (
            RepoRunRow,
            BaseReferences<_$AppDatabase, $RepoRunsTable, RepoRunRow>,
          ),
          RepoRunRow,
          PrefetchHooks Function()
        > {
  $$RepoRunsTableTableManager(_$AppDatabase db, $RepoRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepoRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepoRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepoRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> repoKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> conclusion = const Value.absent(),
                Value<String?> branch = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<String?> url = const Value.absent(),
              }) => RepoRunsCompanion(
                id: id,
                repoKey: repoKey,
                name: name,
                status: status,
                conclusion: conclusion,
                branch: branch,
                finishedAt: finishedAt,
                url: url,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String repoKey,
                required String name,
                required String status,
                required String conclusion,
                Value<String?> branch = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<String?> url = const Value.absent(),
              }) => RepoRunsCompanion.insert(
                id: id,
                repoKey: repoKey,
                name: name,
                status: status,
                conclusion: conclusion,
                branch: branch,
                finishedAt: finishedAt,
                url: url,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RepoRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepoRunsTable,
      RepoRunRow,
      $$RepoRunsTableFilterComposer,
      $$RepoRunsTableOrderingComposer,
      $$RepoRunsTableAnnotationComposer,
      $$RepoRunsTableCreateCompanionBuilder,
      $$RepoRunsTableUpdateCompanionBuilder,
      (RepoRunRow, BaseReferences<_$AppDatabase, $RepoRunsTable, RepoRunRow>),
      RepoRunRow,
      PrefetchHooks Function()
    >;
typedef $$RepoReleasesTableCreateCompanionBuilder =
    RepoReleasesCompanion Function({
      Value<int> id,
      required String repoKey,
      required String tag,
      Value<String?> name,
      Value<String?> author,
      Value<int?> publishedAt,
      Value<String?> url,
    });
typedef $$RepoReleasesTableUpdateCompanionBuilder =
    RepoReleasesCompanion Function({
      Value<int> id,
      Value<String> repoKey,
      Value<String> tag,
      Value<String?> name,
      Value<String?> author,
      Value<int?> publishedAt,
      Value<String?> url,
    });

class $$RepoReleasesTableFilterComposer
    extends Composer<_$AppDatabase, $RepoReleasesTable> {
  $$RepoReleasesTableFilterComposer({
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

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RepoReleasesTableOrderingComposer
    extends Composer<_$AppDatabase, $RepoReleasesTable> {
  $$RepoReleasesTableOrderingComposer({
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

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepoReleasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepoReleasesTable> {
  $$RepoReleasesTableAnnotationComposer({
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

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);
}

class $$RepoReleasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepoReleasesTable,
          RepoReleaseRow,
          $$RepoReleasesTableFilterComposer,
          $$RepoReleasesTableOrderingComposer,
          $$RepoReleasesTableAnnotationComposer,
          $$RepoReleasesTableCreateCompanionBuilder,
          $$RepoReleasesTableUpdateCompanionBuilder,
          (
            RepoReleaseRow,
            BaseReferences<_$AppDatabase, $RepoReleasesTable, RepoReleaseRow>,
          ),
          RepoReleaseRow,
          PrefetchHooks Function()
        > {
  $$RepoReleasesTableTableManager(_$AppDatabase db, $RepoReleasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepoReleasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepoReleasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepoReleasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> repoKey = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> publishedAt = const Value.absent(),
                Value<String?> url = const Value.absent(),
              }) => RepoReleasesCompanion(
                id: id,
                repoKey: repoKey,
                tag: tag,
                name: name,
                author: author,
                publishedAt: publishedAt,
                url: url,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String repoKey,
                required String tag,
                Value<String?> name = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> publishedAt = const Value.absent(),
                Value<String?> url = const Value.absent(),
              }) => RepoReleasesCompanion.insert(
                id: id,
                repoKey: repoKey,
                tag: tag,
                name: name,
                author: author,
                publishedAt: publishedAt,
                url: url,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RepoReleasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepoReleasesTable,
      RepoReleaseRow,
      $$RepoReleasesTableFilterComposer,
      $$RepoReleasesTableOrderingComposer,
      $$RepoReleasesTableAnnotationComposer,
      $$RepoReleasesTableCreateCompanionBuilder,
      $$RepoReleasesTableUpdateCompanionBuilder,
      (
        RepoReleaseRow,
        BaseReferences<_$AppDatabase, $RepoReleasesTable, RepoReleaseRow>,
      ),
      RepoReleaseRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String scope,
      Value<int?> lastSuccessAt,
      Value<String?> etag,
      Value<String?> cursor,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> scope,
      Value<int?> lastSuccessAt,
      Value<String?> etag,
      Value<String?> cursor,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<int?> lastSuccessAt = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                scope: scope,
                lastSuccessAt: lastSuccessAt,
                etag: etag,
                cursor: cursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                Value<int?> lastSuccessAt = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                scope: scope,
                lastSuccessAt: lastSuccessAt,
                etag: etag,
                cursor: cursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$NotificationSeenTableCreateCompanionBuilder =
    NotificationSeenCompanion Function({Value<int> id, required String seenId});
typedef $$NotificationSeenTableUpdateCompanionBuilder =
    NotificationSeenCompanion Function({Value<int> id, Value<String> seenId});

class $$NotificationSeenTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationSeenTable> {
  $$NotificationSeenTableFilterComposer({
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

  ColumnFilters<String> get seenId => $composableBuilder(
    column: $table.seenId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationSeenTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationSeenTable> {
  $$NotificationSeenTableOrderingComposer({
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

  ColumnOrderings<String> get seenId => $composableBuilder(
    column: $table.seenId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationSeenTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationSeenTable> {
  $$NotificationSeenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get seenId =>
      $composableBuilder(column: $table.seenId, builder: (column) => column);
}

class $$NotificationSeenTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationSeenTable,
          NotificationSeenRow,
          $$NotificationSeenTableFilterComposer,
          $$NotificationSeenTableOrderingComposer,
          $$NotificationSeenTableAnnotationComposer,
          $$NotificationSeenTableCreateCompanionBuilder,
          $$NotificationSeenTableUpdateCompanionBuilder,
          (
            NotificationSeenRow,
            BaseReferences<
              _$AppDatabase,
              $NotificationSeenTable,
              NotificationSeenRow
            >,
          ),
          NotificationSeenRow,
          PrefetchHooks Function()
        > {
  $$NotificationSeenTableTableManager(
    _$AppDatabase db,
    $NotificationSeenTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationSeenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationSeenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationSeenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> seenId = const Value.absent(),
              }) => NotificationSeenCompanion(id: id, seenId: seenId),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String seenId,
              }) => NotificationSeenCompanion.insert(id: id, seenId: seenId),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationSeenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationSeenTable,
      NotificationSeenRow,
      $$NotificationSeenTableFilterComposer,
      $$NotificationSeenTableOrderingComposer,
      $$NotificationSeenTableAnnotationComposer,
      $$NotificationSeenTableCreateCompanionBuilder,
      $$NotificationSeenTableUpdateCompanionBuilder,
      (
        NotificationSeenRow,
        BaseReferences<
          _$AppDatabase,
          $NotificationSeenTable,
          NotificationSeenRow
        >,
      ),
      NotificationSeenRow,
      PrefetchHooks Function()
    >;
typedef $$NotificationKnownReposTableCreateCompanionBuilder =
    NotificationKnownReposCompanion Function({
      required String repoDisplay,
      Value<int> rowid,
    });
typedef $$NotificationKnownReposTableUpdateCompanionBuilder =
    NotificationKnownReposCompanion Function({
      Value<String> repoDisplay,
      Value<int> rowid,
    });

class $$NotificationKnownReposTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationKnownReposTable> {
  $$NotificationKnownReposTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationKnownReposTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationKnownReposTable> {
  $$NotificationKnownReposTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationKnownReposTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationKnownReposTable> {
  $$NotificationKnownReposTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => column,
  );
}

class $$NotificationKnownReposTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationKnownReposTable,
          NotificationKnownRepoRow,
          $$NotificationKnownReposTableFilterComposer,
          $$NotificationKnownReposTableOrderingComposer,
          $$NotificationKnownReposTableAnnotationComposer,
          $$NotificationKnownReposTableCreateCompanionBuilder,
          $$NotificationKnownReposTableUpdateCompanionBuilder,
          (
            NotificationKnownRepoRow,
            BaseReferences<
              _$AppDatabase,
              $NotificationKnownReposTable,
              NotificationKnownRepoRow
            >,
          ),
          NotificationKnownRepoRow,
          PrefetchHooks Function()
        > {
  $$NotificationKnownReposTableTableManager(
    _$AppDatabase db,
    $NotificationKnownReposTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationKnownReposTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationKnownReposTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationKnownReposTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> repoDisplay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationKnownReposCompanion(
                repoDisplay: repoDisplay,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String repoDisplay,
                Value<int> rowid = const Value.absent(),
              }) => NotificationKnownReposCompanion.insert(
                repoDisplay: repoDisplay,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationKnownReposTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationKnownReposTable,
      NotificationKnownRepoRow,
      $$NotificationKnownReposTableFilterComposer,
      $$NotificationKnownReposTableOrderingComposer,
      $$NotificationKnownReposTableAnnotationComposer,
      $$NotificationKnownReposTableCreateCompanionBuilder,
      $$NotificationKnownReposTableUpdateCompanionBuilder,
      (
        NotificationKnownRepoRow,
        BaseReferences<
          _$AppDatabase,
          $NotificationKnownReposTable,
          NotificationKnownRepoRow
        >,
      ),
      NotificationKnownRepoRow,
      PrefetchHooks Function()
    >;
typedef $$CiRunHistoryTableCreateCompanionBuilder =
    CiRunHistoryCompanion Function({
      Value<int> id,
      required String provider,
      required String repoKey,
      required String repoDisplay,
      required String workflow,
      Value<String?> workflowId,
      required String runKey,
      required String outcome,
      required String conclusion,
      Value<String?> branch,
      Value<int?> finishedAt,
      Value<int?> durationMs,
      Value<String?> url,
    });
typedef $$CiRunHistoryTableUpdateCompanionBuilder =
    CiRunHistoryCompanion Function({
      Value<int> id,
      Value<String> provider,
      Value<String> repoKey,
      Value<String> repoDisplay,
      Value<String> workflow,
      Value<String?> workflowId,
      Value<String> runKey,
      Value<String> outcome,
      Value<String> conclusion,
      Value<String?> branch,
      Value<int?> finishedAt,
      Value<int?> durationMs,
      Value<String?> url,
    });

class $$CiRunHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $CiRunHistoryTable> {
  $$CiRunHistoryTableFilterComposer({
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

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoKey => $composableBuilder(
    column: $table.repoKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflow => $composableBuilder(
    column: $table.workflow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runKey => $composableBuilder(
    column: $table.runKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conclusion => $composableBuilder(
    column: $table.conclusion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CiRunHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $CiRunHistoryTable> {
  $$CiRunHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoKey => $composableBuilder(
    column: $table.repoKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflow => $composableBuilder(
    column: $table.workflow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runKey => $composableBuilder(
    column: $table.runKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conclusion => $composableBuilder(
    column: $table.conclusion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CiRunHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $CiRunHistoryTable> {
  $$CiRunHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get repoKey =>
      $composableBuilder(column: $table.repoKey, builder: (column) => column);

  GeneratedColumn<String> get repoDisplay => $composableBuilder(
    column: $table.repoDisplay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workflow =>
      $composableBuilder(column: $table.workflow, builder: (column) => column);

  GeneratedColumn<String> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get runKey =>
      $composableBuilder(column: $table.runKey, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get conclusion => $composableBuilder(
    column: $table.conclusion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);
}

class $$CiRunHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CiRunHistoryTable,
          CiRunHistoryRow,
          $$CiRunHistoryTableFilterComposer,
          $$CiRunHistoryTableOrderingComposer,
          $$CiRunHistoryTableAnnotationComposer,
          $$CiRunHistoryTableCreateCompanionBuilder,
          $$CiRunHistoryTableUpdateCompanionBuilder,
          (
            CiRunHistoryRow,
            BaseReferences<_$AppDatabase, $CiRunHistoryTable, CiRunHistoryRow>,
          ),
          CiRunHistoryRow,
          PrefetchHooks Function()
        > {
  $$CiRunHistoryTableTableManager(_$AppDatabase db, $CiRunHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CiRunHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CiRunHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CiRunHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> repoKey = const Value.absent(),
                Value<String> repoDisplay = const Value.absent(),
                Value<String> workflow = const Value.absent(),
                Value<String?> workflowId = const Value.absent(),
                Value<String> runKey = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<String> conclusion = const Value.absent(),
                Value<String?> branch = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> url = const Value.absent(),
              }) => CiRunHistoryCompanion(
                id: id,
                provider: provider,
                repoKey: repoKey,
                repoDisplay: repoDisplay,
                workflow: workflow,
                workflowId: workflowId,
                runKey: runKey,
                outcome: outcome,
                conclusion: conclusion,
                branch: branch,
                finishedAt: finishedAt,
                durationMs: durationMs,
                url: url,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String provider,
                required String repoKey,
                required String repoDisplay,
                required String workflow,
                Value<String?> workflowId = const Value.absent(),
                required String runKey,
                required String outcome,
                required String conclusion,
                Value<String?> branch = const Value.absent(),
                Value<int?> finishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> url = const Value.absent(),
              }) => CiRunHistoryCompanion.insert(
                id: id,
                provider: provider,
                repoKey: repoKey,
                repoDisplay: repoDisplay,
                workflow: workflow,
                workflowId: workflowId,
                runKey: runKey,
                outcome: outcome,
                conclusion: conclusion,
                branch: branch,
                finishedAt: finishedAt,
                durationMs: durationMs,
                url: url,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CiRunHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CiRunHistoryTable,
      CiRunHistoryRow,
      $$CiRunHistoryTableFilterComposer,
      $$CiRunHistoryTableOrderingComposer,
      $$CiRunHistoryTableAnnotationComposer,
      $$CiRunHistoryTableCreateCompanionBuilder,
      $$CiRunHistoryTableUpdateCompanionBuilder,
      (
        CiRunHistoryRow,
        BaseReferences<_$AppDatabase, $CiRunHistoryTable, CiRunHistoryRow>,
      ),
      CiRunHistoryRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MetricSnapshotsTableTableManager get metricSnapshots =>
      $$MetricSnapshotsTableTableManager(_db, _db.metricSnapshots);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(_db, _db.activityEvents);
  $$AttentionItemsTableTableManager get attentionItems =>
      $$AttentionItemsTableTableManager(_db, _db.attentionItems);
  $$RepoPullsTableTableManager get repoPulls =>
      $$RepoPullsTableTableManager(_db, _db.repoPulls);
  $$RepoRunsTableTableManager get repoRuns =>
      $$RepoRunsTableTableManager(_db, _db.repoRuns);
  $$RepoReleasesTableTableManager get repoReleases =>
      $$RepoReleasesTableTableManager(_db, _db.repoReleases);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$NotificationSeenTableTableManager get notificationSeen =>
      $$NotificationSeenTableTableManager(_db, _db.notificationSeen);
  $$NotificationKnownReposTableTableManager get notificationKnownRepos =>
      $$NotificationKnownReposTableTableManager(
        _db,
        _db.notificationKnownRepos,
      );
  $$CiRunHistoryTableTableManager get ciRunHistory =>
      $$CiRunHistoryTableTableManager(_db, _db.ciRunHistory);
}
