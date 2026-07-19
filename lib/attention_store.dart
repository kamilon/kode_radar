import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'attention_service.dart';
import 'database/app_database.dart';

/// Caches the attention-inbox snapshot on the local SQLite database (drift) so
/// the inbox renders instantly from disk on cold start / offline, with the
/// network as a refresher (Phase 2b of the local-database roadmap).
///
/// Attention items are a *computed ranking*, not an append-only log, so the
/// cache is a replaceable snapshot keyed by each item's deterministic
/// [AttentionItem.id]. [save] merges intelligently: items for repos that
/// returned an `error` this round (a transient/offline failure) are retained
/// from the prior snapshot, while repos that were fetched successfully have
/// their items replaced. Transient `error` items are never persisted; snoozed
/// items are filtered on read.
class AttentionStore {
  AttentionStore._();

  /// Category marking a per-repo fetch failure (not a real attention item).
  static const String errorCategory = AttentionService.errorCategory;

  static AppDatabase? _db;

  // Serializes mutating operations (save) relative to each other.
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

  /// Returns the cached snapshot ranked most-urgent first (severity desc, then
  /// repo) — a one-shot read companion to [watch]. Snooze is applied by callers
  /// at display time (see [AttentionInboxPage]), not here.
  static Future<List<AttentionItem>> cached() async {
    final rows = await _selectRanked().get();
    return rows.map(_toItem).toList();
  }

  /// A reactive stream of the full ranked cached snapshot that re-emits whenever
  /// the `attention_items` table changes — so a page bound to it renders the
  /// cache instantly on cold start and updates automatically when a refresh (or
  /// another in-isolate writer) persists new data.
  ///
  /// Unlike [cached] this does NOT apply a snooze filter: snooze is a display
  /// concern the page layers on top (via [SnoozeStore]) while the cache stays
  /// the source of truth for what each repo currently has.
  static Stream<List<AttentionItem>> watch() {
    return _selectRanked().watch().map((rows) => rows.map(_toItem).toList());
  }

  static SimpleSelectStatement<$AttentionItemsTable, AttentionItemRow>
  _selectRanked() {
    final db = _database;
    return db.select(db.attentionItems)..orderBy([
      (t) => OrderingTerm(expression: t.severity, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.repoDisplay),
      // Final tie-breaker so same-severity items in the same repo have a stable
      // order (SQLite is otherwise free to reorder them, causing list jitter
      // between cache and network renders).
      (t) => OrderingTerm(expression: t.id),
    ]);
  }

  /// Replaces the cached snapshot from a freshly-[computed] list (as returned by
  /// [AttentionService.computeAll], which emits one `error` item per repo that
  /// failed to load).
  ///
  /// Callers should pass the FULL snapshot (do not pre-filter snoozed items):
  /// the cache is the source of truth for what each repo currently has, and
  /// snooze is a display concern applied at read time by [cached]. Pre-filtering
  /// would make a snoozed-away or dismissed item look like the repo went clean
  /// and wrongly evict its cached data.
  ///
  /// Repos that returned an `error` this round keep their previously-cached
  /// items (so a transient/offline failure doesn't drop their data); every other
  /// repo's cached items are replaced by the fresh set (and repos no longer
  /// present — clean, or unmonitored — are dropped, self-healing the cache).
  /// `error` items themselves are never stored.
  static Future<void> save(List<AttentionItem> computed) async {
    await _runLocked(() async {
      final db = _database;
      final failedDisplays = computed
          .where((i) => i.category == errorCategory)
          .map((i) => i.repoDisplay)
          .toSet();
      final fresh = computed.where((i) => i.category != errorCategory).toList();

      await db.transaction(() async {
        // Drop everything except the rows for repos that failed this round,
        // which we retain as the last-known-good data for them.
        final keep = failedDisplays.toList();
        await (db.delete(db.attentionItems)..where(
              (t) => keep.isEmpty
                  ? const Constant(true)
                  : t.repoDisplay.isNotIn(keep),
            ))
            .go();

        // Insert the fresh (successful-repo) items; disjoint from the retained
        // failed-repo rows by repo, but upsert defensively on the id PK.
        for (final item in fresh) {
          await db
              .into(db.attentionItems)
              .insert(_toCompanion(item), mode: InsertMode.insertOrReplace);
        }
      });
    });
  }

  static AttentionItem _toItem(AttentionItemRow row) => AttentionItem(
    id: row.id,
    category: row.category,
    severity: row.severity,
    title: row.title,
    subtitle: row.subtitle,
    repoDisplay: row.repoDisplay,
    url: row.url,
    ageDays: row.ageDays,
    isMine: row.isMine,
  );

  static AttentionItemsCompanion _toCompanion(AttentionItem item) =>
      AttentionItemsCompanion.insert(
        id: item.id,
        category: item.category,
        severity: item.severity,
        title: item.title,
        subtitle: item.subtitle,
        repoDisplay: item.repoDisplay,
        url: Value(item.url),
        ageDays: Value(item.ageDays),
        isMine: item.isMine,
      );
}
