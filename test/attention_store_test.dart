import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/attention_service.dart';
import 'package:kode_radar/attention_store.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

AttentionItem _item({
  required String id,
  required String repoDisplay,
  String category = 'reviewRequested',
  int severity = 3000,
  String title = 'PR #1',
  String subtitle = 'subtitle',
  String? url = 'https://example.com/1',
  int? ageDays = 2,
  bool isMine = false,
}) => AttentionItem(
  id: id,
  category: category,
  severity: severity,
  title: title,
  subtitle: subtitle,
  repoDisplay: repoDisplay,
  url: url,
  ageDays: ageDays,
  isMine: isMine,
);

AttentionItem _error(String repoDisplay) => AttentionItem(
  id: 'error:$repoDisplay',
  category: AttentionStore.errorCategory,
  severity: 0,
  title: 'Could not load',
  subtitle: repoDisplay,
  repoDisplay: repoDisplay,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    AttentionStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('save persists non-error items and never stores error items', () async {
    await AttentionStore.save([
      _item(id: 'a', repoDisplay: 'owner/one', severity: 3002),
      _item(id: 'b', repoDisplay: 'owner/two', severity: 2001),
      _error('owner/three'),
    ]);

    final cached = await AttentionStore.cached();
    // Ranked by severity desc; error item not stored.
    expect(cached.map((e) => e.id).toList(), ['a', 'b']);
    expect(
      cached.any((e) => e.category == AttentionStore.errorCategory),
      isFalse,
    );
    // Fields round-trip.
    expect(cached.first.repoDisplay, 'owner/one');
    expect(cached.first.ageDays, 2);
  });

  test('cached breaks severity+repo ties deterministically by id', () async {
    await AttentionStore.save([
      _item(id: 'z', repoDisplay: 'owner/one', severity: 3000),
      _item(id: 'a', repoDisplay: 'owner/one', severity: 3000),
      _item(id: 'm', repoDisplay: 'owner/one', severity: 3000),
    ]);

    final cached = await AttentionStore.cached();
    expect(cached.map((e) => e.id).toList(), ['a', 'm', 'z']);
  });

  test('cached filters out snoozed ids on read', () async {
    await AttentionStore.save([
      _item(id: 'a', repoDisplay: 'owner/one'),
      _item(id: 'b', repoDisplay: 'owner/two'),
    ]);

    final cached = await AttentionStore.cached(snoozedIds: {'a'});
    expect(cached.map((e) => e.id).toList(), ['b']);
  });

  test('a successful refresh replaces a repo\'s items', () async {
    await AttentionStore.save([
      _item(id: 'old', repoDisplay: 'owner/one', title: 'old'),
    ]);
    // Same repo fetched successfully again, different item.
    await AttentionStore.save([
      _item(id: 'new', repoDisplay: 'owner/one', title: 'new'),
    ]);

    final cached = await AttentionStore.cached();
    expect(cached.map((e) => e.id).toList(), ['new']);
  });

  test('a repo that is now clean drops its cached items', () async {
    await AttentionStore.save([
      _item(id: 'a', repoDisplay: 'owner/one'),
      _item(id: 'b', repoDisplay: 'owner/two'),
    ]);
    // owner/one is now clean (no items, no error) while owner/two still has one.
    await AttentionStore.save([_item(id: 'b', repoDisplay: 'owner/two')]);

    final cached = await AttentionStore.cached();
    expect(cached.map((e) => e.id).toList(), ['b']);
  });

  test('items for a repo that errored this round are retained', () async {
    await AttentionStore.save([
      _item(id: 'a', repoDisplay: 'owner/one', severity: 3000),
      _item(id: 'b', repoDisplay: 'owner/two', severity: 2000),
    ]);
    // owner/one errors this round; owner/two succeeds with an updated item.
    await AttentionStore.save([
      _error('owner/one'),
      _item(id: 'b2', repoDisplay: 'owner/two', severity: 2500),
    ]);

    final cached = await AttentionStore.cached();
    // owner/one's cached 'a' is kept; owner/two replaced 'b' -> 'b2'.
    expect(cached.map((e) => e.id).toSet(), {'a', 'b2'});
  });

  test(
    'a fully offline refresh (all errors) keeps the prior snapshot',
    () async {
      await AttentionStore.save([
        _item(id: 'a', repoDisplay: 'owner/one'),
        _item(id: 'b', repoDisplay: 'owner/two'),
      ]);
      await AttentionStore.save([_error('owner/one'), _error('owner/two')]);

      final cached = await AttentionStore.cached();
      expect(cached.map((e) => e.id).toSet(), {'a', 'b'});
    },
  );

  test(
    'a repo no longer fetched (removed) self-heals out of the cache',
    () async {
      await AttentionStore.save([
        _item(id: 'a', repoDisplay: 'owner/one'),
        _item(id: 'gone', repoDisplay: 'owner/removed'),
      ]);
      // Next refresh only fetches owner/one (owner/removed was unmonitored).
      await AttentionStore.save([_item(id: 'a', repoDisplay: 'owner/one')]);

      final cached = await AttentionStore.cached();
      expect(cached.map((e) => e.repoDisplay).toSet(), {'owner/one'});
    },
  );

  test('v2 -> v3 upgrade creates a working attention_items table', () async {
    // Set user_version = 2 so opening AppDatabase runs onUpgrade(2 -> 3) rather
    // than onCreate. We don't materialize the other v2 tables because this test
    // only exercises the v3 step (creating attention_items), which is
    // independent of them.
    final native = sqlite3.openInMemory();
    native.execute('PRAGMA user_version = 2;');
    final upgraded = AppDatabase.forExecutor(
      NativeDatabase.opened(native, closeUnderlyingOnClose: true),
    );
    AttentionStore.debugUseDatabase(upgraded);

    await AttentionStore.save([_item(id: 'a', repoDisplay: 'owner/one')]);
    final cached = await AttentionStore.cached();
    expect(cached.map((e) => e.id).toList(), ['a']);

    await upgraded.close();
  });
}
