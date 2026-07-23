import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults are returned when nothing is stored', () async {
    final prefs = await PreferencesStore.load();
    expect(prefs.notificationsEnabled, isTrue);
    expect(prefs.quietHoursEnabled, isFalse);
    expect(prefs.feedLookbackDays, 14);
    expect(prefs.backgroundSyncEnabled, isTrue);
    expect(prefs.notifyMineOnly, isFalse);
    expect(prefs.silencedNotifyCategories, isEmpty);
  });

  test('notify mine-only setting round-trips through load()', () async {
    await PreferencesStore.setNotifyMineOnly(true);
    expect((await PreferencesStore.load()).notifyMineOnly, isTrue);
    await PreferencesStore.setNotifyMineOnly(false);
    expect((await PreferencesStore.load()).notifyMineOnly, isFalse);
  });

  test('silenced notify categories round-trip and toggle', () async {
    await PreferencesStore.setCategorySilenced('oldOpenPr', true);
    await PreferencesStore.setCategorySilenced('error', true);
    expect((await PreferencesStore.load()).silencedNotifyCategories, {
      'oldOpenPr',
      'error',
    });
    // Idempotent add + independent remove.
    await PreferencesStore.setCategorySilenced('oldOpenPr', true);
    await PreferencesStore.setCategorySilenced('error', false);
    expect((await PreferencesStore.load()).silencedNotifyCategories, {
      'oldOpenPr',
    });
  });

  test('background sync setting round-trips through load()', () async {
    await PreferencesStore.setBackgroundSyncEnabled(false);
    expect((await PreferencesStore.load()).backgroundSyncEnabled, isFalse);
    await PreferencesStore.setBackgroundSyncEnabled(true);
    expect((await PreferencesStore.load()).backgroundSyncEnabled, isTrue);
  });

  test('digest settings round-trip through load()', () async {
    expect((await PreferencesStore.load()).digestModeEnabled, isFalse);
    expect((await PreferencesStore.load()).digestHour, 9);
    await PreferencesStore.setDigestModeEnabled(true);
    await PreferencesStore.setDigestHour(7);
    final loaded = await PreferencesStore.load();
    expect(loaded.digestModeEnabled, isTrue);
    expect(loaded.digestHour, 7);
    // Out-of-range hour is clamped.
    await PreferencesStore.setDigestHour(99);
    expect((await PreferencesStore.load()).digestHour, 23);
  });

  test('last-digest local date key formats correctly', () {
    expect(PreferencesStore.localDateString(DateTime(2026, 1, 5)), '2026-1-5');
    expect(
      PreferencesStore.localDateString(DateTime(2026, 7, 23, 14)),
      '2026-7-23',
    );
  });

  test('setters round-trip through load()', () async {
    await PreferencesStore.setNotificationsEnabled(false);
    await PreferencesStore.setQuietHoursEnabled(true);
    await PreferencesStore.setQuietStartHour(23);
    await PreferencesStore.setQuietEndHour(7);
    await PreferencesStore.setFeedLookbackDays(30);
    final prefs = await PreferencesStore.load();
    expect(prefs.notificationsEnabled, isFalse);
    expect(prefs.quietHoursEnabled, isTrue);
    expect(prefs.quietStartHour, 23);
    expect(prefs.quietEndHour, 7);
    expect(prefs.feedLookbackDays, 30);
  });

  test('invalid lookback falls back to 14; hours are clamped', () async {
    await PreferencesStore.setFeedLookbackDays(999);
    await PreferencesStore.setQuietStartHour(99);
    final prefs = await PreferencesStore.load();
    expect(prefs.feedLookbackDays, 14);
    expect(prefs.quietStartHour, 23);
  });

  group('isWithinQuietHours', () {
    DateTime at(int hour) => DateTime(2026, 7, 15, hour, 30);

    test('overnight window wraps past midnight', () {
      expect(PreferencesStore.isWithinQuietHours(at(23), 22, 8), isTrue);
      expect(PreferencesStore.isWithinQuietHours(at(3), 22, 8), isTrue);
      expect(PreferencesStore.isWithinQuietHours(at(12), 22, 8), isFalse);
      expect(PreferencesStore.isWithinQuietHours(at(8), 22, 8), isFalse);
    });

    test('same-day window is inclusive of start, exclusive of end', () {
      expect(PreferencesStore.isWithinQuietHours(at(9), 9, 17), isTrue);
      expect(PreferencesStore.isWithinQuietHours(at(16), 9, 17), isTrue);
      expect(PreferencesStore.isWithinQuietHours(at(17), 9, 17), isFalse);
      expect(PreferencesStore.isWithinQuietHours(at(8), 9, 17), isFalse);
    });

    test('empty window (start == end) is never quiet', () {
      expect(PreferencesStore.isWithinQuietHours(at(9), 9, 9), isFalse);
    });
  });

  group('notificationsAllowed', () {
    test('blocked when notifications disabled', () {
      const prefs = AppPreferences(notificationsEnabled: false);
      expect(
        PreferencesStore.notificationsAllowed(prefs, DateTime(2026, 7, 15, 12)),
        isFalse,
      );
    });

    test('blocked during quiet hours, allowed otherwise', () {
      const prefs = AppPreferences(
        quietHoursEnabled: true,
        quietStartHour: 22,
        quietEndHour: 8,
      );
      expect(
        PreferencesStore.notificationsAllowed(prefs, DateTime(2026, 7, 15, 23)),
        isFalse,
      );
      expect(
        PreferencesStore.notificationsAllowed(prefs, DateTime(2026, 7, 15, 12)),
        isTrue,
      );
    });
  });
}
