import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:kode_radar/repo_detail_service.dart';
import 'package:kode_radar/repo_detail_store.dart';
import 'package:sqlite3/sqlite3.dart';

RepoPr _pr(String label, {String reviewState = 'waiting'}) => RepoPr(
  label: label,
  title: 'title $label',
  author: 'octocat',
  reviewState: reviewState,
  ageDays: 3,
  url: 'https://example.com/$label',
);

RepoRun _run(String name, {String conclusion = 'success'}) => RepoRun(
  name: name,
  status: 'completed',
  conclusion: conclusion,
  branch: 'main',
  finishedAt: DateTime.utc(2026, 1, 2, 3, 4),
  url: 'https://example.com/run/$name',
);

RepoRelease _release(String tag) => RepoRelease(
  tag: tag,
  name: 'Release $tag',
  author: 'octocat',
  publishedAt: DateTime.utc(2026, 1, 1),
  url: 'https://example.com/rel/$tag',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const repo = 'github:owner/name';

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    RepoDetailStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'save then cached round-trips pulls, CI and releases in order',
    () async {
      await RepoDetailStore.save(
        repo,
        RepoDetailData(
          pulls: [
            _pr('PR #1'),
            _pr('PR #2', reviewState: 'approved'),
          ],
          ci: [_run('build')],
          releases: [_release('v1.0'), _release('v0.9')],
        ),
      );

      final cached = await RepoDetailStore.cached(
        repo,
        releasesSupported: true,
      );
      expect(cached.pulls.map((p) => p.label).toList(), ['PR #1', 'PR #2']);
      expect(cached.pulls[1].reviewState, 'approved');
      expect(cached.ci.single.name, 'build');
      expect(cached.ci.single.finishedAt, DateTime.utc(2026, 1, 2, 3, 4));
      expect(cached.releases.map((r) => r.tag).toList(), ['v1.0', 'v0.9']);
      // Failure flags are always false for a cache read.
      expect(cached.failedSources, 0);
    },
  );

  test('cached is scoped to the requested repo', () async {
    await RepoDetailStore.save(repo, RepoDetailData(pulls: [_pr('PR #1')]));
    await RepoDetailStore.save(
      'github:other/repo',
      RepoDetailData(pulls: [_pr('PR #9')]),
    );

    final cached = await RepoDetailStore.cached(repo, releasesSupported: true);
    expect(cached.pulls.map((p) => p.label).toList(), ['PR #1']);
  });

  test('a successful source replaces its cached rows', () async {
    await RepoDetailStore.save(repo, RepoDetailData(pulls: [_pr('PR #1')]));
    await RepoDetailStore.save(repo, RepoDetailData(pulls: [_pr('PR #2')]));

    final cached = await RepoDetailStore.cached(repo, releasesSupported: true);
    expect(cached.pulls.map((p) => p.label).toList(), ['PR #2']);
  });

  test('a failed source keeps its last-known-good rows', () async {
    await RepoDetailStore.save(
      repo,
      RepoDetailData(pulls: [_pr('PR #1')], ci: [_run('build')]),
    );
    // Next refresh: pulls succeed (updated), CI failed (should retain).
    await RepoDetailStore.save(
      repo,
      RepoDetailData(pulls: [_pr('PR #2')], ci: const [], ciFailed: true),
    );

    final cached = await RepoDetailStore.cached(repo, releasesSupported: true);
    expect(cached.pulls.map((p) => p.label).toList(), ['PR #2']);
    // CI retained from the prior successful load.
    expect(cached.ci.map((r) => r.name).toList(), ['build']);
  });

  test('releases are untouched for providers without releases support', () async {
    // A GitHub-cached release, then an ADO-style save (releasesSupported: false)
    // must not wipe the cached releases.
    await RepoDetailStore.save(
      repo,
      RepoDetailData(releases: [_release('v1')]),
    );
    await RepoDetailStore.save(
      repo,
      const RepoDetailData(releasesSupported: false),
    );

    final cached = await RepoDetailStore.cached(repo, releasesSupported: true);
    expect(cached.releases.map((r) => r.tag).toList(), ['v1']);
  });

  test('removeRepo drops all detail for the repo only', () async {
    await RepoDetailStore.save(
      repo,
      RepoDetailData(
        pulls: [_pr('PR #1')],
        ci: [_run('build')],
        releases: [_release('v1')],
      ),
    );
    await RepoDetailStore.save(
      'github:other/repo',
      RepoDetailData(pulls: [_pr('PR #9')]),
    );

    await RepoDetailStore.removeRepo(repo);

    final gone = await RepoDetailStore.cached(repo, releasesSupported: true);
    expect(gone.pulls, isEmpty);
    expect(gone.ci, isEmpty);
    expect(gone.releases, isEmpty);
    final other = await RepoDetailStore.cached(
      'github:other/repo',
      releasesSupported: true,
    );
    expect(other.pulls.map((p) => p.label).toList(), ['PR #9']);
  });

  test('v3 -> v4 upgrade creates working repo-detail tables', () async {
    // Set user_version = 3 so opening AppDatabase runs onUpgrade(3 -> 4) rather
    // than onCreate; the other tables aren't materialized because the v4 step
    // (repo-detail tables) is independent of them.
    final native = sqlite3.openInMemory();
    native.execute('PRAGMA user_version = 3;');
    final upgraded = AppDatabase.forExecutor(
      NativeDatabase.opened(native, closeUnderlyingOnClose: true),
    );
    RepoDetailStore.debugUseDatabase(upgraded);

    await RepoDetailStore.save(repo, RepoDetailData(pulls: [_pr('PR #1')]));
    final cached = await RepoDetailStore.cached(repo, releasesSupported: true);
    expect(cached.pulls.map((p) => p.label).toList(), ['PR #1']);

    await upgraded.close();
  });
}
