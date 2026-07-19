import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/app_database.dart';

/// The attention notification "seen" baseline, persisted on the local SQLite
/// database (Phase 4) instead of `SharedPreferences`.
///
/// The resident foreground and the background-sync isolate both record the
/// baseline; on `SharedPreferences` they read-modify-write the same blob and can
/// clobber each other (last-writer-win). Here [recordBaseline] does additive
/// upserts inside one transaction (`INSERT OR REPLACE` for seen ids — so a
/// re-seen id is bumped to newest and never wrongly pruned — and `INSERT OR
/// IGNORE` for known repos), so concurrent isolates union rather than overwrite:
/// an atomic, race-free baseline.
///
/// The legacy `SharedPreferences` baseline is imported once, transparently, on
/// first use (see [_ensureImported]).
class NotificationSeenStore {
  NotificationSeenStore._();

  /// Legacy `SharedPreferences` keys, retained only for the one-time import.
  static const String _legacySeenKey = 'seen_attention';
  static const String _legacyKnownReposKey = 'known_attention_repos';

  /// `app_meta` markers (kept in the DB so they commit atomically with the data
  /// they guard).
  static const String _importedFlag = 'notif_seen_imported';
  static const String _seededFlag = 'notif_seeded';

  /// Bounds the seen set; the oldest ids beyond this are pruned.
  static const int maxSeenIds = 5000;

  static AppDatabase? _db;
  static Future<void>? _migration;

  static Future<void> _lock = SynchronousFuture<void>(null);

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static AppDatabase get _database => _db ??= AppDatabase();

  @visibleForTesting
  static void debugUseDatabase(AppDatabase db) {
    _db = db;
    _migration = null;
    _lock = SynchronousFuture<void>(null);
  }

  /// The already-notified attention ids.
  static Future<Set<String>> seenIds() async {
    await _ensureImported();
    final rows = await _database.select(_database.notificationSeen).get();
    return rows.map((r) => r.seenId).toSet();
  }

  /// The repos whose existing backlog has been seeded silently.
  static Future<Set<String>> knownRepos() async {
    await _ensureImported();
    final rows = await _database.select(_database.notificationKnownRepos).get();
    return rows.map((r) => r.repoDisplay).toSet();
  }

  /// Whether a baseline has been established (was: the legacy `seen_attention`
  /// key existing). False means the next record is a silent first-run seed.
  static Future<bool> isSeeded() async {
    await _ensureImported();
    return _hasMeta(_database, _seededFlag);
  }

  /// Records the new baseline atomically: unions [currentIds] into the seen set
  /// (pruning to [maxSeenIds] newest), unions [monitoredRepos] into the known
  /// set, and marks the baseline seeded. Additive inserts make this safe against
  /// a concurrent isolate doing the same.
  static Future<void> recordBaseline(
    Set<String> currentIds,
    Set<String> monitoredRepos,
  ) async {
    await _ensureImported();
    await _runLocked(() async {
      final db = _database;
      await db.transaction(() async {
        // OR REPLACE (not IGNORE) so a re-seen id is bumped to a fresh, newest
        // autoincrement id — a continuously-current item then never falls into
        // the oldest-pruned tail and can't be spuriously re-notified. Still
        // additive across isolates (the id stays present). Batched so N ids are
        // one round-trip, not N.
        await db.batch((batch) {
          batch.insertAll(
            db.notificationSeen,
            currentIds.map(
              (id) => NotificationSeenCompanion.insert(seenId: id),
            ),
            mode: InsertMode.insertOrReplace,
          );
          batch.insertAll(
            db.notificationKnownRepos,
            monitoredRepos.map(
              (repo) =>
                  NotificationKnownReposCompanion.insert(repoDisplay: repo),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        });
        await _pruneSeen(db);
        await _setMeta(db, _seededFlag, '1');
      });
    });
  }

  /// Keeps only the newest [maxSeenIds] seen rows (by insertion order). Deletes
  /// via a subquery so no large `IN (...)` list is materialized.
  static Future<void> _pruneSeen(AppDatabase db) async {
    await db.customStatement(
      'DELETE FROM notification_seen WHERE id NOT IN '
      '(SELECT id FROM notification_seen ORDER BY id DESC LIMIT ?)',
      [maxSeenIds],
    );
  }

  /// Imports the legacy `SharedPreferences` baseline into the DB exactly once.
  static Future<void> _ensureImported() {
    return _migration ??= _migrate().catchError((Object e, StackTrace st) {
      _migration = null;
      Error.throwWithStackTrace(e, st);
    });
  }

  static Future<void> _migrate() async {
    final db = _database;
    if (await _hasMeta(db, _importedFlag)) return;

    final prefs = await SharedPreferences.getInstance();
    // Freshen from disk before reading the legacy blobs, so a reused isolate
    // with a stale cache doesn't import an empty set and then clear the real
    // legacy keys.
    await prefs.reload();
    final hadBaseline = prefs.containsKey(_legacySeenKey);
    final seen = prefs.getStringList(_legacySeenKey) ?? const <String>[];
    final known = prefs.getStringList(_legacyKnownReposKey) ?? const <String>[];

    await db.transaction(() async {
      // Re-check inside the (serialized) transaction so a concurrent isolate
      // can't double-import.
      if (await _hasMeta(db, _importedFlag)) return;
      await db.batch((batch) {
        batch.insertAll(
          db.notificationSeen,
          seen.map((id) => NotificationSeenCompanion.insert(seenId: id)),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(
          db.notificationKnownRepos,
          known.map(
            (repo) => NotificationKnownReposCompanion.insert(repoDisplay: repo),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      });
      // A pre-existing legacy key means a baseline was established, so preserve
      // "not first run" across the migration.
      if (hadBaseline) await _setMeta(db, _seededFlag, '1');
      await _setMeta(db, _importedFlag, '1');
    });

    // Safe once the import marker is committed.
    await prefs.remove(_legacySeenKey);
    await prefs.remove(_legacyKnownReposKey);
  }

  static Future<bool> _hasMeta(AppDatabase db, String key) async {
    final row = await (db.select(
      db.appMeta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row != null;
  }

  static Future<void> _setMeta(AppDatabase db, String key, String value) {
    return db
        .into(db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(key: key, value: value),
        );
  }
}
