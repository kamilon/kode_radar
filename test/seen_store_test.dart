import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/seen_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SeenStore.debugReset();
  });

  test('lastSeen is null until first marked, then round-trips', () async {
    expect(await SeenStore.lastSeen(SeenStore.feedKey), isNull);
    final when = DateTime.utc(2026, 7, 15, 12);
    await SeenStore.markSeen(SeenStore.feedKey, when);
    expect(await SeenStore.lastSeen(SeenStore.feedKey), when);
  });

  test('keys are independent', () async {
    final when = DateTime.utc(2026, 7, 15, 12);
    await SeenStore.markSeen(SeenStore.feedKey, when);
    expect(await SeenStore.lastSeen(SeenStore.radarKey), isNull);
  });

  test('markSeen never moves the marker backwards', () async {
    final later = DateTime.utc(2026, 7, 15, 12);
    final earlier = DateTime.utc(2026, 7, 14, 12);
    await SeenStore.markSeen(SeenStore.feedKey, later);
    await SeenStore.markSeen(SeenStore.feedKey, earlier);
    expect(await SeenStore.lastSeen(SeenStore.feedKey), later);
  });

  test('stores as UTC regardless of input zone offset', () async {
    final local = DateTime.parse('2026-07-15T12:00:00Z').toLocal();
    await SeenStore.markSeen(SeenStore.feedKey, local);
    final stored = await SeenStore.lastSeen(SeenStore.feedKey);
    expect(stored, DateTime.parse('2026-07-15T12:00:00Z'));
    expect(stored!.isUtc, isTrue);
  });
}
