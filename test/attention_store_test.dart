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
  DateTime? createdAt,
  bool isMine = false,
}) => AttentionItem(
  id: id,
  category: category,
  severity: severity,
  titleTemplate: title,
  subtitleTemplate: subtitle,
  repoDisplay: repoDisplay,
  url: url,
  ageDays: ageDays,
  createdAt: createdAt,
  isMine: isMine,
);

AttentionItem _error(String repoDisplay) => AttentionItem(
  id: 'error:$repoDisplay',
  category: AttentionStore.errorCategory,
  severity: 0,
  titleTemplate: 'Could not load',
  subtitleTemplate: repoDisplay,
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

  test('cached recomputes item age from createdAt at read time', () async {
    final created = DateTime.utc(2026, 1, 1);
    await AttentionStore.save([
      _item(
        id: 'a',
        repoDisplay: 'owner/one',
        // Age-token subtitle, as the service builds for review-requested items.
        subtitle: 'owner/one · Title · opened ${AttentionItem.ageToken} by me',
        ageDays: 2,
        createdAt: created,
      ),
    ]);

    // 10 days after creation: age advances and the displayed subtitle reflects
    // it, instead of freezing at the fetch-time value of 2.
    final ten = await AttentionStore.cached(
      now: created.add(const Duration(days: 10)),
    );
    expect(ten.single.ageDays, 10);
    expect(ten.single.subtitle, 'owner/one · Title · opened 10 days by me');

    // 40 days after creation, still without a re-save.
    final forty = await AttentionStore.cached(
      now: created.add(const Duration(days: 40)),
    );
    expect(forty.single.ageDays, 40);
    expect(forty.single.subtitle, contains('opened 40 days'));
  });

  test(
    'cached falls back to stored ageDays when createdAt is absent',
    () async {
      await AttentionStore.save([
        _item(id: 'a', repoDisplay: 'owner/one', ageDays: 7),
      ]);
      final cached = await AttentionStore.cached(now: DateTime.utc(2030));
      expect(cached.single.ageDays, 7);
    },
  );

  test('cached re-ranks by the recomputed age within a category', () async {
    final now = DateTime.utc(2026, 2, 1);
    await AttentionStore.save([
      // Fetched long ago at age 2 (severity 3002) but now 20 days old.
      _item(
        id: 'old',
        repoDisplay: 'owner/one',
        severity: 3002,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      // Fetched recently at age 5 (severity 3005), still 5 days old.
      _item(
        id: 'new',
        repoDisplay: 'owner/two',
        severity: 3005,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ]);
    final ranked = await AttentionStore.cached(now: now);
    // 'old' (now 20 days) outranks 'new' (5 days) despite its lower *stored*
    // severity, because severity is recomputed from the fresh age on read.
    expect(ranked.map((e) => e.id).toList(), ['old', 'new']);
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

  test('watch emits the ranked cache and re-emits after a save', () async {
    final emissions = <List<String>>[];
    final sub = AttentionStore.watch().listen((items) {
      emissions.add(items.map((e) => e.id).toList());
    });
    // Initial emission (empty cache).
    await pumpEventQueue();
    await AttentionStore.save([
      _item(id: 'a', repoDisplay: 'owner/one', severity: 3000),
      _item(id: 'b', repoDisplay: 'owner/two', severity: 5000),
    ]);
    await pumpEventQueue();
    await sub.cancel();

    expect(emissions.first, isEmpty);
    // Ranked most-urgent first (severity desc): b (5000) before a (3000).
    expect(emissions.last, ['b', 'a']);
  });

  test('watch is not snooze-filtered (the page applies snooze)', () async {
    await AttentionStore.save([
      _item(id: 'a', repoDisplay: 'owner/one'),
      _item(id: 'b', repoDisplay: 'owner/two'),
    ]);
    final items = await AttentionStore.watch().first;
    expect(items.map((e) => e.id).toSet(), {'a', 'b'});
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

  test('v7 -> v8 upgrade adds created_at and recomputes age', () async {
    // Materialize the pre-v8 attention_items schema (no created_at) at
    // user_version = 7, so opening AppDatabase runs the v8 ALTER ADD COLUMN.
    final native = sqlite3.openInMemory();
    native.execute('''
      CREATE TABLE attention_items (
        id TEXT NOT NULL PRIMARY KEY,
        category TEXT NOT NULL,
        severity INTEGER NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        repo_display TEXT NOT NULL,
        url TEXT,
        age_days INTEGER,
        is_mine INTEGER NOT NULL
      );
    ''');
    native.execute('PRAGMA user_version = 7;');
    final upgraded = AppDatabase.forExecutor(
      NativeDatabase.opened(native, closeUnderlyingOnClose: true),
    );
    AttentionStore.debugUseDatabase(upgraded);

    final created = DateTime.utc(2026, 1, 1);
    await AttentionStore.save([
      _item(
        id: 'a',
        repoDisplay: 'owner/one',
        subtitle: 'owner/one · T · opened ${AttentionItem.ageToken} by me',
        createdAt: created,
      ),
    ]);
    // The new created_at column persisted, so age recomputes on read.
    final cached = await AttentionStore.cached(
      now: created.add(const Duration(days: 5)),
    );
    expect(cached.single.ageDays, 5);
    expect(cached.single.subtitle, contains('opened 5 days'));

    await upgraded.close();
  });
}
