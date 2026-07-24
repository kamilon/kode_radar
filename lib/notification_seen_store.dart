import 'dart:convert';

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

  static Future<String?> _getMeta(AppDatabase db, String key) async {
    final row = await (db.select(
      db.appMeta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  static Future<void> _setMeta(AppDatabase db, String key, String value) {
    return db
        .into(db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(key: key, value: value),
        );
  }

  /// `app_meta` key holding the local date (`yyyy-M-d`) the daily digest was
  /// last shown, used as an atomic once-per-day claim.
  static const String _digestShownKey = 'digest_last_shown';

  /// Atomically claims the daily digest for [date] (a `yyyy-M-d` key): returns
  /// true if this run won the claim (the digest hasn't been shown for [date]
  /// yet), false if another run already claimed it. The check-and-set runs in a
  /// single write transaction, which SQLite serializes, so the foreground and
  /// background-sync isolates can't both claim — and show — the same day.
  static Future<bool> claimDailyDigest(String date) {
    final db = _database;
    return _runLocked(
      () => db.transaction(() async {
        if (await _getMeta(db, _digestShownKey) == date) return false;
        await _setMeta(db, _digestShownKey, date);
        return true;
      }),
    );
  }

  /// Releases a same-day digest claim (e.g. when showing the notification
  /// failed) so a later sync can retry. Only clears the marker if it still
  /// holds [date], to avoid clobbering a newer day's claim.
  static Future<void> releaseDailyDigest(String date) {
    final db = _database;
    return _runLocked(
      () => db.transaction(() async {
        if (await _getMeta(db, _digestShownKey) == date) {
          await (db.delete(
            db.appMeta,
          )..where((t) => t.key.equals(_digestShownKey))).go();
        }
      }),
    );
  }

  /// `app_meta` key holding the JSON list of regression alert keys already
  /// notified in the current period (see [claimNewRegressionKeys]).
  static const String _regressionKeysKey = 'regression_notified_keys';

  /// Records which of [currentKeys] are newly seen this period and returns just
  /// those (the ones an alert should fire for). Every key is `<periodKey>|…`;
  /// entries from any period other than [periodKey] are pruned, so a regression
  /// that persists into a new period alerts again (once), while one that keeps
  /// standing within a period doesn't re-alert. The read-modify-write runs in a
  /// single transaction (SQLite-serialized) so foreground and background-sync
  /// isolates can't both fire the same alert.
  ///
  /// Best-effort across a period boundary: if a slow pre-boundary sync commits
  /// after a new-period sync, it prunes the newer period's keys and can cause
  /// one duplicate alert next period. That's a benign, rare cosmetic dupe (no
  /// data loss), so it isn't guarded against here.
  static Future<Set<String>> claimNewRegressionKeys(
    Set<String> currentKeys,
    String periodKey,
  ) {
    final db = _database;
    return _runLocked(
      () => db.transaction(() async {
        final raw = await _getMeta(db, _regressionKeysKey);
        final stored = <String>{};
        if (raw != null && raw.isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              for (final e in decoded) {
                if (e is String) stored.add(e);
              }
            }
          } catch (_) {
            // Corrupt marker: treat as empty and overwrite below.
          }
        }
        // Scope everything to this period: only keys prefixed `<periodKey>|`
        // are considered, so a caller that passes an out-of-period key can't
        // slip an unprunable entry into the stored set (and it matches the doc:
        // entries from any other period are pruned).
        final prefix = '$periodKey|';
        final scoped = currentKeys.where((k) => k.startsWith(prefix)).toSet();
        final kept = stored.where((k) => k.startsWith(prefix)).toSet();
        final fresh = scoped.difference(kept);
        // Skip the write when there's nothing new to record and nothing stale
        // to prune.
        if (fresh.isEmpty && kept.length == stored.length) {
          return <String>{};
        }
        final updated = <String>{...kept, ...scoped};
        await _setMeta(db, _regressionKeysKey, jsonEncode(updated.toList()));
        return fresh;
      }),
    );
  }

  /// Un-marks [keys] (e.g. when showing the alert failed) so a later sync
  /// re-fires them, mirroring [releaseDailyDigest]. Only removes the given keys
  /// from the stored set; a no-op when none are present.
  static Future<void> releaseRegressionKeys(Set<String> keys) {
    if (keys.isEmpty) return Future<void>.value();
    final db = _database;
    return _runLocked(
      () => db.transaction(() async {
        final raw = await _getMeta(db, _regressionKeysKey);
        if (raw == null || raw.isEmpty) return;
        final stored = <String>{};
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            for (final e in decoded) {
              if (e is String) stored.add(e);
            }
          }
        } catch (_) {
          return;
        }
        final before = stored.length;
        stored.removeAll(keys);
        if (stored.length == before) return;
        await _setMeta(db, _regressionKeysKey, jsonEncode(stored.toList()));
      }),
    );
  }
}
