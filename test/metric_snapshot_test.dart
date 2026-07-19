import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/metric_snapshot.dart';

void main() {
  test('latestSnapshotByDay keeps the latest snapshot per UTC day', () {
    final snaps = [
      MetricSnapshot(
        at: DateTime.utc(2026, 1, 1, 3),
        openPrs: 1,
        needsReview: 0,
        activityScore: 1,
      ),
      // Later the same day — must win over the 03:00 one, and NOT be summed
      // (denser-than-daily capture must not inflate daily aggregations).
      MetricSnapshot(
        at: DateTime.utc(2026, 1, 1, 9),
        openPrs: 5,
        needsReview: 0,
        activityScore: 5,
      ),
      MetricSnapshot(
        at: DateTime.utc(2026, 1, 2, 6),
        openPrs: 3,
        needsReview: 0,
        activityScore: 3,
      ),
    ];

    final byDay = latestSnapshotByDay(snaps);

    expect(byDay, hasLength(2));
    expect(byDay[DateTime.utc(2026, 1, 1)]!.activityScore, 5);
    expect(byDay[DateTime.utc(2026, 1, 2)]!.activityScore, 3);
  });

  test('latestSnapshotByDay is empty for no snapshots', () {
    expect(latestSnapshotByDay(const []), isEmpty);
  });
}
