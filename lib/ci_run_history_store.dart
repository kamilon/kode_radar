import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'ci_run_history.dart';
import 'database/app_database.dart';

/// Persists observed CI runs on the local SQLite database (drift) so the "CI
/// trends" insight can surface chronically-failing / flaky workflows across
/// syncs, rather than just the single latest run the Radar keeps.
///
/// Rows are de-duplicated by `runKey` (a provider-stable id) via an
/// `INSERT OR REPLACE` on its UNIQUE index, so repeated syncs that re-see the
/// same recent runs union rather than double-count. After each write the table
/// is pruned to stay bounded: rows older than [retention] are dropped, and each
/// repo is capped at [perRepoCap] newest rows.
///
/// Like the other local-DB stores, this owns its own [AppDatabase] singleton
/// (a separate connection to the shared WAL file) and serializes its writes
/// through a static lock chain.
class CiRunHistoryStore {
  CiRunHistoryStore._();

  static AppDatabase? _db;

  static Future<void> _lock = SynchronousFuture<void>(null);

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static AppDatabase get _database => _db ??= AppDatabase();

  /// How long a run stays in history before it's pruned.
  static const Duration retention = Duration(days: 45);

  /// Cap on rows kept per repo so a very active repo can't grow unbounded.
  static const int perRepoCap = 400;

  /// Test hook: back the store with an injected (e.g. in-memory) database and
  /// reset the mutation lock.
  @visibleForTesting
  static void debugUseDatabase(AppDatabase db) {
    _db = db;
    _lock = SynchronousFuture<void>(null);
  }

  /// Records [samples], de-duplicating by `runKey`, then prunes by age and the
  /// per-repo cap. Skips runs that can't be safely persisted as history: those
  /// without a `runKey`, still running, or lacking a finish time (so every
  /// stored row has a real completion timestamp for pruning and ordering). A
  /// no-op for an empty result so a sync with no CI data doesn't churn.
  static Future<void> record(Iterable<CiRunSample> samples, {DateTime? now}) {
    final rows = samples
        .where(
          (s) =>
              s.runKey.isNotEmpty &&
              s.finishedAt != null &&
              s.outcome != CiOutcome.running,
        )
        .toList();
    if (rows.isEmpty) return Future<void>.value();
    final at = now ?? DateTime.now();
    return _runLocked(() async {
      final db = _database;
      await db.transaction(() async {
        // One batched insert-or-replace rather than a statement per sample.
        await db.batch((b) {
          b.insertAll(
            db.ciRunHistory,
            rows.map(_companion).toList(),
            mode: InsertMode.insertOrReplace,
          );
        });
        // Age prune. Every stored row has a finish time (see the filter above),
        // so nothing escapes this by being null.
        final cutoff = at.subtract(retention).millisecondsSinceEpoch;
        await (db.delete(
          db.ciRunHistory,
        )..where((t) => t.finishedAt.isSmallerThanValue(cutoff))).go();
        // Per-repo cap: for each repo touched this round, keep only the newest
        // [perRepoCap] rows (by finish time, then insert order).
        for (final repoKey in rows.map((s) => s.repoKey).toSet()) {
          await _capRepo(db, repoKey);
        }
      });
    });
  }

  /// Like [record] but never throws — logs and swallows — for UI load paths
  /// where a history-write hiccup must not fail the surrounding refresh.
  static Future<void> recordSafely(
    Iterable<CiRunSample> samples, {
    DateTime? now,
  }) async {
    try {
      await record(samples, now: now);
    } catch (e, st) {
      debugPrint('CiRunHistoryStore.record failed: $e\n$st');
    }
  }

  static Future<void> _capRepo(AppDatabase db, String repoKey) async {
    final ids =
        await (db.selectOnly(db.ciRunHistory)
              ..addColumns([db.ciRunHistory.id])
              ..where(db.ciRunHistory.repoKey.equals(repoKey))
              ..orderBy([
                OrderingTerm.desc(db.ciRunHistory.finishedAt),
                OrderingTerm.desc(db.ciRunHistory.id),
              ]))
            .map((row) => row.read(db.ciRunHistory.id)!)
            .get();
    if (ids.length <= perRepoCap) return;
    final toDrop = ids.sublist(perRepoCap);
    await (db.delete(db.ciRunHistory)..where((t) => t.id.isIn(toDrop))).go();
  }

  /// The per-workflow trends over [window], worst-first (see
  /// [CiWorkflowTrend.aggregate]). Reads within the store lock so a concurrent
  /// [record] can't interleave with the read.
  static Future<List<CiWorkflowTrend>> trends({
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) {
    final at = now ?? DateTime.now();
    return _runLocked(() async {
      final db = _database;
      final rows = await db.select(db.ciRunHistory).get();
      final samples = rows.map(_toSample).toList();
      return CiWorkflowTrend.aggregate(samples, now: at, window: window);
    });
  }

  /// Drops all history for [repoKey] (e.g. after the repo is removed from
  /// monitoring), so its workflows stop appearing in the trends.
  static Future<void> removeRepo(String repoKey) async {
    final key = repoKey.trim();
    if (key.isEmpty) return;
    await _runLocked(() async {
      final db = _database;
      await (db.delete(
        db.ciRunHistory,
      )..where((t) => t.repoKey.equals(key))).go();
    });
  }

  static CiRunSample _toSample(CiRunHistoryRow row) => CiRunSample(
    provider: row.provider,
    repoKey: row.repoKey,
    repoDisplay: row.repoDisplay,
    workflow: row.workflow,
    workflowId: row.workflowId,
    runKey: row.runKey,
    outcome: row.outcome,
    conclusion: row.conclusion,
    branch: row.branch,
    finishedAt: row.finishedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.finishedAt!, isUtc: true),
    url: row.url,
  );

  static CiRunHistoryCompanion _companion(CiRunSample s) =>
      CiRunHistoryCompanion.insert(
        provider: s.provider,
        repoKey: s.repoKey,
        repoDisplay: s.repoDisplay,
        workflow: s.workflow,
        workflowId: Value(s.workflowId),
        runKey: s.runKey,
        outcome: s.outcome,
        conclusion: s.conclusion,
        branch: Value(s.branch),
        finishedAt: Value(s.finishedAt?.toUtc().millisecondsSinceEpoch),
        url: Value(s.url),
      );
}
