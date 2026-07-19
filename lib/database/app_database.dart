import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Per-repo trend snapshots. This is the first table migrated off
/// `SharedPreferences` onto the local SQLite database (drift). `capturedAt` is
/// stored as milliseconds since epoch in UTC. The generated row class is named
/// `MetricSnapshotRow` to avoid colliding with the `MetricSnapshot` DTO.
@DataClassName('MetricSnapshotRow')
@TableIndex(name: 'idx_metric_snapshots_repo_key', columns: {#repoKey})
class MetricSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get repoKey => text()();
  IntColumn get capturedAt => integer()();
  IntColumn get openPrs => integer()();
  IntColumn get needsReview => integer()();
  RealColumn get activityScore => real()();
}

/// Cached, normalized cross-repo activity feed events (Phase 2 domain cache).
/// Rows mirror the `ActivityEvent` DTO so the feed can render instantly from
/// this table on cold start and treat the network as a refresher. `occurredAt`
/// is milliseconds since epoch in UTC. `(repoKey, eventId)` is unique so a
/// re-fetch upserts the same event instead of duplicating it. The generated row
/// class is named `ActivityEventRow` to avoid colliding with the `ActivityEvent`
/// DTO.
@DataClassName('ActivityEventRow')
@TableIndex(name: 'idx_activity_events_repo_key', columns: {#repoKey})
@TableIndex(name: 'idx_activity_events_occurred_at', columns: {#occurredAt})
@TableIndex(
  name: 'idx_activity_events_repo_event',
  columns: {#repoKey, #eventId},
  unique: true,
)
class ActivityEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get eventId => text()();
  TextColumn get type => text()();
  TextColumn get provider => text()();
  TextColumn get repoKey => text()();
  TextColumn get repoDisplay => text()();
  TextColumn get actor => text()();
  TextColumn get title => text()();
  TextColumn get subtitle => text()();
  IntColumn get occurredAt => integer()();
  TextColumn get url => text().nullable()();
  BoolColumn get isMine => boolean()();
}

/// Small key/value table for database-local bookkeeping (e.g. one-time
/// migration markers that must commit atomically with the data they guard).
@DataClassName('AppMetaRow')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The application's local SQLite database. Holds cached, aggregated monitoring
/// data that would not fit in `SharedPreferences` at scale. Configuration
/// (tokens, repo lists, preferences) continues to live in `SharedPreferences`.
@DriftDatabase(tables: [MetricSnapshots, AppMeta, ActivityEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Builds a database over a caller-provided executor (e.g.
  /// `NativeDatabase.memory()` in unit tests).
  AppDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 adds the activity-feed cache (Phase 2). Create the table and its
      // indexes explicitly — `createTable` only issues `CREATE TABLE`, so the
      // (repo_key, event_id) UNIQUE index the upsert relies on must be created
      // separately or existing (v1) installs would get duplicate rows.
      //
      // Guard on the table's existence so a concurrent open from a second
      // connection (e.g. the background-sync isolate) that also observed v1
      // can't fail with "table already exists": SQLite serializes writers, so
      // by the time the second migration's transaction runs, it sees the table
      // the first one committed and skips the (non-idempotent) DDL.
      if (from < 2) {
        final existing = await m.database
            .customSelect(
              "SELECT 1 FROM sqlite_master "
              "WHERE type = 'table' AND name = 'activity_events'",
            )
            .get();
        if (existing.isEmpty) {
          await m.createTable(activityEvents);
          await m.create(idxActivityEventsRepoKey);
          await m.create(idxActivityEventsOccurredAt);
          await m.create(idxActivityEventsRepoEvent);
        }
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Application-support (not documents): this is an internal cache/DB, so it
    // should not be user-visible or included in document backups.
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'kode_radar.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      // WAL lets the app and a background-sync isolate (which opens its own
      // connection to this file) read/write concurrently; busy_timeout makes a
      // writer wait for a brief lock instead of failing fast with SQLITE_BUSY.
      setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL;');
        rawDb.execute('PRAGMA busy_timeout=5000;');
      },
    );
  });
}
