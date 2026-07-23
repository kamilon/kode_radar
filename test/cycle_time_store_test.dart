import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/cycle_time.dart';
import 'package:kode_radar/cycle_time_store.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

MergedPrSample _pr({
  required int number,
  String repoKey = 'github:owner/name',
  String repoDisplay = 'owner/name',
  required DateTime createdAt,
  required DateTime mergedAt,
  DateTime? firstReviewAt,
}) => MergedPrSample(
  provider: 'github',
  repoKey: repoKey,
  repoDisplay: repoDisplay,
  prKey: '$repoKey:$number',
  createdAt: createdAt,
  mergedAt: mergedAt,
  firstReviewAt: firstReviewAt,
  title: 'PR $number',
  author: 'octocat',
  url: 'https://example.com/$number',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    CycleTimeStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('round-trips samples including a null first-review', () async {
    final now = DateTime.utc(2026, 1, 15);
    await CycleTimeStore.record([
      _pr(
        number: 1,
        createdAt: DateTime.utc(2026, 1, 10, 0),
        firstReviewAt: DateTime.utc(2026, 1, 10, 2),
        mergedAt: DateTime.utc(2026, 1, 10, 5),
      ),
      _pr(
        number: 2,
        createdAt: DateTime.utc(2026, 1, 11, 0),
        mergedAt: DateTime.utc(2026, 1, 11, 4),
      ),
    ], now: now);

    final all = await CycleTimeStore.allSamples();
    expect(all, hasLength(2));
    final byKey = {for (final s in all) s.prKey: s};
    expect(
      byKey['github:owner/name:1']!.firstReviewAt,
      DateTime.utc(2026, 1, 10, 2),
    );
    expect(byKey['github:owner/name:2']!.firstReviewAt, isNull);
    expect(byKey['github:owner/name:2']!.title, 'PR 2');
  });

  test('de-duplicates by prKey (re-seen PR does not double-count)', () async {
    final now = DateTime.utc(2026, 1, 15);
    await CycleTimeStore.record([
      _pr(
        number: 1,
        createdAt: DateTime.utc(2026, 1, 10),
        mergedAt: DateTime.utc(2026, 1, 11),
      ),
    ], now: now);
    // Re-seen PR 1 (same prKey, now with a review time) plus a new PR 2.
    await CycleTimeStore.record([
      _pr(
        number: 1,
        createdAt: DateTime.utc(2026, 1, 10),
        firstReviewAt: DateTime.utc(2026, 1, 10, 6),
        mergedAt: DateTime.utc(2026, 1, 11),
      ),
      _pr(
        number: 2,
        createdAt: DateTime.utc(2026, 1, 12),
        mergedAt: DateTime.utc(2026, 1, 13),
      ),
    ], now: now);

    final all = await CycleTimeStore.allSamples();
    expect(all, hasLength(2));
    final one = all.firstWhere((s) => s.prKey == 'github:owner/name:1');
    expect(
      one.firstReviewAt,
      DateTime.utc(2026, 1, 10, 6),
      reason: 'the re-seen row is upserted with the newer review time',
    );
  });

  test('skips samples with an empty prKey', () async {
    final now = DateTime.utc(2026, 1, 15);
    await CycleTimeStore.record([
      MergedPrSample(
        provider: 'github',
        repoKey: 'github:owner/name',
        repoDisplay: 'owner/name',
        prKey: '',
        createdAt: DateTime.utc(2026, 1, 10),
        mergedAt: DateTime.utc(2026, 1, 11),
      ),
      _pr(
        number: 9,
        createdAt: DateTime.utc(2026, 1, 12),
        mergedAt: DateTime.utc(2026, 1, 13),
      ),
    ], now: now);
    final all = await CycleTimeStore.allSamples();
    expect(all, hasLength(1));
    expect(all.single.prKey, 'github:owner/name:9');
  });

  test('age prune drops PRs merged before the retention window', () async {
    final now = DateTime.utc(2026, 6, 1);
    await CycleTimeStore.record([
      _pr(
        number: 1,
        createdAt: now.subtract(const Duration(days: 200)),
        mergedAt: now.subtract(const Duration(days: 200)),
      ),
      _pr(
        number: 2,
        createdAt: now.subtract(const Duration(days: 2)),
        mergedAt: now.subtract(const Duration(days: 1)),
      ),
    ], now: now);
    final all = await CycleTimeStore.allSamples();
    expect(all, hasLength(1));
    expect(all.single.prKey, 'github:owner/name:2');
  });

  test('removeRepo drops only that repo history', () async {
    final now = DateTime.utc(2026, 1, 15);
    await CycleTimeStore.record([
      _pr(
        number: 1,
        repoKey: 'github:owner/a',
        repoDisplay: 'owner/a',
        createdAt: DateTime.utc(2026, 1, 10),
        mergedAt: DateTime.utc(2026, 1, 11),
      ),
      _pr(
        number: 1,
        repoKey: 'github:owner/b',
        repoDisplay: 'owner/b',
        createdAt: DateTime.utc(2026, 1, 10),
        mergedAt: DateTime.utc(2026, 1, 11),
      ),
    ], now: now);
    await CycleTimeStore.removeRepo('github:owner/a');
    final all = await CycleTimeStore.allSamples();
    expect(all, hasLength(1));
    expect(all.single.repoKey, 'github:owner/b');
  });

  test(
    'v12 -> v13 upgrade creates merged_prs with a working unique index',
    () async {
      // A database at the pre-v13 schema (user_version = 12): opening
      // AppDatabase over it runs onUpgrade(12 -> 13), which must create
      // merged_prs and its UNIQUE pr_key index (the insert-or-replace de-dup
      // relies on it).
      final native = sqlite3.openInMemory();
      native.execute('PRAGMA user_version = 12;');
      final upgraded = AppDatabase.forExecutor(
        NativeDatabase.opened(native, closeUnderlyingOnClose: true),
      );
      CycleTimeStore.debugUseDatabase(upgraded);

      final now = DateTime.utc(2026, 1, 15);
      await CycleTimeStore.record([
        _pr(
          number: 1,
          createdAt: DateTime.utc(2026, 1, 10),
          mergedAt: DateTime.utc(2026, 1, 11),
        ),
      ], now: now);
      await CycleTimeStore.record([
        _pr(
          number: 1,
          createdAt: DateTime.utc(2026, 1, 10),
          firstReviewAt: DateTime.utc(2026, 1, 10, 3),
          mergedAt: DateTime.utc(2026, 1, 11),
        ),
      ], now: now);

      final all = await CycleTimeStore.allSamples();
      // Same prKey replaced rather than duplicated: one row, now with a review.
      expect(all, hasLength(1));
      expect(all.single.firstReviewAt, DateTime.utc(2026, 1, 10, 3));
      await upgraded.close();
    },
  );
}
