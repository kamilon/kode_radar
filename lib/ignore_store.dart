import 'package:shared_preferences/shared_preferences.dart';

import 'repo_store.dart';

/// Persists a set of repository keys the user never wants monitored.
///
/// Keys use the same scheme as [RepoDiscoveryService] (`github:owner/name`,
/// `ado:org/project/name`), so auto-add and the import UI can consult it.
///
/// Writes go through [RepoStore.runLocked] — the SAME lock as the repo lists —
/// so combined operations like "remove & ignore" are atomic against an
/// in-flight auto-add pass.
class IgnoreStore {
  IgnoreStore._();

  static const String storageKey = 'ignored_repos';

  /// Returns the current set of ignored repo keys.
  static Future<Set<String>> get() async {
    final prefs = await SharedPreferences.getInstance();
    return readFrom(prefs);
  }

  /// Reads the ignore set from an already-obtained [prefs] without locking —
  /// for use inside an existing [RepoStore.runLocked] section.
  static Set<String> readFrom(SharedPreferences prefs) =>
      (prefs.getStringList(storageKey) ?? const <String>[]).toSet();

  /// Writes the ignore set using an already-obtained [prefs] without locking —
  /// for use inside an existing [RepoStore.runLocked] section.
  static Future<void> writeTo(SharedPreferences prefs, Set<String> keys) =>
      prefs.setStringList(storageKey, keys.toList());

  static Future<void> add(String key) => addAll([key]);

  static Future<void> addAll(Iterable<String> keys) {
    return RepoStore.runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final set = readFrom(prefs);
      set.addAll(keys.where((k) => k.isNotEmpty));
      await writeTo(prefs, set);
    });
  }

  static Future<void> remove(String key) {
    return RepoStore.runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final set = readFrom(prefs);
      set.remove(key);
      await writeTo(prefs, set);
    });
  }
}
