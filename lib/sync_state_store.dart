import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'database/app_database.dart';

/// Records when each cache "scope" was last refreshed successfully from the
/// network (Phase 3 provenance), so the UI can show an accurate "updated Xh
/// ago" instead of "just now" when it's actually displaying stale cached data
/// after a failed/offline refresh.
///
/// Scopes are stable keys: [feedScope], [attentionScope], or
/// `repoScope(repoKey)` for a repo drill-down.
class SyncStateStore {
  SyncStateStore._();

  static const String feedScope = 'feed';
  static const String attentionScope = 'attention';

  static String repoScope(String repoKey) => 'repo:$repoKey';

  static AppDatabase? _db;

  static Future<void> _lock = SynchronousFuture<void>(null);

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static AppDatabase get _database => _db ??= AppDatabase();

  /// Test hook: back the store with an injected (e.g. in-memory) database and
  /// reset the mutation lock.
  @visibleForTesting
  static void debugUseDatabase(AppDatabase db) {
    _db = db;
    _lock = SynchronousFuture<void>(null);
  }

  /// Records that [scope] just refreshed successfully (defaults to now).
  static Future<void> markSuccess(String scope, {DateTime? now}) async {
    final at = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    await _runLocked(() async {
      final db = _database;
      await db
          .into(db.syncState)
          .insert(
            SyncStateCompanion.insert(scope: scope, lastSuccessAt: Value(at)),
            onConflict: DoUpdate(
              (_) => SyncStateCompanion(lastSuccessAt: Value(at)),
            ),
          );
    });
  }

  /// The last successful-sync time for [scope], or null if it has never synced.
  static Future<DateTime?> lastSuccess(String scope) async {
    final db = _database;
    final row = await (db.select(
      db.syncState,
    )..where((t) => t.scope.equals(scope))).getSingleOrNull();
    final at = row?.lastSuccessAt;
    if (at == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
  }

  /// Drops the provenance row for [scope] (e.g. a repo removed from monitoring).
  static Future<void> remove(String scope) async {
    await _runLocked(() async {
      final db = _database;
      await (db.delete(db.syncState)..where((t) => t.scope.equals(scope))).go();
    });
  }
}
