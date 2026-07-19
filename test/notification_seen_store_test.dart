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
}
