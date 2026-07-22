import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/ci_run_history.dart';
import 'package:kode_radar/ci_run_history_store.dart';
import 'package:kode_radar/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

CiRunSample _sample(
  String workflow, {
  required String runKey,
  String outcome = CiOutcome.success,
  String repoKey = 'github:owner/name',
  String repoDisplay = 'owner/name',
  String conclusion = 'success',
  String? workflowId,
  DateTime? finishedAt,
  String? url,
}) => CiRunSample(
  provider: 'github',
  repoKey: repoKey,
  repoDisplay: repoDisplay,
  workflow: workflow,
  workflowId: workflowId,
  runKey: runKey,
  outcome: outcome,
  conclusion: conclusion,
  finishedAt: finishedAt ?? DateTime.utc(2026, 1, 10),
  url: url ?? 'https://example.com/$runKey',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    CiRunHistoryStore.debugUseDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'record de-duplicates by runKey (re-seen run does not double-count)',
    () async {
      final now = DateTime.utc(2026, 1, 11);
      await CiRunHistoryStore.record([
        _sample(
          'build',
          runKey: 'github:owner/name:1',
          outcome: CiOutcome.failure,
        ),
        _sample(
          'build',
          runKey: 'github:owner/name:2',
          outcome: CiOutcome.success,
        ),
      ], now: now);
      // A later sync re-sees run 1 (same runKey) plus a new run 3.
      await CiRunHistoryStore.record([
        _sample(
          'build',
          runKey: 'github:owner/name:1',
          outcome: CiOutcome.failure,
        ),
        _sample(
          'build',
          runKey: 'github:owner/name:3',
          outcome: CiOutcome.success,
        ),
      ], now: now);

      final trends = await CiRunHistoryStore.trends(now: now);
      expect(trends, hasLength(1));
      // 3 distinct runs: 1 failure + 2 successes (not 4).
      expect(trends.single.total, 3);
      expect(trends.single.failures, 1);
      expect(trends.single.successes, 2);
    },
  );

  test('record skips samples without a runKey', () async {
    final now = DateTime.utc(2026, 1, 11);
    await CiRunHistoryStore.record([
      _sample('build', runKey: ''),
      _sample('build', runKey: 'github:owner/name:9'),
    ], now: now);
    final trends = await CiRunHistoryStore.trends(now: now);
    expect(trends.single.total, 1);
  });

  test('record skips still-running and finish-time-less runs', () async {
    final now = DateTime.utc(2026, 1, 11);
    await CiRunHistoryStore.record([
      _sample(
        'build',
        runKey: 'github:owner/name:r',
        outcome: CiOutcome.running,
      ),
      CiRunSample(
        provider: 'github',
        repoKey: 'github:owner/name',
        repoDisplay: 'owner/name',
        workflow: 'build',
        runKey: 'github:owner/name:nofinish',
        outcome: CiOutcome.success,
        conclusion: 'success',
        finishedAt: null,
      ),
      _sample('build', runKey: 'github:owner/name:ok'),
    ], now: now);
    final trends = await CiRunHistoryStore.trends(now: now);
    expect(
      trends.single.total,
      1,
      reason: 'only the completed, finished run is kept',
    );
  });

  test('age prune drops runs older than the retention window', () async {
    final now = DateTime.utc(2026, 6, 1);
    await CiRunHistoryStore.record([
      _sample(
        'build',
        runKey: 'github:owner/name:old',
        finishedAt: now.subtract(const Duration(days: 100)),
      ),
      _sample(
        'build',
        runKey: 'github:owner/name:fresh',
        finishedAt: now.subtract(const Duration(days: 1)),
      ),
    ], now: now);
    final trends = await CiRunHistoryStore.trends(
      now: now,
      window: const Duration(days: 365),
    );
    expect(trends.single.total, 1, reason: 'the 100-day-old run is pruned');
  });

  test('removeRepo drops only that repo history', () async {
    final now = DateTime.utc(2026, 1, 11);
    await CiRunHistoryStore.record([
      _sample(
        'build',
        runKey: 'github:owner/a:1',
        repoKey: 'github:owner/a',
        repoDisplay: 'owner/a',
      ),
      _sample(
        'build',
        runKey: 'github:owner/b:1',
        repoKey: 'github:owner/b',
        repoDisplay: 'owner/b',
      ),
    ], now: now);
    await CiRunHistoryStore.removeRepo('github:owner/a');
    final trends = await CiRunHistoryStore.trends(now: now);
    expect(trends, hasLength(1));
    expect(trends.single.repoKey, 'github:owner/b');
  });

  test('persists workflowId so trends group by it across a rename', () async {
    final now = DateTime.utc(2026, 1, 11);
    await CiRunHistoryStore.record([
      _sample('CI', runKey: 'github:owner/name:1', workflowId: '42'),
      _sample(
        'Build',
        runKey: 'github:owner/name:2',
        workflowId: '42',
        outcome: CiOutcome.failure,
        conclusion: 'failure',
      ),
    ], now: now);
    final trends = await CiRunHistoryStore.trends(now: now);
    // Same workflowId '42' under two names collapses to one trend after the
    // DB round-trip (workflowId must be persisted for this to hold).
    expect(trends, hasLength(1));
    expect(trends.single.total, 2);
    expect(trends.single.successes, 1);
    expect(trends.single.failures, 1);
  });

  test(
    'v9 -> v10 upgrade creates ci_run_history with a working unique index',
    () async {
      // A database at the pre-v10 schema (user_version = 9): opening AppDatabase
      // over it runs onUpgrade(9 -> 10), which must create ci_run_history and its
      // UNIQUE run_key index (the record() insert-or-replace de-dup relies on it).
      final native = sqlite3.openInMemory();
      native.execute('PRAGMA user_version = 9;');
      final upgraded = AppDatabase.forExecutor(
        NativeDatabase.opened(native, closeUnderlyingOnClose: true),
      );
      CiRunHistoryStore.debugUseDatabase(upgraded);

      final now = DateTime.utc(2026, 1, 11);
      await CiRunHistoryStore.record([
        _sample(
          'build',
          runKey: 'github:owner/name:1',
          outcome: CiOutcome.failure,
        ),
      ], now: now);
      await CiRunHistoryStore.record([
        _sample(
          'build',
          runKey: 'github:owner/name:1',
          outcome: CiOutcome.success,
        ),
      ], now: now);

      final trends = await CiRunHistoryStore.trends(now: now);
      // The same runKey replaced rather than duplicated: one run, now a success.
      expect(trends.single.total, 1);
      expect(trends.single.successes, 1);
      await upgraded.close();
    },
  );
}
