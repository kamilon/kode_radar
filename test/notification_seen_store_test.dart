import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:kode_radar/notification_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    NotificationSeenStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('starts unseeded and empty', () async {
    expect(await NotificationSeenStore.isSeeded(), isFalse);
    expect(await NotificationSeenStore.seenIds(), isEmpty);
    expect(await NotificationSeenStore.knownRepos(), isEmpty);
  });

  test('recordBaseline seeds and unions ids/repos additively', () async {
    await NotificationSeenStore.recordBaseline({'a', 'b'}, {'owner/one'});
    expect(await NotificationSeenStore.isSeeded(), isTrue);
    expect(await NotificationSeenStore.seenIds(), {'a', 'b'});
    expect(await NotificationSeenStore.knownRepos(), {'owner/one'});

    // A second record unions rather than overwrites (simulating a concurrent
    // isolate's snapshot).
    await NotificationSeenStore.recordBaseline({'b', 'c'}, {'owner/two'});
    expect(await NotificationSeenStore.seenIds(), {'a', 'b', 'c'});
    expect(await NotificationSeenStore.knownRepos(), {
      'owner/one',
      'owner/two',
    });
  });

  test('recordBaseline prunes the seen set to the newest maxSeenIds', () async {
    final many = {
      for (var i = 0; i < NotificationSeenStore.maxSeenIds + 50; i++) 'id$i',
    };
    await NotificationSeenStore.recordBaseline(many, const {});
    final seen = await NotificationSeenStore.seenIds();
    expect(seen.length, NotificationSeenStore.maxSeenIds);
    // Newest ids kept; oldest evicted.
    expect(seen.contains('id${NotificationSeenStore.maxSeenIds + 49}'), isTrue);
    expect(seen.contains('id0'), isFalse);
  });

  test('a re-seen id is bumped so it survives pruning', () async {
    await NotificationSeenStore.recordBaseline({'keep'}, const {});
    // Fill past the cap while ALSO re-seeing 'keep', which bumps it to newest.
    final fresh = {
      for (var i = 0; i <= NotificationSeenStore.maxSeenIds; i++) 'n$i',
    };
    await NotificationSeenStore.recordBaseline({...fresh, 'keep'}, const {});

    final seen = await NotificationSeenStore.seenIds();
    expect(seen.length, NotificationSeenStore.maxSeenIds);
    // 'keep' was re-seen this round, so it wasn't evicted as "oldest".
    expect(seen.contains('keep'), isTrue);
  });

  test('imports a legacy SharedPreferences baseline once', () async {
    SharedPreferences.setMockInitialValues({
      'seen_attention': ['x', 'y'],
      'known_attention_repos': ['owner/legacy'],
    });
    // Fresh db + store so the one-time import runs against it.
    final freshDb = AppDatabase.forExecutor(NativeDatabase.memory());
    NotificationSeenStore.debugUseDatabase(freshDb);

    expect(await NotificationSeenStore.isSeeded(), isTrue);
    expect(await NotificationSeenStore.seenIds(), {'x', 'y'});
    expect(await NotificationSeenStore.knownRepos(), {'owner/legacy'});
    // Legacy keys cleared after import.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('seen_attention'), isFalse);

    await freshDb.close();
  });

  test('a fresh install (no legacy baseline) stays unseeded', () async {
    // No legacy keys set; import runs but establishes no baseline.
    expect(await NotificationSeenStore.isSeeded(), isFalse);
    expect(await NotificationSeenStore.seenIds(), isEmpty);
  });

  test('v6 -> v7 upgrade creates the notification-seen tables', () async {
    // Set user_version = 6 so opening AppDatabase runs onUpgrade(6 -> 7). Create
    // app_meta (an original table the store reads; present in any real upgrade).
    final native = sqlite3.openInMemory();
    native.execute(
      'CREATE TABLE app_meta (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
    );
    native.execute('PRAGMA user_version = 6;');
    final upgraded = AppDatabase.forExecutor(
      NativeDatabase.opened(native, closeUnderlyingOnClose: true),
    );
    NotificationSeenStore.debugUseDatabase(upgraded);

    await NotificationSeenStore.recordBaseline({'a'}, {'owner/one'});
    expect(await NotificationSeenStore.seenIds(), {'a'});

    await upgraded.close();
  });

  test('claimDailyDigest is once-per-day and release allows a retry', () async {
    // First claim for a date wins; a second (e.g. the other isolate) loses.
    expect(await NotificationSeenStore.claimDailyDigest('2026-7-23'), isTrue);
    expect(await NotificationSeenStore.claimDailyDigest('2026-7-23'), isFalse);
    // Releasing the ACTIVE claim (e.g. after a failed show) lets the SAME day
    // be re-claimed so a later sync retries.
    await NotificationSeenStore.releaseDailyDigest('2026-7-23');
    expect(await NotificationSeenStore.claimDailyDigest('2026-7-23'), isTrue);
    // A different date is its own claim.
    expect(await NotificationSeenStore.claimDailyDigest('2026-7-24'), isTrue);
    // A stale release (the marker has moved on) is a no-op — today stays held.
    await NotificationSeenStore.releaseDailyDigest('2026-7-23');
    expect(await NotificationSeenStore.claimDailyDigest('2026-7-24'), isFalse);
  });

  group('claimNewRegressionKeys', () {
    test('returns only newly-seen keys within a period', () async {
      final first = await NotificationSeenStore.claimNewRegressionKeys({
        'w7-1|t1|mergeTimeUp',
        'w7-1|t2|reviewLatencyUp',
      }, 'w7-1');
      expect(first, {'w7-1|t1|mergeTimeUp', 'w7-1|t2|reviewLatencyUp'});
      // Re-seeing the same standing regressions plus a new one: only the new
      // one is returned (the others already alerted this period).
      final second = await NotificationSeenStore.claimNewRegressionKeys({
        'w7-1|t1|mergeTimeUp',
        'w7-1|t2|reviewLatencyUp',
        'w7-1|t3|ciFailureRateUp',
      }, 'w7-1');
      expect(second, {'w7-1|t3|ciFailureRateUp'});
    });

    test(
      'a new period re-alerts a standing regression and prunes old',
      () async {
        await NotificationSeenStore.claimNewRegressionKeys({
          'w7-1|t1|mergeTimeUp',
        }, 'w7-1');
        // Next period: the same regression (new period key) alerts again.
        final next = await NotificationSeenStore.claimNewRegressionKeys({
          'w7-2|t1|mergeTimeUp',
        }, 'w7-2');
        expect(next, {'w7-2|t1|mergeTimeUp'});
        // The old period's key was pruned, so returning to it (unlikely) would
        // alert once more — and importantly it's no longer stored.
        final backAgain = await NotificationSeenStore.claimNewRegressionKeys({
          'w7-2|t1|mergeTimeUp',
        }, 'w7-2');
        expect(backAgain, isEmpty, reason: 'still standing in the same period');
      },
    );

    test('empty current keys is a no-op returning nothing', () async {
      expect(
        await NotificationSeenStore.claimNewRegressionKeys({}, 'w7-9'),
        isEmpty,
      );
    });

    test('releaseRegressionKeys lets a claimed key re-fire', () async {
      await NotificationSeenStore.claimNewRegressionKeys({
        'w7-1|t1|mergeTimeUp',
      }, 'w7-1');
      // Released (e.g. after a failed show) → the same key is fresh again.
      await NotificationSeenStore.releaseRegressionKeys({
        'w7-1|t1|mergeTimeUp',
      });
      final again = await NotificationSeenStore.claimNewRegressionKeys({
        'w7-1|t1|mergeTimeUp',
      }, 'w7-1');
      expect(again, {'w7-1|t1|mergeTimeUp'});
    });
  });
}
