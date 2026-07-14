import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SnoozeStore {
  SnoozeStore._();

  static const String _storageKey = 'snoozed_attention';

  static Future<Set<String>> snoozedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _readFrom(prefs);
    final pruned = pruneExpired(raw, DateTime.now());
    if (!_mapsEqual(raw, pruned)) {
      await _writeTo(prefs, pruned);
    }
    return pruned.keys.toSet();
  }

  static Future<void> snooze(String id, {Duration? forDuration}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _readFrom(prefs);
    raw[id] = forDuration == null
        ? null
        : DateTime.now().add(forDuration).millisecondsSinceEpoch;
    await _writeTo(prefs, raw);
  }

  static Future<void> unsnooze(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _readFrom(prefs);
    raw.remove(id);
    await _writeTo(prefs, raw);
  }

  static Future<bool> isSnoozed(String id) async {
    final ids = await snoozedIds();
    return ids.contains(id);
  }

  static Map<String, int?> pruneExpired(Map<String, int?> raw, DateTime now) {
    final nowMillis = now.millisecondsSinceEpoch;
    return Map<String, int?>.fromEntries(
      raw.entries.where((entry) {
        final untilMillis = entry.value;
        return untilMillis == null || untilMillis > nowMillis;
      }),
    );
  }

  static Map<String, int?> _readFrom(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <String, int?>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int?>{};

      final result = <String, int?>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        if (key is! String || key.isEmpty) continue;

        final value = entry.value;
        if (value == null) {
          result[key] = null;
        } else if (value is int) {
          result[key] = value;
        } else if (value is num) {
          result[key] = value.toInt();
        }
      }
      return result;
    } catch (_) {
      return <String, int?>{};
    }
  }

  static Future<void> _writeTo(
    SharedPreferences prefs,
    Map<String, int?> raw,
  ) async {
    await prefs.setString(_storageKey, jsonEncode(raw));
  }

  static bool _mapsEqual(Map<String, int?> a, Map<String, int?> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
