import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable app preferences.
@immutable
class AppPreferences {
  const AppPreferences({
    this.notificationsEnabled = true,
    this.quietHoursEnabled = false,
    this.quietStartHour = 22,
    this.quietEndHour = 8,
    this.feedLookbackDays = 14,
  });

  final bool notificationsEnabled;
  final bool quietHoursEnabled;

  /// Quiet-hours window in local hours [0, 23]; wraps past midnight when
  /// [quietStartHour] > [quietEndHour].
  final int quietStartHour;
  final int quietEndHour;

  /// Activity Feed lookback window, in days.
  final int feedLookbackDays;

  AppPreferences copyWith({
    bool? notificationsEnabled,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    int? feedLookbackDays,
  }) {
    return AppPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      feedLookbackDays: feedLookbackDays ?? this.feedLookbackDays,
    );
  }
}

/// Persists [AppPreferences] in SharedPreferences and exposes the notification
/// gating logic (enabled + quiet hours).
class PreferencesStore {
  PreferencesStore._();

  static const String _notificationsEnabled = 'pref_notifications_enabled';
  static const String _quietHoursEnabled = 'pref_quiet_hours_enabled';
  static const String _quietStartHour = 'pref_quiet_start_hour';
  static const String _quietEndHour = 'pref_quiet_end_hour';
  static const String _feedLookbackDays = 'pref_feed_lookback_days';

  /// Allowed lookback options shown in the UI.
  static const List<int> lookbackOptions = [7, 14, 30, 60];

  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = AppPreferences();
    return AppPreferences(
      notificationsEnabled:
          prefs.getBool(_notificationsEnabled) ?? defaults.notificationsEnabled,
      quietHoursEnabled:
          prefs.getBool(_quietHoursEnabled) ?? defaults.quietHoursEnabled,
      quietStartHour: _clampHour(
        prefs.getInt(_quietStartHour) ?? defaults.quietStartHour,
      ),
      quietEndHour: _clampHour(
        prefs.getInt(_quietEndHour) ?? defaults.quietEndHour,
      ),
      feedLookbackDays: _sanitizeLookback(
        prefs.getInt(_feedLookbackDays) ?? defaults.feedLookbackDays,
      ),
    );
  }

  static Future<void> setNotificationsEnabled(bool value) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsEnabled, value);
    });
  }

  static Future<void> setQuietHoursEnabled(bool value) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_quietHoursEnabled, value);
    });
  }

  static Future<void> setQuietStartHour(int hour) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_quietStartHour, _clampHour(hour));
    });
  }

  static Future<void> setQuietEndHour(int hour) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_quietEndHour, _clampHour(hour));
    });
  }

  static Future<void> setFeedLookbackDays(int days) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_feedLookbackDays, _sanitizeLookback(days));
    });
  }

  /// Whether notifications should be shown right now given [prefs] and [now].
  static bool notificationsAllowed(AppPreferences prefs, DateTime now) {
    if (!prefs.notificationsEnabled) return false;
    if (prefs.quietHoursEnabled &&
        isWithinQuietHours(now, prefs.quietStartHour, prefs.quietEndHour)) {
      return false;
    }
    return true;
  }

  /// True when [now]'s local hour is inside the quiet window. Handles windows
  /// that wrap past midnight (start > end). An empty window (start == end) is
  /// never quiet.
  static bool isWithinQuietHours(DateTime now, int startHour, int endHour) {
    final start = _clampHour(startHour);
    final end = _clampHour(endHour);
    if (start == end) return false;
    final hour = now.hour;
    if (start < end) return hour >= start && hour < end;
    // Wraps past midnight, e.g. 22 -> 8.
    return hour >= start || hour < end;
  }

  static int _clampHour(int hour) => hour.clamp(0, 23);

  static int _sanitizeLookback(int days) =>
      lookbackOptions.contains(days) ? days : 14;
}
