import 'package:shared_preferences/shared_preferences.dart';

/// Persists the set of repositories whose attention notifications are muted.
///
/// Muting only suppresses *notifications* for a repo — its items still appear in
/// the Attention Inbox. Entries are keyed by `repoDisplay` (`owner/name` for
/// GitHub, `org/project/name` for Azure DevOps) to match
/// `AttentionItem.repoDisplay` and the notification gate.
class MuteStore {
  MuteStore._();

  static const String _storageKey = 'muted_repos';

  // Serializes the read-modify-write of the muted set so rapid toggles can't
  // clobber one another's persisted state.
  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// The set of muted repo displays.
  static Future<Set<String>> mutedDisplays() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storageKey) ?? const <String>[]).toSet();
  }

  /// Whether [display] is currently muted.
  static Future<bool> isMuted(String display) async =>
      (await mutedDisplays()).contains(display);

  /// Mutes or unmutes [display].
  static Future<void> setMuted(String display, bool muted) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final set = (prefs.getStringList(_storageKey) ?? const <String>[])
          .toSet();
      if (muted) {
        set.add(display);
      } else {
        set.remove(display);
      }
      await prefs.setStringList(_storageKey, set.toList());
    });
  }

  /// Removes [display] from the muted set (e.g. when the repo is deleted).
  static Future<void> remove(String display) => setMuted(display, false);
}
