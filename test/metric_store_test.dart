import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/activity_service.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:kode_radar/metric_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    MetricStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('shouldCapture honors the minimum capture interval', () {
    final now = DateTime.utc(2026, 1, 1, 12);

    expect(MetricStore.shouldCapture(null, now), isTrue);
    expect(
      MetricStore.shouldCapture(
        now.subtract(const Duration(hours: 23, minutes: 59)),
        now,
      ),
      isFalse,
    );
    expect(
      MetricStore.shouldCapture(
        now.subtract(MetricStore.minCaptureInterval),
        now,
      ),
      isTrue,
    );
    expect(
      MetricStore.shouldCapture(now.subtract(const Duration(hours: 25)), now),
      isTrue,
    );
  });

  test('capture appends one snapshot per repo and dedups within 24h', () async {
    final now = DateTime.utc(2026, 1, 1, 12);

    await MetricStore.capture([
      _activity('github:owner/one', openPrCount: 1),
      _activity('github:owner/two', openPrCount: 2),
    ], now: now);
    await MetricStore.capture([
      _activity('github:owner/one', openPrCount: 3),
      _activity('github:owner/two', openPrCount: 4),
    ], now: now.add(const Duration(hours: 1)));
    await MetricStore.capture([
      _activity('github:owner/one', openPrCount: 5),
      _activity('github:owner/two', openPrCount: 6),
    ], now: now.add(const Duration(hours: 25)));

    final all = await MetricStore.all();
    expect(all.keys, {'github:owner/one', 'github:owner/two'});
    expect(all['github:owner/one'], hasLength(2));
    expect(all['github:owner/two'], hasLength(2));
    expect(all['github:owner/one']?.map((snapshot) => snapshot.openPrs), [
      1,
      5,
    ]);
    expect(all['github:owner/two']?.map((snapshot) => snapshot.openPrs), [
      2,
      6,
    ]);
  });

  test('capture trims history to maxPerRepo most recent snapshots', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final total = MetricStore.maxPerRepo + 5;

    for (var index = 0; index < total; index += 1) {
      await MetricStore.capture([
        _activity(
          'github:owner/repo',
          openPrCount: index,
          needsReviewCount: index,
          activityScore: index,
        ),
      ], now: now.add(Duration(hours: 25 * index)));
    }

    final history = await MetricStore.historyFor('github:owner/repo');
    expect(history, hasLength(MetricStore.maxPerRepo));
    expect(history.first.openPrs, total - MetricStore.maxPerRepo);
    expect(history.last.openPrs, total - 1);
  });

  test('capture skips activities with errors', () async {
    final now = DateTime.utc(2026, 1, 1, 12);

    await MetricStore.capture([
      _activity('github:owner/ok'),
      _activity('github:owner/error', error: 'failed'),
    ], now: now);

    final all = await MetricStore.all();
    expect(all.keys, {'github:owner/ok'});
  });

  test('seriesFor returns oldest to newest values for each metric', () async {
    final now = DateTime.utc(2026, 1, 1, 12);

    await MetricStore.capture([
      _activity(
        'github:owner/repo',
        openPrCount: 1,
        needsReviewCount: 2,
        activityScore: 3.5,
      ),
    ], now: now);
    await MetricStore.capture([
      _activity(
        'github:owner/repo',
        openPrCount: 4,
        needsReviewCount: 5,
        activityScore: 6.5,
      ),
    ], now: now.add(const Duration(hours: 25)));

    expect(
      await MetricStore.seriesFor('github:owner/repo', metric: 'openPrs'),
      [1, 4],
    );
    expect(
      await MetricStore.seriesFor('github:owner/repo', metric: 'needsReview'),
      [2, 5],
    );
    expect(await MetricStore.seriesFor('github:owner/repo'), [3.5, 6.5]);
  });

  test('removeRepo drops history for the given repo only', () async {
    final now = DateTime.utc(2026, 1, 1, 12);

    await MetricStore.capture([
      _activity('github:owner/one', openPrCount: 1),
      _activity('github:owner/two', openPrCount: 2),
    ], now: now);

    await MetricStore.removeRepo('github:owner/one');

    final all = await MetricStore.all();
    expect(all.keys, {'github:owner/two'});
    expect(await MetricStore.historyFor('github:owner/one'), isEmpty);
  });

  test('removeRepo is a no-op for unknown or blank keys', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await MetricStore.capture([_activity('github:owner/one')], now: now);

    await MetricStore.removeRepo('github:owner/missing');
    await MetricStore.removeRepo('  ');

    expect((await MetricStore.all()).keys, {'github:owner/one'});
  });

  test(
    'capture with restrictToMonitored skips repos no longer monitored',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      SharedPreferences.setMockInitialValues({
        'github_repos': [
          jsonEncode({'owner': 'owner', 'repoName': 'one'}),
        ],
      });

      // Simulates an in-flight fetch (computed before a repo was removed) trying
      // to re-insert history for a repo that is no longer monitored.
      await MetricStore.capture(
        [
          _activity('github:owner/one', openPrCount: 1),
          _activity('github:owner/gone', openPrCount: 2),
        ],
        now: now,
        restrictToMonitored: true,
      );

      final all = await MetricStore.all();
      expect(all.keys, {'github:owner/one'});
    },
  );

  test(
    'imports legacy metric_history from SharedPreferences on first use',
    () async {
      // Seed a pre-database history blob, then point the store at a fresh db so
      // the one-time migration runs against it.
      SharedPreferences.setMockInitialValues({
        'metric_history': jsonEncode({
          'github:owner/legacy': [
            {
              'at': DateTime.utc(2026, 1, 1).toIso8601String(),
              'openPrs': 2,
              'needsReview': 1,
              'activityScore': 3,
            },
            {
              'at': DateTime.utc(2026, 1, 2).toIso8601String(),
              'openPrs': 4,
              'needsReview': 0,
              'activityScore': 5,
            },
          ],
        }),
      });
      final legacyDb = AppDatabase.forExecutor(NativeDatabase.memory());
      MetricStore.debugUseDatabase(legacyDb);

      final history = await MetricStore.historyFor('github:owner/legacy');
      expect(history.map((snapshot) => snapshot.openPrs), [2, 4]);

      // The legacy blob is cleared once the import has committed.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('metric_history'), isNull);

      await legacyDb.close();
    },
  );

  test(
    're-running migration against the same db does not duplicate rows',
    () async {
      final legacy = jsonEncode({
        'github:owner/legacy': [
          {
            'at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'openPrs': 2,
            'needsReview': 1,
            'activityScore': 3,
          },
        ],
      });
      SharedPreferences.setMockInitialValues({'metric_history': legacy});
      final migDb = AppDatabase.forExecutor(NativeDatabase.memory());
      MetricStore.debugUseDatabase(migDb);
      expect(await MetricStore.historyFor('github:owner/legacy'), hasLength(1));

      // Simulate a later launch against the already-migrated db, even if the blob
      // somehow reappears: the in-DB marker must prevent a second import.
      SharedPreferences.setMockInitialValues({'metric_history': legacy});
      MetricStore.debugUseDatabase(migDb);
      expect(await MetricStore.historyFor('github:owner/legacy'), hasLength(1));

      await migDb.close();
    },
  );

  test(
    'malformed legacy metric_history is retained, not imported or deleted',
    () async {
      SharedPreferences.setMockInitialValues({'metric_history': 'not-json{'});
      final badDb = AppDatabase.forExecutor(NativeDatabase.memory());
      MetricStore.debugUseDatabase(badDb);

      expect(await MetricStore.all(), isEmpty);

      // The unparseable blob is preserved so it isn't silently discarded.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('metric_history'), 'not-json{');

      await badDb.close();
    },
  );
}

RepoActivity _activity(
  String repoKey, {
  int openPrCount = 1,
  int needsReviewCount = 2,
  num activityScore = 3,
  String? error,
}) {
  return RepoActivity(
    repoKey: repoKey,
    provider: 'github',
    displayName: repoKey,
    url: 'https://example.com/$repoKey',
    openPrCount: openPrCount,
    needsReviewCount: needsReviewCount,
    oldestOpenPrAgeDays: null,
    lastActivity: null,
    ciStatus: 'unknown',
    contributors: const <String>[],
    activityScore: activityScore,
    error: error,
  );
}
