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
@DriftDatabase(tables: [MetricSnapshots, AppMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Builds a database over a caller-provided executor (e.g.
  /// `NativeDatabase.memory()` in unit tests).
  AppDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 1;
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
      // connection to this file) read/write concurrently without "database is
      // locked" errors.
      setup: (rawDb) => rawDb.execute('PRAGMA journal_mode=WAL;'),
    );
  });
}
