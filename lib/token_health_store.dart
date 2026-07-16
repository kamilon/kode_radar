import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'token_health_service.dart';

/// A persisted token check: the last known [TokenHealth], the resolved account
/// (if any), a human-readable message, and when the check ran.
class StoredTokenCheck {
  const StoredTokenCheck({
    required this.health,
    required this.checkedAt,
    this.account,
    this.message,
  });

  final TokenHealth health;
  final DateTime checkedAt;
  final String? account;
  final String? message;

  Map<String, dynamic> toJson() => {
    'health': health.name,
    'checkedAt': checkedAt.toUtc().millisecondsSinceEpoch,
    if (account != null) 'account': account,
    if (message != null) 'message': message,
  };

  /// Parses a stored entry, or null if it is malformed (unknown health or a
  /// missing/invalid timestamp).
  static StoredTokenCheck? fromJson(dynamic json) {
    if (json is! Map) return null;
    final healthName = json['health'];
    TokenHealth? health;
    for (final h in TokenHealth.values) {
      if (h.name == healthName) {
        health = h;
        break;
      }
    }
    if (health == null) return null;
    final millis = json['checkedAt'];
    if (millis is! int) return null;
    final DateTime checkedAt;
    try {
      checkedAt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    } catch (_) {
      // An out-of-range timestamp shouldn't discard every other entry.
      return null;
    }
    final account = json['account'];
    final message = json['message'];
    return StoredTokenCheck(
      health: health,
      checkedAt: checkedAt,
      account: account is String ? account : null,
      message: message is String ? message : null,
    );
  }
}

/// Persists the most recent [TokenCheck] per token id so Manage Tokens can show
/// the last known health (and when it was verified) without re-checking.
class TokenHealthStore {
  TokenHealthStore._();

  static const String _storageKey = 'token_health';

  // Serializes read-modify-write access so concurrent verifications can't
  // clobber one another's persisted state.
  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Records the outcome of verifying [tokenId].
  static Future<void> record(
    String tokenId,
    TokenCheck check, {
    DateTime? now,
  }) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = _readFrom(prefs);
      raw[tokenId] = StoredTokenCheck(
        health: check.health,
        checkedAt: now ?? DateTime.now(),
        account: check.account,
        message: check.message,
      );
      await _writeTo(prefs, raw);
    });
  }

  /// The last recorded check per token id.
  static Future<Map<String, StoredTokenCheck>> all() {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      return _readFrom(prefs);
    });
  }

  /// Drops the stored check for [tokenId] (e.g. after removing the token).
  static Future<void> remove(String tokenId) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = _readFrom(prefs);
      if (raw.remove(tokenId) != null) {
        await _writeTo(prefs, raw);
      }
    });
  }

  static Map<String, StoredTokenCheck> _readFrom(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, StoredTokenCheck>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        if (key is! String || key.isEmpty) continue;
        final parsed = StoredTokenCheck.fromJson(entry.value);
        if (parsed != null) result[key] = parsed;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeTo(
    SharedPreferences prefs,
    Map<String, StoredTokenCheck> raw,
  ) async {
    final encoded = raw.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString(_storageKey, jsonEncode(encoded));
  }
}
