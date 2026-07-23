import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'cycle_time.dart';
import 'database/app_database.dart';

/// Persists merged pull requests on the local SQLite database (drift) so the
/// review-time / cycle-time trends can surface how long PRs take to review and
/// merge, across syncs.
///
/// Rows are de-duplicated by `prKey` via an `INSERT OR REPLACE` on its UNIQUE
/// index, so repeated syncs that re-see the same merged PRs union rather than
/// double-count. After each write the table is pruned to stay bounded: rows
/// merged before [retention] ago are dropped, and each repo is capped at
/// [perRepoCap] newest rows.
///
/// Like the other local-DB stores, this owns its own [AppDatabase] singleton
/// and serializes its writes through a static lock chain.
class CycleTimeStore {
  CycleTimeStore._();

  static AppDatabase? _db;

  static Future<void> _lock = SynchronousFuture<void>(null);

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static AppDatabase get _database => _db ??= AppDatabase();

  /// How long a merged PR stays in history before it's pruned.
  static const Duration retention = Duration(days: 120);

  /// Cap on rows kept per repo so a very active repo can't grow unbounded.
  /// Sized to comfortably exceed [retention]'s worth of merges for an active
  /// repo (~10 merged PRs/day over 120 days), so the advertised windows (up to
  /// 90 days) aren't silently clipped for busy repos.
  static const int perRepoCap = 1200;

  @visibleForTesting
  static void debugUseDatabase(AppDatabase db) {
    _db = db;
    _lock = SynchronousFuture<void>(null);
  }

  /// Records [samples] (skipping any without a `prKey`), de-duplicating by
  /// `prKey`, then prunes by age and the per-repo cap. A no-op for empty input.
  static Future<void> record(
    Iterable<MergedPrSample> samples, {
    DateTime? now,
  }) {
    final rows = samples.where((s) => s.prKey.isNotEmpty).toList();
    if (rows.isEmpty) return Future<void>.value();
    final at = now ?? DateTime.now();
    return _runLocked(() async {
      final db = _database;
      await db.transaction(() async {
        await db.batch((b) {
          b.insertAll(
            db.mergedPrs,
            rows.map(_companion).toList(),
            mode: InsertMode.insertOrReplace,
          );
        });
        final cutoff = at.subtract(retention).millisecondsSinceEpoch;
        await (db.delete(
          db.mergedPrs,
        )..where((t) => t.mergedAt.isSmallerThanValue(cutoff))).go();
        for (final repoKey in rows.map((s) => s.repoKey).toSet()) {
          await _capRepo(db, repoKey);
        }
      });
    });
  }

  /// Like [record] but never throws — logs and swallows — for UI load paths.
  static Future<void> recordSafely(
    Iterable<MergedPrSample> samples, {
    DateTime? now,
  }) async {
    try {
      await record(samples, now: now);
    } catch (e, st) {
      debugPrint('CycleTimeStore.record failed: $e\n$st');
    }
  }

  static Future<void> _capRepo(AppDatabase db, String repoKey) async {
    final ids =
        await (db.selectOnly(db.mergedPrs)
              ..addColumns([db.mergedPrs.id])
              ..where(db.mergedPrs.repoKey.equals(repoKey))
              ..orderBy([
                OrderingTerm.desc(db.mergedPrs.mergedAt),
                OrderingTerm.desc(db.mergedPrs.id),
              ]))
            .map((row) => row.read(db.mergedPrs.id)!)
            .get();
    if (ids.length <= perRepoCap) return;
    final toDrop = ids.sublist(perRepoCap);
    await (db.delete(db.mergedPrs)..where((t) => t.id.isIn(toDrop))).go();
  }

  /// All stored merged-PR samples (bounded by [retention] and the per-repo
  /// cap), so a caller can aggregate client-side for any window.
  static Future<List<MergedPrSample>> allSamples() {
    return _runLocked(() async {
      final db = _database;
      final rows = await db.select(db.mergedPrs).get();
      return rows.map(_toSample).toList();
    });
  }

  /// Drops all history for [repoKey] (e.g. after the repo is removed).
  static Future<void> removeRepo(String repoKey) async {
    final key = repoKey.trim();
    if (key.isEmpty) return;
    await _runLocked(() async {
      final db = _database;
      await (db.delete(db.mergedPrs)..where((t) => t.repoKey.equals(key))).go();
    });
  }

  static DateTime _fromMs(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static MergedPrSample _toSample(MergedPrRow row) => MergedPrSample(
    provider: row.provider,
    repoKey: row.repoKey,
    repoDisplay: row.repoDisplay,
    prKey: row.prKey,
    createdAt: _fromMs(row.createdAt),
    mergedAt: _fromMs(row.mergedAt),
    firstReviewAt: row.firstReviewAt == null
        ? null
        : _fromMs(row.firstReviewAt!),
    title: row.title,
    author: row.author,
    url: row.url,
  );

  static MergedPrsCompanion _companion(MergedPrSample s) =>
      MergedPrsCompanion.insert(
        provider: s.provider,
        repoKey: s.repoKey,
        repoDisplay: s.repoDisplay,
        prKey: s.prKey,
        createdAt: s.createdAt.toUtc().millisecondsSinceEpoch,
        mergedAt: s.mergedAt.toUtc().millisecondsSinceEpoch,
        firstReviewAt: Value(s.firstReviewAt?.toUtc().millisecondsSinceEpoch),
        title: Value(s.title),
        author: Value(s.author),
        url: Value(s.url),
      );
}
