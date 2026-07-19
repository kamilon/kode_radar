import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:kode_radar/sync_state_store.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    SyncStateStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('lastSuccess is null before any sync', () async {
    expect(await SyncStateStore.lastSuccess(SyncStateStore.feedScope), isNull);
  });

  test('markSuccess records and lastSuccess round-trips (UTC)', () async {
    final at = DateTime.utc(2026, 1, 2, 3, 4, 5);
    await SyncStateStore.markSuccess(SyncStateStore.feedScope, now: at);

    final got = await SyncStateStore.lastSuccess(SyncStateStore.feedScope);
    expect(got, at);
    expect(got!.isUtc, isTrue);
  });

  test('markSuccess upserts (updates the same scope in place)', () async {
    final t1 = DateTime.utc(2026, 1, 1);
    final t2 = DateTime.utc(2026, 1, 2);
    await SyncStateStore.markSuccess(SyncStateStore.attentionScope, now: t1);
    await SyncStateStore.markSuccess(SyncStateStore.attentionScope, now: t2);

    expect(await SyncStateStore.lastSuccess(SyncStateStore.attentionScope), t2);
  });

  test('scopes are independent', () async {
    final at = DateTime.utc(2026, 5, 5);
    await SyncStateStore.markSuccess(SyncStateStore.feedScope, now: at);

    expect(await SyncStateStore.lastSuccess(SyncStateStore.feedScope), at);
    expect(
      await SyncStateStore.lastSuccess(SyncStateStore.attentionScope),
      isNull,
    );
  });

  test('repoScope keys by repo and remove clears it', () async {
    final scope = SyncStateStore.repoScope('github:owner/name');
    await SyncStateStore.markSuccess(scope, now: DateTime.utc(2026, 1, 1));
    expect(await SyncStateStore.lastSuccess(scope), isNotNull);

    await SyncStateStore.remove(scope);
    expect(await SyncStateStore.lastSuccess(scope), isNull);
  });

  test('v4 -> v5 upgrade creates a working sync_state table', () async {
    // Set user_version = 4 so opening AppDatabase runs onUpgrade(4 -> 5) rather
    // than onCreate; the other tables aren't materialized because the v5 step
    // (sync_state) is independent of them.
    final native = sqlite3.openInMemory();
    native.execute('PRAGMA user_version = 4;');
    final upgraded = AppDatabase.forExecutor(
      NativeDatabase.opened(native, closeUnderlyingOnClose: true),
    );
    SyncStateStore.debugUseDatabase(upgraded);

    final at = DateTime.utc(2026, 7, 1);
    await SyncStateStore.markSuccess(SyncStateStore.feedScope, now: at);
    expect(await SyncStateStore.lastSuccess(SyncStateStore.feedScope), at);

    await upgraded.close();
  });
}
