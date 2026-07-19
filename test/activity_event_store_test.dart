import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/activity_event.dart';
import 'package:kode_radar/activity_event_store.dart';
import 'package:kode_radar/activity_feed_service.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

ActivityEvent _event({
  required String id,
  required String repoKey,
  required DateTime occurredAt,
  String type = ActivityType.prOpened,
  String provider = 'github',
  String repoDisplay = 'owner/name',
  String actor = 'octocat',
  String title = 'PR title',
  String subtitle = 'subtitle',
  String? url = 'https://example.com/1',
  bool isMine = false,
}) => ActivityEvent(
  id: id,
  type: type,
  provider: provider,
  repoKey: repoKey,
  repoDisplay: repoDisplay,
  actor: actor,
  title: title,
  subtitle: subtitle,
  occurredAt: occurredAt,
  url: url,
  isMine: isMine,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime.utc(2026, 1, 15, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    ActivityEventStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('save then cached round-trips events newest-first', () async {
    await ActivityEventStore.save([
      _event(
        id: 'a',
        repoKey: 'github:owner/name',
        occurredAt: now.subtract(const Duration(hours: 2)),
      ),
      _event(
        id: 'b',
        repoKey: 'github:owner/name',
        occurredAt: now.subtract(const Duration(hours: 1)),
        isMine: true,
        url: null,
      ),
    ], now: now);

    final cached = await ActivityEventStore.cached(now: now);
    expect(cached.map((e) => e.id).toList(), ['b', 'a']);
    // Fields survive the round-trip.
    expect(cached.first.isMine, isTrue);
    expect(cached.first.url, isNull);
    expect(cached.last.repoDisplay, 'owner/name');
    expect(cached.first.occurredAt.isUtc, isTrue);
  });

  test(
    're-saving the same (repoKey, eventId) upserts instead of duplicating',
    () async {
      await ActivityEventStore.save([
        _event(
          id: 'a',
          repoKey: 'github:owner/name',
          occurredAt: now.subtract(const Duration(hours: 3)),
          title: 'old title',
        ),
      ], now: now);
      await ActivityEventStore.save([
        _event(
          id: 'a',
          repoKey: 'github:owner/name',
          occurredAt: now.subtract(const Duration(hours: 3)),
          title: 'new title',
        ),
      ], now: now);

      final cached = await ActivityEventStore.cached(now: now);
      expect(cached, hasLength(1));
      expect(cached.single.title, 'new title');
    },
  );

  test('same eventId in different repos are kept separately', () async {
    await ActivityEventStore.save([
      _event(id: '1', repoKey: 'github:a/a', occurredAt: now),
      _event(id: '1', repoKey: 'github:b/b', occurredAt: now),
    ], now: now);

    final cached = await ActivityEventStore.cached(now: now);
    expect(cached, hasLength(2));
    expect(cached.map((e) => e.repoKey).toSet(), {'github:a/a', 'github:b/b'});
  });

  test('save prunes events older than the retention horizon', () async {
    await ActivityEventStore.save([
      _event(
        id: 'fresh',
        repoKey: 'github:owner/name',
        occurredAt: now.subtract(const Duration(days: 2)),
      ),
      _event(
        id: 'stale',
        repoKey: 'github:owner/name',
        // Older than ActivityEventStore.maxRetention (60 days).
        occurredAt: now.subtract(const Duration(days: 70)),
      ),
    ], now: now);

    // Read with a wide window so only the retention prune (not the read filter)
    // can drop the stale event.
    final cached = await ActivityEventStore.cached(
      lookback: const Duration(days: 365),
      now: now,
    );
    expect(cached.map((e) => e.id).toList(), ['fresh']);
  });

  test('retention keeps events beyond the display lookback', () async {
    await ActivityEventStore.save([
      _event(
        id: 'recent',
        repoKey: 'github:owner/name',
        occurredAt: now.subtract(const Duration(days: 3)),
      ),
      _event(
        id: 'old',
        repoKey: 'github:owner/name',
        occurredAt: now.subtract(const Duration(days: 40)),
      ),
    ], now: now);

    // A narrow display window hides the 40-day event...
    expect(
      (await ActivityEventStore.cached(
        lookback: const Duration(days: 7),
        now: now,
      )).map((e) => e.id).toList(),
      ['recent'],
    );
    // ...but it is still retained on disk, so a wider window recovers it (the
    // write-side prune uses maxRetention, not the display lookback).
    expect(
      (await ActivityEventStore.cached(
        lookback: const Duration(days: 60),
        now: now,
      )).map((e) => e.id).toList(),
      ['recent', 'old'],
    );
  });

  test('cached honors the lookback window on read', () async {
    await ActivityEventStore.save([
      _event(
        id: 'recent',
        repoKey: 'github:owner/name',
        occurredAt: now.subtract(const Duration(days: 3)),
      ),
      _event(
        id: 'older',
        repoKey: 'github:owner/name',
        occurredAt: now.subtract(const Duration(days: 10)),
      ),
    ], now: now);

    final cached = await ActivityEventStore.cached(
      lookback: const Duration(days: 7),
      now: now,
    );
    expect(cached.map((e) => e.id).toList(), ['recent']);
  });

  test(
    'save with restrictToMonitored skips and purges unmonitored repos',
    () async {
      // A previously-cached event for a repo that is about to be unmonitored.
      await ActivityEventStore.save([
        _event(id: 'gone', repoKey: 'github:owner/gone', occurredAt: now),
      ], now: now);

      SharedPreferences.setMockInitialValues({
        'github_repos': [
          jsonEncode({'owner': 'owner', 'repoName': 'kept'}),
        ],
      });

      // Simulates an in-flight fetch (computed before 'gone' was removed) trying
      // to re-insert its events alongside the still-monitored repo's.
      await ActivityEventStore.save(
        [
          _event(id: 'kept', repoKey: 'github:owner/kept', occurredAt: now),
          _event(id: 'gone2', repoKey: 'github:owner/gone', occurredAt: now),
        ],
        now: now,
        restrictToMonitored: true,
      );

      final cached = await ActivityEventStore.cached(now: now);
      expect(cached.map((e) => e.repoKey).toSet(), {'github:owner/kept'});
    },
  );

  test(
    'restrictToMonitored purges all rows when nothing is monitored',
    () async {
      await ActivityEventStore.save([
        _event(id: 'a', repoKey: 'github:owner/one', occurredAt: now),
        _event(id: 'b', repoKey: 'github:owner/two', occurredAt: now),
      ], now: now);

      // No monitored repos in prefs -> the cache should be fully purged.
      SharedPreferences.setMockInitialValues({});
      await ActivityEventStore.save(
        const [],
        now: now,
        restrictToMonitored: true,
      );

      expect(await ActivityEventStore.cached(now: now), isEmpty);
    },
  );

  test('save trims the cache to maxEvents newest rows', () async {
    final many = [
      for (var i = 0; i < ActivityFeedService.maxEvents + 25; i++)
        _event(
          id: 'e$i',
          repoKey: 'github:owner/name',
          occurredAt: now.subtract(Duration(minutes: i)),
        ),
    ];
    await ActivityEventStore.save(many, now: now);

    final cached = await ActivityEventStore.cached(now: now);
    expect(cached, hasLength(ActivityFeedService.maxEvents));
    // Newest kept, oldest evicted.
    expect(cached.first.id, 'e0');
    expect(
      cached.any((e) => e.id == 'e${ActivityFeedService.maxEvents + 24}'),
      isFalse,
    );
  });

  test('cached(repoKey:) returns only that repo\'s events', () async {
    await ActivityEventStore.save([
      _event(id: '1', repoKey: 'github:a/a', occurredAt: now),
      _event(id: '2', repoKey: 'github:b/b', occurredAt: now),
      _event(
        id: '3',
        repoKey: 'github:a/a',
        occurredAt: now.subtract(const Duration(hours: 1)),
      ),
    ], now: now);

    final cached = await ActivityEventStore.cached(
      repoKey: 'github:a/a',
      now: now,
    );
    expect(cached.map((e) => e.id).toList(), ['1', '3']);
  });

  test('removeRepo drops only the given repo', () async {
    await ActivityEventStore.save([
      _event(id: '1', repoKey: 'github:a/a', occurredAt: now),
      _event(id: '2', repoKey: 'github:b/b', occurredAt: now),
    ], now: now);

    await ActivityEventStore.removeRepo('github:a/a');

    final cached = await ActivityEventStore.cached(now: now);
    expect(cached.map((e) => e.repoKey).toList(), ['github:b/b']);
  });

  test(
    'v1 -> v2 upgrade creates activity_events with a working unique index',
    () async {
      // Build a database that looks like the Phase-1 (v1) schema: no
      // activity_events table and user_version = 1, so opening AppDatabase over
      // it runs onUpgrade(1 -> 2) rather than onCreate.
      final native = sqlite3.openInMemory();
      native.execute('PRAGMA user_version = 1;');
      final upgraded = AppDatabase.forExecutor(
        NativeDatabase.opened(native, closeUnderlyingOnClose: true),
      );
      ActivityEventStore.debugUseDatabase(upgraded);

      // Same (repoKey, eventId) twice: only works without duplicating if the
      // UNIQUE (repo_key, event_id) index was created by the migration (the
      // upsert's conflict target requires it).
      await ActivityEventStore.save([
        _event(id: 'x', repoKey: 'github:owner/name', occurredAt: now),
      ], now: now);
      await ActivityEventStore.save([
        _event(
          id: 'x',
          repoKey: 'github:owner/name',
          occurredAt: now,
          title: 'updated',
        ),
      ], now: now);

      final cached = await ActivityEventStore.cached(now: now);
      expect(cached, hasLength(1));
      expect(cached.single.title, 'updated');
      await upgraded.close();
    },
  );
}
