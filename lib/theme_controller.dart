import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds and persists the app-wide light/dark/system theme preference, and
/// notifies listeners (the root [MaterialApp]) when it changes.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String storageKey = 'theme_mode';

  // Serializes SharedPreferences access so rapid theme changes can't persist
  // out of order (matches TokenStore/RepoStore).
  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Loads the persisted preference. Safe to call once at startup.
  Future<void> load() async {
    await _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      _mode = parseMode(prefs.getString(storageKey));
    });
    notifyListeners();
  }

  /// Updates and persists the theme mode.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, mode.name);
    });
  }

  /// Parses a stored value into a [ThemeMode], defaulting to system.
  static ThemeMode parseMode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
