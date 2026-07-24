import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/cycle_time.dart';

MergedPrSample _pr({
  required int number,
  String repoKey = 'github:owner/name',
  String repoDisplay = 'owner/name',
  required DateTime createdAt,
  required DateTime mergedAt,
  DateTime? firstReviewAt,
  String provider = 'github',
}) => MergedPrSample(
  provider: provider,
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
  group('MergedPrSample timings', () {
    test('time-to-first-review and time-to-merge computed from timestamps', () {
      final pr = _pr(
        number: 1,
        createdAt: DateTime.utc(2026, 1, 1, 0),
        firstReviewAt: DateTime.utc(2026, 1, 1, 2),
        mergedAt: DateTime.utc(2026, 1, 1, 5),
      );
      expect(pr.timeToFirstReviewMs, const Duration(hours: 2).inMilliseconds);
      expect(pr.timeToMergeMs, const Duration(hours: 5).inMilliseconds);
    });

    test('null first-review yields null review time', () {
      final pr = _pr(
        number: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        mergedAt: DateTime.utc(2026, 1, 2),
      );
      expect(pr.timeToFirstReviewMs, isNull);
      expect(pr.timeToMergeMs, const Duration(days: 1).inMilliseconds);
    });

    test('negative spans (clock skew) guard to null', () {
      final pr = _pr(
        number: 1,
        createdAt: DateTime.utc(2026, 1, 2),
        firstReviewAt: DateTime.utc(2026, 1, 1),
        mergedAt: DateTime.utc(2026, 1, 1, 12),
      );
      expect(pr.timeToFirstReviewMs, isNull);
      expect(pr.timeToMergeMs, isNull);
    });
  });

  group('CycleTimeStats.median', () {
    test('odd count returns middle', () {
      expect(CycleTimeStats.median([3, 1, 2]), 2);
    });
    test('even count averages the two middle values', () {
      expect(CycleTimeStats.median([10, 20, 30, 40]), 25);
    });
    test('empty returns null and does not mutate input', () {
      final input = <int>[];
      expect(CycleTimeStats.median(input), isNull);
      final ordered = [5, 1, 3];
      CycleTimeStats.median(ordered);
      expect(ordered, [5, 1, 3]);
    });
  });

  group('CycleTimeStats.summarize', () {
    final now = DateTime.utc(2026, 2, 1);

    test('medians over PRs merged within the window', () {
      final samples = [
        _pr(
          number: 1,
          createdAt: DateTime.utc(2026, 1, 30, 0),
          firstReviewAt: DateTime.utc(2026, 1, 30, 1),
          mergedAt: DateTime.utc(2026, 1, 30, 3),
        ),
        _pr(
          number: 2,
          createdAt: DateTime.utc(2026, 1, 31, 0),
          firstReviewAt: DateTime.utc(2026, 1, 31, 3),
          mergedAt: DateTime.utc(2026, 1, 31, 9),
        ),
      ];
      final s = CycleTimeStats.summarize(samples, now: now);
      expect(s.mergedCount, 2);
      expect(s.reviewedCount, 2);
      // review: [1h, 3h] -> median 2h; merge: [3h, 9h] -> median 6h
      expect(
        s.medianTimeToFirstReviewMs,
        const Duration(hours: 2).inMilliseconds,
      );
      expect(s.medianTimeToMergeMs, const Duration(hours: 6).inMilliseconds);
    });

    test('excludes PRs merged before the window', () {
      final samples = [
        _pr(
          number: 1,
          createdAt: DateTime.utc(2025, 12, 1),
          mergedAt: DateTime.utc(2025, 12, 2),
        ),
        _pr(
          number: 2,
          createdAt: DateTime.utc(2026, 1, 20),
          mergedAt: DateTime.utc(2026, 1, 21),
        ),
      ];
      final s = CycleTimeStats.summarize(
        samples,
        now: now,
        window: const Duration(days: 30),
      );
      expect(s.mergedCount, 1);
    });

    test('reviewedCount counts only PRs with a first-review time', () {
      final samples = [
        _pr(
          number: 1,
          createdAt: DateTime.utc(2026, 1, 30, 0),
          firstReviewAt: DateTime.utc(2026, 1, 30, 1),
          mergedAt: DateTime.utc(2026, 1, 30, 2),
        ),
        _pr(
          number: 2,
          createdAt: DateTime.utc(2026, 1, 31, 0),
          mergedAt: DateTime.utc(2026, 1, 31, 4),
        ),
      ];
      final s = CycleTimeStats.summarize(samples, now: now);
      expect(s.mergedCount, 2);
      expect(s.reviewedCount, 1);
      expect(
        s.medianTimeToFirstReviewMs,
        const Duration(hours: 1).inMilliseconds,
      );
    });

    test('empty input is empty summary', () {
      final s = CycleTimeStats.summarize(const [], now: now);
      expect(s.isEmpty, isTrue);
      expect(s.medianTimeToFirstReviewMs, isNull);
      expect(s.medianTimeToMergeMs, isNull);
    });
  });

  group('CycleTimeStats.perRepo', () {
    final now = DateTime.utc(2026, 2, 1);

    test('sorts slowest median merge first', () {
      final samples = [
        _pr(
          number: 1,
          repoKey: 'github:o/fast',
          repoDisplay: 'o/fast',
          createdAt: DateTime.utc(2026, 1, 31, 0),
          mergedAt: DateTime.utc(2026, 1, 31, 1),
        ),
        _pr(
          number: 2,
          repoKey: 'github:o/slow',
          repoDisplay: 'o/slow',
          createdAt: DateTime.utc(2026, 1, 20, 0),
          mergedAt: DateTime.utc(2026, 1, 25, 0),
        ),
      ];
      final repos = CycleTimeStats.perRepo(samples, now: now);
      expect(repos.map((r) => r.repoKey), ['github:o/slow', 'github:o/fast']);
    });

    test('drops repos with no PRs in the window', () {
      final samples = [
        _pr(
          number: 1,
          repoKey: 'github:o/old',
          repoDisplay: 'o/old',
          createdAt: DateTime.utc(2025, 11, 1),
          mergedAt: DateTime.utc(2025, 11, 2),
        ),
        _pr(
          number: 2,
          repoKey: 'github:o/recent',
          repoDisplay: 'o/recent',
          createdAt: DateTime.utc(2026, 1, 28),
          mergedAt: DateTime.utc(2026, 1, 29),
        ),
      ];
      final repos = CycleTimeStats.perRepo(
        samples,
        now: now,
        window: const Duration(days: 30),
      );
      expect(repos.map((r) => r.repoKey), ['github:o/recent']);
    });
  });
}
