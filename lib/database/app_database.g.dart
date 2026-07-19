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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MetricSnapshotsTable metricSnapshots = $MetricSnapshotsTable(
    this,
  );
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $ActivityEventsTable activityEvents = $ActivityEventsTable(this);
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
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    metricSnapshots,
    appMeta,
    activityEvents,
    idxMetricSnapshotsRepoKey,
    idxActivityEventsRepoKey,
    idxActivityEventsOccurredAt,
    idxActivityEventsRepoEvent,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MetricSnapshotsTableTableManager get metricSnapshots =>
      $$MetricSnapshotsTableTableManager(_db, _db.metricSnapshots);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(_db, _db.activityEvents);
}
