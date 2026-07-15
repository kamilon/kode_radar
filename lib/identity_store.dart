import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class IdentityStore {
  IdentityStore._();

  static const String _githubKey = 'self_github_logins';
  static const String _adoKey = 'self_ado_names';

  static Future<Set<String>> selfGithubLogins() async {
    final prefs = await SharedPreferences.getInstance();
    return _readSet(prefs, _githubKey, _normalizeLogin);
  }

  static Future<void> setSelfGithubLogins(Set<String> logins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _githubKey,
      jsonEncode(_normalizedSorted(logins, _normalizeLogin)),
    );
  }

  static Future<Set<String>> selfAdoNames() async {
    final prefs = await SharedPreferences.getInstance();
    return _readSet(prefs, _adoKey, _normalizeName);
  }

  static Future<void> setSelfAdoNames(Set<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _adoKey,
      jsonEncode(_normalizedSorted(names, _normalizeName)),
    );
  }

  static Set<String> _readSet(
    SharedPreferences prefs,
    String key,
    String Function(String) normalize,
  ) {
    final raw = prefs.getString(key);
    if (raw == null) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return _normalizedSorted(
        decoded.whereType<String>().toSet(),
        normalize,
      ).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static List<String> _normalizedSorted(
    Iterable<String> values,
    String Function(String) normalize,
  ) {
    final normalized = values
        .map(normalize)
        .where((value) => value.isNotEmpty)
        .toSet();
    return normalized.toList()..sort();
  }

  static String _normalizeLogin(String value) => value.trim().toLowerCase();

  static String _normalizeName(String value) => value.trim();
}
