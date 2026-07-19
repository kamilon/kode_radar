import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_event.dart';
import 'activity_feed_service.dart';
import 'database/app_database.dart';
import 'monitored_repos.dart';
import 'repo_store.dart';

/// Caches normalized cross-repo [ActivityEvent]s on the local SQLite database
/// (drift) so the Activity Feed can render instantly from disk on cold start
/// and treat the network as a refresher (Phase 2 of the local-database
/// roadmap).
///
/// Events are keyed by `(repoKey, eventId)`: re-fetching the same event upserts
/// its (possibly updated) row instead of duplicating it. On [save] the cache is
/// pruned to the [maxRetention] horizon and the [ActivityFeedService.maxEvents]
/// cap so it stays bounded; reads filter to the caller's display window.
class ActivityEventStore {
  ActivityEventStore._();

  /// How much history to retain on disk, independent of the feed's *display*
  /// lookback. Set to the widest lookback the UI offers so shrinking then
  /// re-widening the lookback (e.g. 60 → 7 → 60) recovers previously-cached
  /// events instead of permanently discarding them; reads still filter to the
  /// caller's requested window (see [cached]).
  static const Duration maxRetention = Duration(days: 60);

  static AppDatabase? _db;

  // Serializes mutating operations (save / removeRepo) relative to each other.
  // drift already serializes transactions on the single connection; this keeps
  // a save's upsert+prune atomic with respect to a concurrent removeRepo.
  static Future<void> _lock = SynchronousFuture<void>(null);

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static AppDatabase get _database => _db ??= AppDatabase();

  /// Test hook: back the store with an injected (e.g. in-memory) database and
  /// reset the mutation lock so each injected database starts from a clean
  /// serialization state.
  @visibleForTesting
  static void debugUseDatabase(AppDatabase db) {
    _db = db;
    _lock = SynchronousFuture<void>(null);
  }

  /// Returns the cached events within [lookback] of [now] (default: now),
  /// newest first, capped at [ActivityFeedService.maxEvents] — matching the
  /// shape the feed would fetch from the network.
  ///
  /// When [repoKey] is given, only that repo's events are returned (and the cap
  /// applies to that repo), so a single repo's cached timeline isn't hidden
  /// behind the global newest-[ActivityFeedService.maxEvents] window.
  static Future<List<ActivityEvent>> cached({
    Duration lookback = ActivityFeedService.defaultLookback,
    DateTime? now,
    String? repoKey,
  }) async {
    final since = (now ?? DateTime.now()).toUtc().subtract(lookback);
    final db = _database;
    final query = db.select(db.activityEvents)
      ..where(
        (t) => t.occurredAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch),
      );
    if (repoKey != null) {
      query.where((t) => t.repoKey.equals(repoKey));
    }
    final rows =
        await (query
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.occurredAt,
                  mode: OrderingMode.desc,
                ),
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(ActivityFeedService.maxEvents))
            .get();
    return rows.map(_toEvent).toList();
  }

  /// Upserts [events] into the cache (keyed by `(repoKey, eventId)`), prunes
  /// anything older than [maxRetention] before [now], then trims the whole cache
  /// to [ActivityFeedService.maxEvents] newest rows so it stays bounded.
  ///
  /// Upsert (rather than replace-all) means a transient per-source fetch failure
  /// doesn't evict still-valid cached events from sources that didn't refresh.
  ///
  /// When [restrictToMonitored] is true the currently-persisted repo lists are
  /// read and (a) events for repos no longer monitored are skipped and (b) any
  /// cached rows for unmonitored repos are purged. This self-heals the cache
  /// against a repo removed while a feed fetch was already in flight (whose
  /// in-flight result would otherwise re-insert the just-deleted repo's events)
  /// and against repos removed while offline.
  static Future<void> save(
    List<ActivityEvent> events, {
    DateTime? now,
    bool restrictToMonitored = false,
  }) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(maxRetention);
    await _runLocked(() async {
      final db = _database;

      Set<String>? monitored;
      if (restrictToMonitored) {
        final prefs = await SharedPreferences.getInstance();
        monitored = parseMonitoredRepos(
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[],
          prefs.getStringList(RepoStore.adoKey) ?? const <String>[],
        ).map((repo) => repo.repoKey).toSet();
      }

      final toSave = monitored == null
          ? events
          : events.where((e) => monitored!.contains(e.repoKey)).toList();

      await db.transaction(() async {
        for (final event in toSave) {
          await db
              .into(db.activityEvents)
              .insert(
                _toCompanion(event),
                onConflict: DoUpdate(
                  (_) => _toCompanion(event),
                  target: [
                    db.activityEvents.repoKey,
                    db.activityEvents.eventId,
                  ],
                ),
              );
        }

        // Drop anything that has aged out of the retention window.
        await (db.delete(db.activityEvents)..where(
              (t) => t.occurredAt.isSmallerThanValue(
                cutoff.millisecondsSinceEpoch,
              ),
            ))
            .go();

        // Purge cached rows for repos that are no longer monitored.
        if (monitored != null) {
          final keep = monitored.toList();
          await (db.delete(db.activityEvents)..where(
                (t) => keep.isEmpty
                    ? const Constant(true)
                    : t.repoKey.isNotIn(keep),
              ))
              .go();
        }

        await _pruneToMax(db);
      });
    });
  }

  /// Drops all cached events for [repoKey] (e.g. after the repo is removed from
  /// monitoring) so deleted repos don't linger as stale rows.
  static Future<void> removeRepo(String repoKey) async {
    final key = repoKey.trim();
    if (key.isEmpty) return;
    await _runLocked(() async {
      final db = _database;
      await (db.delete(
        db.activityEvents,
      )..where((t) => t.repoKey.equals(key))).go();
    });
  }

  /// Keeps only the newest [ActivityFeedService.maxEvents] rows across the whole
  /// cache.
  static Future<void> _pruneToMax(AppDatabase db) async {
    final ids =
        await (db.selectOnly(db.activityEvents)
              ..addColumns([db.activityEvents.id])
              ..orderBy([
                OrderingTerm(
                  expression: db.activityEvents.occurredAt,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm(
                  expression: db.activityEvents.id,
                  mode: OrderingMode.desc,
                ),
              ]))
            .map((row) => row.read(db.activityEvents.id)!)
            .get();
    if (ids.length <= ActivityFeedService.maxEvents) return;
    final toDelete = ids.sublist(ActivityFeedService.maxEvents);
    await (db.delete(
      db.activityEvents,
    )..where((t) => t.id.isIn(toDelete))).go();
  }

  static ActivityEvent _toEvent(ActivityEventRow row) => ActivityEvent(
    id: row.eventId,
    type: row.type,
    provider: row.provider,
    repoKey: row.repoKey,
    repoDisplay: row.repoDisplay,
    actor: row.actor,
    title: row.title,
    subtitle: row.subtitle,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(
      row.occurredAt,
      isUtc: true,
    ),
    url: row.url,
    isMine: row.isMine,
  );

  static ActivityEventsCompanion _toCompanion(ActivityEvent event) =>
      ActivityEventsCompanion.insert(
        eventId: event.id,
        type: event.type,
        provider: event.provider,
        repoKey: event.repoKey,
        repoDisplay: event.repoDisplay,
        actor: event.actor,
        title: event.title,
        subtitle: event.subtitle,
        occurredAt: event.occurredAt.toUtc().millisecondsSinceEpoch,
        url: Value(event.url),
        isMine: event.isMine,
      );
}
