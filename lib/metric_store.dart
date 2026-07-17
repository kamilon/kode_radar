import 'dart:convert';

import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_service.dart';
import 'database/app_database.dart';
import 'metric_snapshot.dart';
import 'monitored_repos.dart';
import 'repo_store.dart';

/// Persists per-repo trend snapshots on the local SQLite database (drift).
///
/// This store previously kept its history in `SharedPreferences` under
/// [storageKey]; that data is imported into the database once, transparently,
/// the first time the store is used (see [_ensureMigrated]). The public API is
/// unchanged so callers (Radar / Teams / Digest / repo delete) are unaffected.
class MetricStore {
  MetricStore._();

  /// Legacy `SharedPreferences` key. Retained only so the one-time import can
  /// find and migrate pre-database history.
  static const String storageKey = 'metric_history';

  /// `app_meta` key recording that the legacy import has completed. Stored in
  /// the database (not `SharedPreferences`) so it commits atomically with the
  /// imported rows and a crash mid-import can't cause a re-import.
  static const String _importedFlag = 'metric_history_imported';
  static const int maxPerRepo = 60;
  static const Duration minCaptureInterval = Duration(hours: 24);

  static AppDatabase? _db;
  static Future<void>? _migration;

  // Serializes mutating operations (capture / removeRepo). drift already
  // serializes transactions on the single connection, so this is primarily to
  // make the "monitored" read in `capture` atomic with its insert relative to
  // `removeRepo` — i.e. a delete can't interleave between a capture reading the
  // monitored set and writing its snapshot.
  static Future<void> _lock = SynchronousFuture<void>(null);

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static AppDatabase get _database => _db ??= AppDatabase();

  /// Test hook: back the store with an injected (e.g. in-memory) database and
  /// reset the one-time migration guard and the mutation lock, so each injected
  /// database starts from a clean serialization state (a pending/errored lock
  /// chain left by a prior test can't stall the next one).
  @visibleForTesting
  static void debugUseDatabase(AppDatabase db) {
    _db = db;
    _migration = null;
    _lock = SynchronousFuture<void>(null);
  }

  static bool shouldCapture(DateTime? lastAt, DateTime now) =>
      lastAt == null || now.difference(lastAt) >= minCaptureInterval;

  /// Appends one snapshot per repo in [activities] (deduped to ~1/day).
  ///
  /// When [restrictToMonitored] is true, the currently-persisted repo lists are
  /// read and any activity whose repo is no longer monitored is skipped. This
  /// closes a race where a screen's in-flight fetch (computed before the user
  /// removed a repo) would otherwise re-insert a just-pruned history key. It is
  /// safe in the normal case because `activities` is itself derived from the
  /// monitored repos.
  static Future<void> capture(
    List<RepoActivity> activities, {
    DateTime? now,
    bool restrictToMonitored = false,
  }) async {
    final capturedAt = (now ?? DateTime.now()).toUtc();
    await _ensureMigrated();

    await _runLocked(() async {
      Iterable<RepoActivity> candidates = activities.where(
        (activity) => activity.error == null,
      );
      if (restrictToMonitored) {
        final prefs = await SharedPreferences.getInstance();
        final monitored = parseMonitoredRepos(
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[],
          prefs.getStringList(RepoStore.adoKey) ?? const <String>[],
        ).map((repo) => repo.repoKey).toSet();
        candidates = candidates.where(
          (activity) => monitored.contains(activity.repoKey),
        );
      }

      final pending = candidates.toList();
      if (pending.isEmpty) return;

      final db = _database;
      await db.transaction(() async {
        for (final activity in pending) {
          final lastAt = await _latestCapturedAt(db, activity.repoKey);
          if (!shouldCapture(lastAt, capturedAt)) {
            continue;
          }

          await db
              .into(db.metricSnapshots)
              .insert(
                MetricSnapshotsCompanion.insert(
                  repoKey: activity.repoKey,
                  capturedAt: capturedAt.millisecondsSinceEpoch,
                  openPrs: activity.openPrCount,
                  needsReview: activity.needsReviewCount,
                  activityScore: activity.activityScore.toDouble(),
                ),
              );

          await _pruneToMax(db, activity.repoKey);
        }
      });
    });
  }

  static Future<Map<String, List<MetricSnapshot>>> all() async {
    await _ensureMigrated();
    final rows =
        await (_database.select(_database.metricSnapshots)..orderBy([
              (t) => OrderingTerm(expression: t.capturedAt),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();

    final histories = <String, List<MetricSnapshot>>{};
    for (final row in rows) {
      histories
          .putIfAbsent(row.repoKey, () => <MetricSnapshot>[])
          .add(_toSnapshot(row));
    }
    return histories;
  }

  static Future<List<MetricSnapshot>> historyFor(String repoKey) async {
    await _ensureMigrated();
    final rows =
        await (_database.select(_database.metricSnapshots)
              ..where((t) => t.repoKey.equals(repoKey))
              ..orderBy([
                (t) => OrderingTerm(expression: t.capturedAt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    return rows.map(_toSnapshot).toList();
  }

  static Future<List<num>> seriesFor(
    String repoKey, {
    String metric = 'activityScore',
  }) async {
    final history = await historyFor(repoKey);
    return switch (metric) {
      'openPrs' => history.map<num>((snapshot) => snapshot.openPrs).toList(),
      'needsReview' =>
        history.map<num>((snapshot) => snapshot.needsReview).toList(),
      'activityScore' =>
        history.map<num>((snapshot) => snapshot.activityScore).toList(),
      _ => _unknownMetric(metric),
    };
  }

  /// Drops all captured history for [repoKey] (e.g. after the repo is removed
  /// from monitoring) so deleted repos don't linger as stale keys.
  static Future<void> removeRepo(String repoKey) async {
    final key = repoKey.trim();
    if (key.isEmpty) return;
    await _ensureMigrated();
    await _runLocked(() async {
      await (_database.delete(
        _database.metricSnapshots,
      )..where((t) => t.repoKey.equals(key))).go();
    });
  }

  static Future<DateTime?> _latestCapturedAt(
    AppDatabase db,
    String repoKey,
  ) async {
    final row =
        await (db.select(db.metricSnapshots)
              ..where((t) => t.repoKey.equals(repoKey))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.capturedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(row.capturedAt, isUtc: true);
  }

  /// Keeps only the newest [maxPerRepo] snapshots for [repoKey].
  static Future<void> _pruneToMax(AppDatabase db, String repoKey) async {
    final ids =
        await (db.selectOnly(db.metricSnapshots)
              ..addColumns([db.metricSnapshots.id])
              ..where(db.metricSnapshots.repoKey.equals(repoKey))
              ..orderBy([
                OrderingTerm(
                  expression: db.metricSnapshots.capturedAt,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm(
                  expression: db.metricSnapshots.id,
                  mode: OrderingMode.desc,
                ),
              ]))
            .map((row) => row.read(db.metricSnapshots.id)!)
            .get();
    if (ids.length <= maxPerRepo) return;
    final toDelete = ids.sublist(maxPerRepo);
    await (db.delete(
      db.metricSnapshots,
    )..where((t) => t.id.isIn(toDelete))).go();
  }

  static MetricSnapshot _toSnapshot(MetricSnapshotRow row) => MetricSnapshot(
    at: DateTime.fromMillisecondsSinceEpoch(row.capturedAt, isUtc: true),
    openPrs: row.openPrs,
    needsReview: row.needsReview,
    activityScore: row.activityScore,
  );

  static List<num> _unknownMetric(String metric) {
    debugPrint('MetricStore unknown metric "$metric"');
    return <num>[];
  }

  /// Imports pre-database history from [storageKey] into the database exactly
  /// once. Memoized so it runs at most once per process.
  static Future<void> _ensureMigrated() => _migration ??= _migrate();

  static Future<void> _migrate() async {
    final db = _database;
    final prefs = await SharedPreferences.getInstance();

    // The completion marker lives in the DB, so a crash between committing the
    // imported rows and clearing the legacy key can never re-import.
    if (await _isImported(db)) {
      await prefs.remove(storageKey);
      return;
    }

    final (status, legacy) = _decodeLegacy(prefs.getString(storageKey));
    if (status == _LegacyDecodeStatus.invalid) {
      // Malformed input: leave the blob untouched (don't mark imported, don't
      // delete) so it isn't silently discarded and a later version can retry.
      debugPrint(
        'MetricStore: legacy $storageKey is malformed; skipping import.',
      );
      return;
    }

    // Insert the rows and the completion marker atomically.
    await db.transaction(() async {
      for (final entry in legacy.entries) {
        for (final snapshot in entry.value) {
          await db
              .into(db.metricSnapshots)
              .insert(
                MetricSnapshotsCompanion.insert(
                  repoKey: entry.key,
                  capturedAt: snapshot.at.toUtc().millisecondsSinceEpoch,
                  openPrs: snapshot.openPrs,
                  needsReview: snapshot.needsReview,
                  activityScore: snapshot.activityScore.toDouble(),
                ),
              );
        }
      }
      await db
          .into(db.appMeta)
          .insertOnConflictUpdate(
            AppMetaCompanion.insert(key: _importedFlag, value: '1'),
          );
    });

    // Safe now that the marker is committed: a crash here just leaves a stale
    // key that the early `_isImported` branch clears on the next run.
    await prefs.remove(storageKey);
  }

  static Future<bool> _isImported(AppDatabase db) async {
    final row = await (db.select(
      db.appMeta,
    )..where((t) => t.key.equals(_importedFlag))).getSingleOrNull();
    return row != null;
  }

  static (_LegacyDecodeStatus, Map<String, List<MetricSnapshot>>) _decodeLegacy(
    String? raw,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return (
        _LegacyDecodeStatus.absent,
        const <String, List<MetricSnapshot>>{},
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return (
          _LegacyDecodeStatus.invalid,
          const <String, List<MetricSnapshot>>{},
        );
      }
      final histories = <String, List<MetricSnapshot>>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! List) continue;
        final snapshots = <MetricSnapshot>[];
        for (final item in value) {
          if (item is! Map) continue;
          final snapshot = MetricSnapshot.fromJson(item);
          if (snapshot != null) snapshots.add(snapshot);
        }
        if (snapshots.isNotEmpty) histories[key] = snapshots;
      }
      return (_LegacyDecodeStatus.valid, histories);
    } catch (e) {
      debugPrint('MetricStore failed to decode legacy $storageKey: $e');
      return (
        _LegacyDecodeStatus.invalid,
        const <String, List<MetricSnapshot>>{},
      );
    }
  }
}

/// Outcome of decoding the legacy `metric_history` blob: nothing to import,
/// a well-formed payload, or malformed input that must be retained rather than
/// discarded.
enum _LegacyDecodeStatus { absent, valid, invalid }
