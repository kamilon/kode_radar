import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a per-view "last seen" timestamp so views can highlight what is new
/// "since you last looked". Timestamps are stored as UTC epoch milliseconds.
class SeenStore {
  SeenStore._();

  static const String feedKey = 'feed';
  static const String radarKey = 'radar';
  static const String _prefix = 'seen_';

  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// The last time the given [key] view was marked seen, or null if never.
  static Future<DateTime?> lastSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('$_prefix$key');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  /// Records [when] as the last-seen time for [key]. Serialized so concurrent
  /// writes can't interleave; never moves the marker backwards.
  static Future<void> markSeen(String key, DateTime when) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = '$_prefix$key';
      final existing = prefs.getInt(storageKey);
      final millis = when.toUtc().millisecondsSinceEpoch;
      if (existing != null && existing >= millis) return;
      await prefs.setInt(storageKey, millis);
    });
  }

  @visibleForTesting
  static Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
    _lock = Future<void>.value();
  }
}
