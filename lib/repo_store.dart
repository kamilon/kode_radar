import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Serializes read-modify-write access to the persisted repository lists
/// (`github_repos` / `ado_repos`) so the background auto-add pass and the UI
/// (add / edit / delete / import) can never clobber one another.
class RepoStore {
  RepoStore._();

  static const String githubKey = 'github_repos';
  static const String adoKey = 'ado_repos';

  static Future<void> _lock = Future<void>.value();

  /// Runs [action] on the shared repo/ignore mutation lock. Used by
  /// [IgnoreStore] and by combined operations so repo-list and ignore-list
  /// writes are serialized against one another (e.g. "remove & ignore" vs. an
  /// in-flight auto-add pass).
  static Future<T> runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    // Keep the chain alive whether the action succeeds or fails.
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static Future<T> _synchronized<T>(Future<T> Function() action) =>
      runLocked(action);

  /// Atomically reads [storageKey], lets [mutate] modify the list in place, and
  /// writes it back. Returns whatever [mutate] returns.
  static Future<T> update<T>(
    String storageKey,
    T Function(List<String> repos) mutate,
  ) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final repos = List<String>.of(
        prefs.getStringList(storageKey) ?? const [],
      );
      final result = mutate(repos);
      await prefs.setStringList(storageKey, repos);
      return result;
    });
  }

  /// Atomically reads and writes BOTH lists together (used by the auto-add
  /// pass, which may touch either provider).
  static Future<T> updateBoth<T>(
    T Function(List<String> github, List<String> ado) mutate,
  ) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final github = List<String>.of(
        prefs.getStringList(githubKey) ?? const [],
      );
      final ado = List<String>.of(prefs.getStringList(adoKey) ?? const []);
      final result = mutate(github, ado);
      await prefs.setStringList(githubKey, github);
      await prefs.setStringList(adoKey, ado);
      return result;
    });
  }
}
