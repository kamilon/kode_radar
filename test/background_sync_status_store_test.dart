import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/background_sync_status_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read() returns null before any background run', () async {
    expect(await BackgroundSyncStatusStore.read(), isNull);
  });

  test('recordStarted leaves an unfinished marker', () async {
    final at = DateTime.utc(2026, 7, 15, 12);
    await BackgroundSyncStatusStore.recordStarted(at: at);

    final status = await BackgroundSyncStatusStore.read();
    expect(status, isNotNull);
    expect(status!.at, at);
    expect(status.finished, isFalse);
  });

  test('recordFinished records a successful run', () async {
    final at = DateTime.utc(2026, 7, 15, 12);
    await BackgroundSyncStatusStore.recordFinished(
      activityOk: true,
      repoCount: 7,
      at: at,
    );

    final status = await BackgroundSyncStatusStore.read();
    expect(status!.finished, isTrue);
    expect(status.activityOk, isTrue);
    expect(status.repoCount, 7);
    expect(status.at, at);
  });

  test('recordFinished records a failed run', () async {
    await BackgroundSyncStatusStore.recordFinished(
      activityOk: false,
      repoCount: 0,
    );
    final status = await BackgroundSyncStatusStore.read();
    expect(status!.finished, isTrue);
    expect(status.activityOk, isFalse);
  });

  test('recordFinished overwrites a prior started marker', () async {
    await BackgroundSyncStatusStore.recordStarted(at: DateTime.utc(2026, 1, 1));
    await BackgroundSyncStatusStore.recordFinished(
      activityOk: true,
      repoCount: 3,
      at: DateTime.utc(2026, 1, 1, 0, 0, 20),
    );
    final status = await BackgroundSyncStatusStore.read();
    expect(status!.finished, isTrue);
    expect(status.repoCount, 3);
  });

  test('BackgroundSyncStatus JSON round-trips', () {
    final original = BackgroundSyncStatus(
      at: DateTime.utc(2026, 7, 15, 12),
      finished: true,
      activityOk: true,
      repoCount: 12,
    );
    final restored = BackgroundSyncStatus.fromJson(
      jsonDecode(jsonEncode(original.toJson())),
    );
    expect(restored, isNotNull);
    expect(restored!.at, original.at);
    expect(restored.finished, isTrue);
    expect(restored.activityOk, isTrue);
    expect(restored.repoCount, 12);
  });

  test('fromJson rejects malformed entries', () {
    expect(BackgroundSyncStatus.fromJson('not-a-map'), isNull);
    expect(BackgroundSyncStatus.fromJson({'finished': true}), isNull);
    expect(BackgroundSyncStatus.fromJson({'at': 'nope'}), isNull);
    // Out-of-range epoch must not throw.
    expect(BackgroundSyncStatus.fromJson({'at': 9999999999999999}), isNull);
  });

  test('fromJson defaults missing/invalid optional fields', () {
    final status = BackgroundSyncStatus.fromJson({
      'at': DateTime.utc(2026, 7, 15).millisecondsSinceEpoch,
    });
    expect(status, isNotNull);
    // A record with a valid timestamp but no `finished` flag is treated as
    // finished so it never sticks on "didn't finish".
    expect(status!.finished, isTrue);
    expect(status.activityOk, isFalse);
    expect(status.repoCount, 0);
  });
}
