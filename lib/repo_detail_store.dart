import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'database/app_database.dart';
import 'repo_detail_service.dart';

/// Caches the per-repo detail (open PRs, CI runs, releases) on the local SQLite
/// database (drift) so the repo drill-down renders instantly from disk on cold
/// start / offline, with the network as a refresher (Phase 2c of the
/// local-database roadmap).
///
/// Rows are keyed by `repoKey`; the autoincrement `id` preserves the provider's
/// list order. [save] replaces a source's rows only when that source loaded
/// successfully this round, so a transient/offline failure of one source (e.g.
/// CI) keeps its last-known-good rows while the others refresh.
class RepoDetailStore {
  RepoDetailStore._();

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

  /// Reads the cached detail for [repoKey]. Failure flags are always false —
  /// the cache is last-known-good; the caller supplies [releasesSupported]
  /// (derived from the provider, not persisted).
  static Future<RepoDetailData> cached(
    String repoKey, {
    required bool releasesSupported,
  }) {
    // Read all three tables under the same lock the mutators use, so a
    // concurrent save/removeRepo can't interleave between the SELECTs and yield
    // an inconsistent composite (e.g. pulls from before a save, runs from
    // after).
    return _runLocked(() async {
      final db = _database;
      final pulls =
          await (db.select(db.repoPulls)
                ..where((t) => t.repoKey.equals(repoKey))
                ..orderBy([(t) => OrderingTerm(expression: t.id)]))
              .get();
      final runs =
          await (db.select(db.repoRuns)
                ..where((t) => t.repoKey.equals(repoKey))
                ..orderBy([(t) => OrderingTerm(expression: t.id)]))
              .get();
      final releases =
          await (db.select(db.repoReleases)
                ..where((t) => t.repoKey.equals(repoKey))
                ..orderBy([(t) => OrderingTerm(expression: t.id)]))
              .get();
      return RepoDetailData(
        pulls: pulls.map(_toPr).toList(),
        ci: runs.map(_toRun).toList(),
        releases: releases.map(_toRelease).toList(),
        releasesSupported: releasesSupported,
      );
    });
  }

  /// Persists [data] for [repoKey]. Each source (pulls / CI / releases) is
  /// replaced only when it did NOT fail this round; a failed source keeps its
  /// cached rows so an offline/partial refresh never blanks it. Releases are
  /// only touched when the provider supports them.
  static Future<void> save(String repoKey, RepoDetailData data) async {
    await _runLocked(() async {
      final db = _database;
      await db.transaction(() async {
        if (!data.pullsFailed) {
          await (db.delete(
            db.repoPulls,
          )..where((t) => t.repoKey.equals(repoKey))).go();
          for (final pr in data.pulls) {
            await db.into(db.repoPulls).insert(_prCompanion(repoKey, pr));
          }
        }
        if (!data.ciFailed) {
          await (db.delete(
            db.repoRuns,
          )..where((t) => t.repoKey.equals(repoKey))).go();
          for (final run in data.ci) {
            await db.into(db.repoRuns).insert(_runCompanion(repoKey, run));
          }
        }
        if (data.releasesSupported && !data.releasesFailed) {
          await (db.delete(
            db.repoReleases,
          )..where((t) => t.repoKey.equals(repoKey))).go();
          for (final release in data.releases) {
            await db
                .into(db.repoReleases)
                .insert(_releaseCompanion(repoKey, release));
          }
        }
      });
    });
  }

  /// Drops all cached detail for [repoKey] (e.g. after the repo is removed from
  /// monitoring).
  static Future<void> removeRepo(String repoKey) async {
    final key = repoKey.trim();
    if (key.isEmpty) return;
    await _runLocked(() async {
      final db = _database;
      await db.transaction(() async {
        await (db.delete(
          db.repoPulls,
        )..where((t) => t.repoKey.equals(key))).go();
        await (db.delete(
          db.repoRuns,
        )..where((t) => t.repoKey.equals(key))).go();
        await (db.delete(
          db.repoReleases,
        )..where((t) => t.repoKey.equals(key))).go();
      });
    });
  }

  static RepoPr _toPr(RepoPrRow row) => RepoPr(
    label: row.label,
    title: row.title,
    author: row.author,
    reviewState: row.reviewState,
    ageDays: row.ageDays,
    draft: row.draft,
    url: row.url,
  );

  static RepoRun _toRun(RepoRunRow row) => RepoRun(
    name: row.name,
    status: row.status,
    conclusion: row.conclusion,
    branch: row.branch,
    finishedAt: row.finishedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.finishedAt!, isUtc: true),
    url: row.url,
  );

  static RepoRelease _toRelease(RepoReleaseRow row) => RepoRelease(
    tag: row.tag,
    name: row.name,
    author: row.author,
    publishedAt: row.publishedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.publishedAt!, isUtc: true),
    url: row.url,
  );

  static RepoPullsCompanion _prCompanion(String repoKey, RepoPr pr) =>
      RepoPullsCompanion.insert(
        repoKey: repoKey,
        label: pr.label,
        title: pr.title,
        author: pr.author,
        reviewState: pr.reviewState,
        ageDays: Value(pr.ageDays),
        draft: pr.draft,
        url: Value(pr.url),
      );

  static RepoRunsCompanion _runCompanion(String repoKey, RepoRun run) =>
      RepoRunsCompanion.insert(
        repoKey: repoKey,
        name: run.name,
        status: run.status,
        conclusion: run.conclusion,
        branch: Value(run.branch),
        finishedAt: Value(run.finishedAt?.toUtc().millisecondsSinceEpoch),
        url: Value(run.url),
      );

  static RepoReleasesCompanion _releaseCompanion(
    String repoKey,
    RepoRelease release,
  ) => RepoReleasesCompanion.insert(
    repoKey: repoKey,
    tag: release.tag,
    name: Value(release.name),
    author: Value(release.author),
    publishedAt: Value(release.publishedAt?.toUtc().millisecondsSinceEpoch),
    url: Value(release.url),
  );
}
