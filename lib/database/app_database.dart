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

/// Cached attention-inbox items (Phase 2b). A ranked snapshot of PRs needing
/// action across all monitored repos, so the inbox renders instantly on cold
/// start / offline. `id` is the deterministic identity the service already
/// assigns (e.g. `reviewRequested:owner/name:PR #12`) and is used as the PK so
/// a recompute replaces rather than duplicates. Transient `error` items are not
/// persisted. The generated row class is named `AttentionItemRow` to avoid
/// colliding with the `AttentionItem` DTO.
@DataClassName('AttentionItemRow')
@TableIndex(name: 'idx_attention_items_repo_display', columns: {#repoDisplay})
class AttentionItems extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  IntColumn get severity => integer()();
  TextColumn get title => text()();
  TextColumn get subtitle => text()();
  TextColumn get repoDisplay => text()();
  TextColumn get url => text().nullable()();
  IntColumn get ageDays => integer().nullable()();
  IntColumn get createdAt => integer().nullable()();
  BoolColumn get isMine => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached per-repo detail (Phase 2c): the open pull requests, CI runs, and
/// releases shown on the repo drill-down, so it renders instantly on cold start
/// / offline. Each row carries its `repoKey`; the autoincrement `id` preserves
/// the provider's list order. Generated row classes are suffixed `Row` to avoid
/// colliding with the `RepoPr`/`RepoRun`/`RepoRelease` DTOs.
@DataClassName('RepoPrRow')
@TableIndex(name: 'idx_repo_pulls_repo_key', columns: {#repoKey})
class RepoPulls extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get repoKey => text()();
  TextColumn get label => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get reviewState => text()();
  IntColumn get ageDays => integer().nullable()();
  IntColumn get createdAt => integer().nullable()();
  BoolColumn get draft => boolean()();
  TextColumn get url => text().nullable()();
  TextColumn get mergeable => text().nullable()();
  IntColumn get additions => integer().nullable()();
  IntColumn get deletions => integer().nullable()();
  IntColumn get changedFiles => integer().nullable()();
}

@DataClassName('RepoRunRow')
@TableIndex(name: 'idx_repo_runs_repo_key', columns: {#repoKey})
class RepoRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get repoKey => text()();
  TextColumn get name => text()();
  TextColumn get status => text()();
  TextColumn get conclusion => text()();
  TextColumn get branch => text().nullable()();
  IntColumn get finishedAt => integer().nullable()();
  TextColumn get url => text().nullable()();
}

@DataClassName('RepoReleaseRow')
@TableIndex(name: 'idx_repo_releases_repo_key', columns: {#repoKey})
class RepoReleases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get repoKey => text()();
  TextColumn get tag => text()();
  TextColumn get name => text().nullable()();
  TextColumn get author => text().nullable()();
  IntColumn get publishedAt => integer().nullable()();
  TextColumn get url => text().nullable()();
}

/// Accumulated CI run history (Phase 5): one row per observed workflow/build
/// run, de-duplicated by [runKey] (a provider-stable id), so repeated syncs
/// that re-see the same recent runs union rather than double-count. Powers the
/// "CI trends" insight (per-workflow failure rate + flakiness). Rows are pruned
/// by age and a per-repo cap so the table stays bounded. `outcome` is the
/// normalized bucket (success/failure/running/other); `conclusion` keeps the
/// raw provider result for display.
@DataClassName('CiRunHistoryRow')
@TableIndex(
  name: 'idx_ci_run_history_run_key',
  columns: {#runKey},
  unique: true,
)
@TableIndex(name: 'idx_ci_run_history_repo_key', columns: {#repoKey})
@TableIndex(name: 'idx_ci_run_history_finished_at', columns: {#finishedAt})
class CiRunHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()();
  TextColumn get repoKey => text()();
  TextColumn get repoDisplay => text()();
  TextColumn get workflow => text()();
  TextColumn get workflowId => text().nullable()();
  TextColumn get runKey => text()();
  TextColumn get outcome => text()();
  TextColumn get conclusion => text()();
  TextColumn get branch => text().nullable()();
  IntColumn get finishedAt => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get url => text().nullable()();
}

/// Accumulated merged-PR history (Phase 6): one row per merged pull request,
/// de-duplicated by [prKey], powering the review-time / cycle-time trends
/// (median open→first-review and open→merge per repo/team). Pruned by age and a
/// per-repo cap so the table stays bounded.
@DataClassName('MergedPrRow')
@TableIndex(name: 'idx_merged_prs_pr_key', columns: {#prKey}, unique: true)
@TableIndex(name: 'idx_merged_prs_repo_key', columns: {#repoKey})
@TableIndex(name: 'idx_merged_prs_merged_at', columns: {#mergedAt})
class MergedPrs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()();
  TextColumn get repoKey => text()();
  TextColumn get repoDisplay => text()();
  TextColumn get prKey => text()();
  IntColumn get createdAt => integer()();
  IntColumn get mergedAt => integer()();
  IntColumn get firstReviewAt => integer().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get url => text().nullable()();
}

/// Per-scope sync provenance (Phase 3): when a cache scope was last refreshed
/// successfully from the network, so the UI can show an accurate "updated Xh
/// ago" instead of "just now" when it's actually displaying stale cached data.
/// `scope` is a stable key like `feed`, `attention`, or `repo:<repoKey>`.
/// `etag`/`cursor` are reserved for later conditional-GET / pagination slices.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get scope => text()();
  IntColumn get lastSuccessAt => integer().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column> get primaryKey => {scope};
}

/// The attention notification "seen" baseline (Phase 4), moved off
/// `SharedPreferences` so the resident foreground and the background-sync
/// isolate no longer read-modify-write the same blob and clobber each other.
/// One row per already-notified attention id; inserts are additive
/// (`INSERT OR REPLACE` on the unique `seenId` — which keeps the id present but
/// bumps it to a fresh, newest autoincrement `id`), so two isolates recording
/// concurrently union rather than overwrite, and a still-current id is never
/// pruned as "oldest". The autoincrement `id` orders rows for oldest-first
/// pruning.
@DataClassName('NotificationSeenRow')
@TableIndex(
  name: 'idx_notification_seen_seen_id',
  columns: {#seenId},
  unique: true,
)
class NotificationSeen extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get seenId => text()();
}

/// Repos whose existing attention backlog has been seeded silently (Phase 4);
/// keyed by `repoDisplay` so inserts are additive across isolates.
@DataClassName('NotificationKnownRepoRow')
class NotificationKnownRepos extends Table {
  TextColumn get repoDisplay => text()();

  @override
  Set<Column> get primaryKey => {repoDisplay};
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
@DriftDatabase(
  tables: [
    MetricSnapshots,
    AppMeta,
    ActivityEvents,
    AttentionItems,
    RepoPulls,
    RepoRuns,
    RepoReleases,
    SyncState,
    NotificationSeen,
    NotificationKnownRepos,
    CiRunHistory,
    MergedPrs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Builds a database over a caller-provided executor (e.g.
  /// `NativeDatabase.memory()` in unit tests).
  AppDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 adds the activity-feed cache (Phase 2). Create the table and its
      // indexes explicitly — `createTable` only issues `CREATE TABLE`, so the
      // (repo_key, event_id) UNIQUE index the upsert relies on must be created
      // separately or existing (v1) installs would get duplicate rows.
      //
      // All statements are unconditionally idempotent (`IF NOT EXISTS`) so a
      // concurrent open from a second connection (e.g. the background-sync
      // isolate) that also observed v1 can't crash on "table/index already
      // exists": drift runs `onUpgrade` in autocommit (no wrapping migration
      // transaction), so the check-then-create couldn't otherwise be made race
      // free. `createTable` already emits `CREATE TABLE IF NOT EXISTS`; the
      // index DDL drift generates does not, so issue it directly.
      if (from < 2) {
        await m.createTable(activityEvents);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_activity_events_repo_key '
          'ON activity_events (repo_key)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_activity_events_occurred_at '
          'ON activity_events (occurred_at)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_activity_events_repo_event '
          'ON activity_events (repo_key, event_id)',
        );
      }
      // v3 adds the attention-inbox cache (Phase 2b). Same idempotent-DDL
      // reasoning as above; the PK index is part of `CREATE TABLE`, so only the
      // secondary repo_display index needs an explicit statement.
      if (from < 3) {
        await m.createTable(attentionItems);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attention_items_repo_display '
          'ON attention_items (repo_display)',
        );
      }
      // v4 adds the repo-detail cache (Phase 2c): pulls, CI runs, releases.
      // Same idempotent-DDL reasoning as above.
      if (from < 4) {
        await m.createTable(repoPulls);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_repo_pulls_repo_key '
          'ON repo_pulls (repo_key)',
        );
        await m.createTable(repoRuns);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_repo_runs_repo_key '
          'ON repo_runs (repo_key)',
        );
        await m.createTable(repoReleases);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_repo_releases_repo_key '
          'ON repo_releases (repo_key)',
        );
      }
      // v5 adds the sync-provenance table (Phase 3). Its PK index is part of
      // `CREATE TABLE IF NOT EXISTS`, so no secondary index is needed.
      if (from < 5) {
        await m.createTable(syncState);
      }
      // v6 adds `created_at` to repo_pulls so a cached PR's age can be recomputed
      // on read (Phase 3b). Ensure the table exists first (real upgrades have it
      // from v4, but keep this step self-contained), then add the column with a
      // single `ALTER TABLE ADD COLUMN`. This avoids a multi-statement
      // drop+recreate (whose interleaving across isolates could crash on a
      // half-recreated table) and keeps existing cached rows. A concurrent
      // migrator — or a jump from <4, where `createTable` already built the
      // current schema — may have already added it, so tolerate "duplicate
      // column".
      if (from < 6) {
        await m.createTable(repoPulls);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_repo_pulls_repo_key '
          'ON repo_pulls (repo_key)',
        );
        try {
          await customStatement(
            'ALTER TABLE repo_pulls ADD COLUMN created_at INTEGER',
          );
        } on Exception catch (e) {
          if (!e.toString().toLowerCase().contains('duplicate column')) {
            rethrow;
          }
        }
      }
      // v7 adds the notification "seen" baseline tables (Phase 4). Idempotent
      // DDL as elsewhere; the known-repos PK index is part of `CREATE TABLE`, so
      // only the seen unique index needs an explicit statement.
      if (from < 7) {
        await m.createTable(notificationSeen);
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_seen_seen_id '
          'ON notification_seen (seen_id)',
        );
        await m.createTable(notificationKnownRepos);
      }
      // v8 adds `created_at` to attention_items so a cached item's displayed age
      // can be recomputed on read (unfreezing it offline), mirroring the v6
      // repo_pulls change. Ensure the table exists first (keep the step
      // self-contained), then add the column with a single idempotent
      // `ALTER TABLE ADD COLUMN`, tolerating "duplicate column" from a
      // concurrent migrator or a jump from <3 where `createTable` already built
      // the current schema.
      if (from < 8) {
        await m.createTable(attentionItems);
        try {
          await customStatement(
            'ALTER TABLE attention_items ADD COLUMN created_at INTEGER',
          );
        } on Exception catch (e) {
          if (!e.toString().toLowerCase().contains('duplicate column')) {
            rethrow;
          }
        }
      }
      // v9 adds PR triage columns to repo_pulls (mergeable + diff size). Ensure
      // the table exists, then add each column with an idempotent
      // `ALTER TABLE ADD COLUMN`, tolerating "duplicate column" (concurrent
      // migrator, or a jump from <4 where createTable already built the current
      // schema).
      if (from < 9) {
        await m.createTable(repoPulls);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_repo_pulls_repo_key '
          'ON repo_pulls (repo_key)',
        );
        for (final ddl in const [
          'ALTER TABLE repo_pulls ADD COLUMN mergeable TEXT',
          'ALTER TABLE repo_pulls ADD COLUMN additions INTEGER',
          'ALTER TABLE repo_pulls ADD COLUMN deletions INTEGER',
          'ALTER TABLE repo_pulls ADD COLUMN changed_files INTEGER',
        ]) {
          try {
            await customStatement(ddl);
          } on Exception catch (e) {
            if (!e.toString().toLowerCase().contains('duplicate column')) {
              rethrow;
            }
          }
        }
      }
      // v10 adds the CI run-history table (Phase 5). Same idempotent-DDL
      // reasoning as the earlier steps: `createTable` emits only
      // `CREATE TABLE IF NOT EXISTS`, so create each @TableIndex explicitly with
      // `CREATE [UNIQUE] INDEX IF NOT EXISTS` — the unique run_key index the
      // record() upsert relies on especially — so a concurrent open from the
      // background-sync isolate can't crash on an already-existing object.
      if (from < 10) {
        await m.createTable(ciRunHistory);
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_ci_run_history_run_key '
          'ON ci_run_history (run_key)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_ci_run_history_repo_key '
          'ON ci_run_history (repo_key)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_ci_run_history_finished_at '
          'ON ci_run_history (finished_at)',
        );
      }
      // v11 changes CI-trend semantics to default-branch-only. ci_run_history
      // is a derived cache (re-populated from the API on the next sync), so
      // clear the now-stale all-branch rows rather than let them linger for the
      // retention window. Idempotent and safe to race: DELETE on an empty/just-
      // created table is a no-op, and `from < 10` above guarantees the table
      // exists first on a multi-version jump. In the rare case two connections
      // both observe v10 and one records fresh rows before the other's DELETE
      // runs, the only effect is that those rows are cleared and later re-
      // observed from the API on a subsequent sync — a derived cache self-
      // heals, so no serialization/marker is warranted here.
      if (from < 11) {
        await customStatement('DELETE FROM ci_run_history');
      }
      // v12 adds `duration_ms` to ci_run_history (run-duration trends). Ensure
      // the table exists, then add the column with a single idempotent
      // `ALTER TABLE ADD COLUMN`, tolerating "duplicate column" from a
      // concurrent migrator or a jump from <10 where createTable already built
      // the current schema.
      if (from < 12) {
        await m.createTable(ciRunHistory);
        try {
          await customStatement(
            'ALTER TABLE ci_run_history ADD COLUMN duration_ms INTEGER',
          );
        } on Exception catch (e) {
          if (!e.toString().toLowerCase().contains('duplicate column')) {
            rethrow;
          }
        }
      }
      // v13 adds the merged-PR history table (Phase 6, cycle-time trends). Same
      // idempotent-DDL reasoning as the CI-history table: `createTable` emits
      // only `CREATE TABLE IF NOT EXISTS`, so create each @TableIndex explicitly
      // with `CREATE [UNIQUE] INDEX IF NOT EXISTS` — the unique pr_key index the
      // upsert relies on especially — so a concurrent background-isolate open
      // can't crash on an already-existing object.
      if (from < 13) {
        await m.createTable(mergedPrs);
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_merged_prs_pr_key '
          'ON merged_prs (pr_key)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_merged_prs_repo_key '
          'ON merged_prs (repo_key)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_merged_prs_merged_at '
          'ON merged_prs (merged_at)',
        );
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
