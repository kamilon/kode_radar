import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Metadata about a stored access token.
///
/// The secret value itself is kept in secure storage under `token_<id>` and is
/// never held in this record.
class TokenInfo {
  const TokenInfo({
    required this.id,
    required this.provider,
    required this.label,
    required this.scope,
    this.autoAdd = false,
  });

  /// Unique identifier for the token.
  final String id;

  /// Either [TokenStore.providerGithub] or [TokenStore.providerAdo].
  final String provider;

  /// Human-readable signifier, e.g. "Personal" or "Acme Org".
  final String label;

  /// The org/owner this token applies to. An empty string marks the token as
  /// the default fallback for its provider.
  final String scope;

  /// When true, newly-appearing repositories visible to this token are added
  /// to monitoring automatically.
  final bool autoAdd;

  bool get isDefault => scope.trim().isEmpty;

  String get providerDisplayName =>
      provider == TokenStore.providerAdo ? 'Azure DevOps' : 'GitHub';

  TokenInfo copyWith({String? label, String? scope, bool? autoAdd}) =>
      TokenInfo(
        id: id,
        provider: provider,
        label: label ?? this.label,
        scope: scope ?? this.scope,
        autoAdd: autoAdd ?? this.autoAdd,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    'label': label,
    'scope': scope,
    'autoAdd': autoAdd,
  };

  factory TokenInfo.fromJson(Map<String, dynamic> json) => TokenInfo(
    id: json['id'] as String,
    provider: json['provider'] as String? ?? TokenStore.providerGithub,
    label: json['label'] as String? ?? '',
    scope: json['scope'] as String? ?? '',
    autoAdd: json['autoAdd'] as bool? ?? false,
  );
}

/// Manages multiple GitHub / Azure DevOps access tokens.
///
/// Token metadata (id, provider, label, scope) is stored in
/// `SharedPreferences` under [_tokensKey]; each secret is stored separately in
/// the OS secure store under `token_<id>`.
class TokenStore {
  TokenStore._();

  static const String providerGithub = 'github';
  static const String providerAdo = 'ado';

  static const String _tokensKey = 'tokens';
  static const String _secretPrefix = 'token_';
  static const String _legacyGithubKey = 'github_token';
  static const String _legacyAdoKey = 'ado_token';

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static final Random _random = Random();

  /// In-flight migration, shared by concurrent first-run callers.
  static Future<List<TokenInfo>>? _migrationFuture;

  /// Serializes mutating operations so their read-modify-write cycles cannot
  /// clobber one another.
  static Future<void> _mutationLock = Future<void>.value();

  static Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _mutationLock.then((_) => action());
    // Keep the chain alive whether the action succeeds or fails.
    _mutationLock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(0x7fffffff)}';

  /// Returns all token metadata, running a one-time migration from legacy
  /// single-token storage on first use.
  static Future<List<TokenInfo>> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_tokensKey);
    if (raw != null) {
      return _parse(raw);
    }
    // Single-flight the migration so concurrent first-run callers share one
    // pass rather than racing to migrate/persist independently.
    return _migrationFuture ??= _migrateLegacy(
      prefs,
    ).whenComplete(() => _migrationFuture = null);
  }

  /// Returns the tokens registered for a given provider.
  static Future<List<TokenInfo>> getTokensForProvider(String provider) async {
    final tokens = List<TokenInfo>.of(await getTokens());
    return tokens.where((t) => t.provider == provider).toList();
  }

  static List<TokenInfo> _parse(List<String> raw) {
    final result = <TokenInfo>[];
    for (final entry in raw) {
      try {
        result.add(
          TokenInfo.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip malformed entries rather than failing the whole load.
      }
    }
    return result;
  }

  static Future<void> _persist(
    SharedPreferences prefs,
    List<TokenInfo> tokens,
  ) async {
    await prefs.setStringList(
      _tokensKey,
      tokens.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  /// Reads the decrypted secret for a token id, or null if unavailable.
  static Future<String?> getSecret(String id) async {
    try {
      return await _secure.read(key: _secretPrefix + id);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to read secret for token "$id": $e');
      }
      return null;
    }
  }

  static Future<TokenInfo> addToken({
    required String provider,
    required String label,
    required String scope,
    required String secret,
    bool autoAdd = false,
  }) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final tokens = List<TokenInfo>.of(await getTokens());
      final info = TokenInfo(
        id: _newId(),
        provider: provider,
        label: label.trim(),
        scope: scope.trim(),
        autoAdd: autoAdd,
      );
      await _secure.write(key: _secretPrefix + info.id, value: secret.trim());
      tokens.add(info);
      await _persist(prefs, tokens);
      return info;
    });
  }

  /// Updates a token's metadata and, when [secret] is a non-empty value, its
  /// stored secret. Passing a null or blank [secret] leaves the secret intact.
  static Future<void> updateToken(TokenInfo info, {String? secret}) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final tokens = List<TokenInfo>.of(await getTokens());
      final index = tokens.indexWhere((t) => t.id == info.id);
      if (index == -1) return;
      tokens[index] = info.copyWith(
        label: info.label.trim(),
        scope: info.scope.trim(),
      );
      if (secret != null && secret.trim().isNotEmpty) {
        await _secure.write(key: _secretPrefix + info.id, value: secret.trim());
      }
      await _persist(prefs, tokens);
    });
  }

  static Future<void> deleteToken(String id) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final tokens = List<TokenInfo>.of(await getTokens());
      tokens.removeWhere((t) => t.id == id);
      await _persist(prefs, tokens);
      try {
        await _secure.delete(key: _secretPrefix + id);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to delete secret for token "$id": $e');
        }
      }
    });
  }

  /// Resolves the secret to use for a GitHub repo owned by [owner], honoring an
  /// optional explicit [tokenId] override.
  static Future<String?> resolveGithubSecret(String owner, {String? tokenId}) =>
      _resolve(providerGithub, owner, tokenId);

  /// Resolves the secret to use for an Azure DevOps [organization], honoring an
  /// optional explicit [tokenId] override.
  static Future<String?> resolveAdoSecret(
    String organization, {
    String? tokenId,
  }) => _resolve(providerAdo, organization, tokenId);

  static Future<String?> _resolve(
    String provider,
    String scopeValue,
    String? tokenId,
  ) async {
    final tokens = await getTokensForProvider(provider);

    // 1) Explicit per-repo override (only if the token still exists).
    if (tokenId != null && tokenId.isNotEmpty) {
      for (final token in tokens) {
        if (token.id == tokenId) {
          return getSecret(token.id);
        }
      }
    }

    // 2) A token scoped to this owner/org (case-insensitive).
    final needle = scopeValue.trim().toLowerCase();
    if (needle.isNotEmpty) {
      for (final token in tokens) {
        if (token.scope.trim().toLowerCase() == needle) {
          return getSecret(token.id);
        }
      }
    }

    // 3) The provider's default (unscoped) token.
    for (final token in tokens) {
      if (token.isDefault) {
        return getSecret(token.id);
      }
    }

    return null;
  }

  static Future<List<TokenInfo>> _migrateLegacy(SharedPreferences prefs) async {
    const legacy = [
      [_legacyGithubKey, providerGithub, 'GitHub token'],
      [_legacyAdoKey, providerAdo, 'Azure DevOps token'],
    ];

    // Phase 1: read any legacy secrets that need migrating.
    final pending = <({TokenInfo info, String legacyKey, String secret})>[];
    for (final entry in legacy) {
      final legacyKey = entry[0];
      final provider = entry[1];
      final label = entry[2];
      final secret = await _readLegacySecret(prefs, legacyKey);
      if (secret == null || secret.isEmpty) continue;
      pending.add((
        info: TokenInfo(
          id: _newId(),
          provider: provider,
          label: label,
          scope: '',
        ),
        legacyKey: legacyKey,
        secret: secret,
      ));
    }

    if (pending.isEmpty) {
      // Nothing to migrate — mark migration complete.
      await _persist(prefs, const []);
      return <TokenInfo>[];
    }

    // Phase 2: write all secrets first. If any write fails (e.g. secure
    // storage is temporarily unavailable), abort WITHOUT persisting the
    // `tokens` marker or deleting legacy values, so the whole migration is
    // retried on the next launch rather than silently losing tokens.
    try {
      for (final item in pending) {
        await _secure.write(
          key: _secretPrefix + item.info.id,
          value: item.secret,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Token migration aborted (secure storage unavailable): $e');
      }
      return <TokenInfo>[];
    }

    // Phase 3: persist metadata, then clean up legacy copies.
    final migrated = pending.map((p) => p.info).toList();
    await _persist(prefs, migrated);
    for (final item in pending) {
      try {
        await _secure.delete(key: item.legacyKey);
      } catch (_) {
        // Best-effort cleanup of the legacy secure entry.
      }
      await prefs.remove(item.legacyKey);
    }
    return migrated;
  }

  static Future<String?> _readLegacySecret(
    SharedPreferences prefs,
    String key,
  ) async {
    try {
      final secure = await _secure.read(key: key);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {
      // Fall back to the plaintext value below.
    }
    final plain = prefs.getString(key);
    if (plain != null && plain.isNotEmpty) return plain;
    return null;
  }
}
