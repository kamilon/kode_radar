import 'dart:async';

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
    DateTime? now,
  }) {
    return _read(
      repoKey,
      releasesSupported: releasesSupported,
      now: now ?? DateTime.now(),
    );
  }

  /// A reactive stream of the cached composite for [repoKey] that re-emits
  /// whenever this repo's pull-request or CI rows change — plus release rows for
  /// providers that support releases ([releasesSupported]) — so a page bound to
  /// it renders the cache instantly on cold start and updates automatically when
  /// a refresh (or a repo-delete prune) persists new data.
  ///
  /// Each emission recomputes PR ages against the current time *at the moment of
  /// that emission*; ages don't tick forward between DB changes (a page that
  /// needs a fresher age re-reads on its own load / cold start).
  ///
  /// drift's change notifications are table-granular, so this fires on a write
  /// to any repo's rows in those tables (like the feed/attention `watch`
  /// streams); the `WHERE repoKey` in [_read] keeps the emitted data correctly
  /// scoped, and such cross-repo triggers are rare and cheap.
  static Stream<RepoDetailData> watch(
    String repoKey, {
    required bool releasesSupported,
  }) {
    final db = _database;
    late StreamController<RepoDetailData> controller;
    StreamSubscription<Set<TableUpdate>>? updatesSub;

    // Concurrent emit() calls stay ordered because [_read] runs through the
    // store's static [_runLocked] chain: reads execute in invocation order and
    // each completes before the next starts, so their `controller.add`s fire in
    // order. The initial emit() below is invoked before the update listener, so
    // it's always queued first — a later table-change read can't overtake it and
    // revert the stream to stale data.
    Future<void> emit() async {
      try {
        final data = await _read(
          repoKey,
          releasesSupported: releasesSupported,
          now: DateTime.now(),
        );
        if (!controller.isClosed) controller.add(data);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller = StreamController<RepoDetailData>(
      onListen: () {
        // Initial snapshot, then re-read on any change to the composite's
        // tables. `onAllTables` fires when repo_pulls or repo_runs — and
        // repo_releases when releases are supported — is written.
        emit();
        updatesSub = db
            .tableUpdates(
              TableUpdateQuery.onAllTables([
                db.repoPulls,
                db.repoRuns,
                if (releasesSupported) db.repoReleases,
              ]),
            )
            .listen(
              (_) => emit(),
              onError: (Object e, StackTrace st) {
                if (!controller.isClosed) controller.addError(e, st);
              },
              onDone: () {
                if (!controller.isClosed) controller.close();
              },
            );
      },
      onCancel: () async {
        await updatesSub?.cancel();
        // Close the controller so any emit() still in flight (guarded by
        // isClosed) is dropped rather than buffered on a listener-less stream.
        if (!controller.isClosed) await controller.close();
      },
    );
    return controller.stream;
  }

  /// Reads the cached composite for [repoKey] at [now]. All three tables are
  /// read under the same lock the mutators use, so a concurrent save/removeRepo
  /// can't interleave between the SELECTs and yield an inconsistent composite
  /// (e.g. pulls from before a save, runs from after).
  static Future<RepoDetailData> _read(
    String repoKey, {
    required bool releasesSupported,
    required DateTime now,
  }) {
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
      // Skip the releases query for providers that don't support releases
      // (e.g. Azure DevOps) — nothing is ever persisted there for such repos.
      final releases = releasesSupported
          ? await (db.select(db.repoReleases)
                  ..where((t) => t.repoKey.equals(repoKey))
                  ..orderBy([(t) => OrderingTerm(expression: t.id)]))
                .get()
          : const <RepoReleaseRow>[];
      return RepoDetailData(
        pulls: pulls.map((row) => _toPr(row, now)).toList(),
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

  static RepoPr _toPr(RepoPrRow row, DateTime now) {
    final createdAt = row.createdAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.createdAt!, isUtc: true);
    // Recompute age from the stored creation time so a cached PR's age reflects
    // "now" on read instead of freezing at its fetch-time value. Fall back to
    // the stored ageDays for rows written before created_at was persisted.
    final int? ageDays;
    if (createdAt == null) {
      ageDays = row.ageDays;
    } else {
      final diff = now.difference(createdAt).inDays;
      ageDays = diff < 0 ? 0 : diff;
    }
    return RepoPr(
      label: row.label,
      title: row.title,
      author: row.author,
      reviewState: row.reviewState,
      ageDays: ageDays,
      createdAt: createdAt,
      draft: row.draft,
      url: row.url,
      mergeable: row.mergeable ?? PrMergeable.unknown,
      additions: row.additions,
      deletions: row.deletions,
      changedFiles: row.changedFiles,
    );
  }

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
        createdAt: Value(pr.createdAt?.toUtc().millisecondsSinceEpoch),
        draft: pr.draft,
        url: Value(pr.url),
        mergeable: Value(pr.mergeable),
        additions: Value(pr.additions),
        deletions: Value(pr.deletions),
        changedFiles: Value(pr.changedFiles),
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
