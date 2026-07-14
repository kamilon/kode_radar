import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CachedHttpClient extends http.BaseClient {
  CachedHttpClient({http.Client? inner, ResponseCache? cache})
      : _inner = inner ?? http.Client(),
        _cache = cache ?? ResponseCache();

  final http.Client _inner;
  final ResponseCache _cache;
  final Map<String, RateLimitStatus> _rateLimits = <String, RateLimitStatus>{};

  /// Worst-case merged GitHub rate-limit view across api.github.com token
  /// scopes (lowest remaining, latest reset, largest retry-after).
  RateLimitStatus get githubRateLimit {
    int? remaining;
    DateTime? resetAt;
    Duration? retryAfter;
    for (final entry in _rateLimits.entries) {
      if (!entry.key.startsWith('api.github.com|')) continue;
      final status = entry.value;
      if (status.remaining != null &&
          (remaining == null || status.remaining! < remaining)) {
        remaining = status.remaining;
      }
      if (status.resetAt != null &&
          (resetAt == null || status.resetAt!.isAfter(resetAt))) {
        resetAt = status.resetAt;
      }
      if (status.retryAfter != null &&
          (retryAfter == null || status.retryAfter! > retryAfter)) {
        retryAfter = status.retryAfter;
      }
    }
    return RateLimitStatus(
      remaining: remaining,
      resetAt: resetAt,
      retryAfter: retryAfter,
    );
  }

  String _scopeKey(http.BaseRequest request) {
    final authorization = _headerValue(request.headers, 'authorization');
    final scope = authorization == null || authorization.isEmpty
        ? ''
        : _stableHash(authorization);
    return '${request.url.host}|$scope';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final scopeKey = _scopeKey(request);
    if (request.method.toUpperCase() != 'GET') {
      final response = await _inner.send(request);
      _updateRateLimit(scopeKey, response.headers);
      return response;
    }

    final key = cacheKey(request);
    final cached = await _cache.get(key);
    if (shouldUseCachedResponseForRateLimit(
      _rateLimits[scopeKey] ?? const RateLimitStatus(),
      DateTime.now().toUtc(),
    )) {
      if (cached != null) {
        return _streamedFromCached(cached, request);
      }
      return _streamedText(
        'Rate limit exceeded and no cached response is available.',
        429,
        request,
        reasonPhrase: 'Too Many Requests',
      );
    }

    if (cached != null && cached.etag.isNotEmpty) {
      request.headers['If-None-Match'] = cached.etag;
    }

    final response = await _inner.send(request);
    _updateRateLimit(scopeKey, response.headers);
    final bytes = await response.stream.toBytes();

    if (response.statusCode == 304 && cached != null) {
      return _streamedFromCached(cached, request, statusCode: 200);
    }

    if (response.statusCode == 200) {
      final etag = _headerValue(response.headers, 'etag');
      if (etag != null && etag.isNotEmpty) {
        await _cache.put(
          key,
          CachedResponse(
            etag: etag,
            body: utf8.decode(bytes, allowMalformed: true),
            statusCode: 200,
            storedAt: DateTime.now().toUtc(),
            headers: response.headers,
          ),
        );
      }
    }

    return _streamedFromBytes(
      bytes,
      response.statusCode,
      request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
  }

  void _updateRateLimit(String scopeKey, Map<String, String> headers) {
    var parsed = parseRateLimit(headers);
    if (!parsed.hasValues) return;
    if (parsed.retryAfter != null) {
      // Secondary rate limit (e.g. a 403 with Retry-After): back off until
      // now + Retry-After by modelling it as an exhausted window.
      final retryUntil = DateTime.now().toUtc().add(parsed.retryAfter!);
      parsed = RateLimitStatus(
        remaining: 0,
        resetAt: retryUntil,
        retryAfter: parsed.retryAfter,
      );
    }
    _rateLimits[scopeKey] = _mergeRateLimit(_rateLimits[scopeKey], parsed);
  }

  /// Conservatively merges a rate-limit [update] into the [existing] state so
  /// out-of-order concurrent responses can't inflate the remaining budget. A
  /// strictly newer window (later resetAt) replaces the old values; otherwise
  /// we keep the lowest remaining, latest reset, and longest retry-after.
  static RateLimitStatus _mergeRateLimit(
    RateLimitStatus? existing,
    RateLimitStatus update,
  ) {
    if (existing == null) return update;
    final existingReset = existing.resetAt;
    final updateReset = update.resetAt;
    if (existingReset != null &&
        updateReset != null &&
        updateReset.isAfter(existingReset)) {
      return update; // new window
    }
    int? remaining;
    if (existing.remaining != null && update.remaining != null) {
      remaining = existing.remaining! < update.remaining!
          ? existing.remaining
          : update.remaining;
    } else {
      remaining = update.remaining ?? existing.remaining;
    }
    DateTime? resetAt = existing.resetAt;
    if (updateReset != null &&
        (resetAt == null || updateReset.isAfter(resetAt))) {
      resetAt = updateReset;
    }
    Duration? retryAfter = existing.retryAfter;
    if (update.retryAfter != null &&
        (retryAfter == null || update.retryAfter! > retryAfter)) {
      retryAfter = update.retryAfter;
    }
    return RateLimitStatus(
      remaining: remaining,
      resetAt: resetAt,
      retryAfter: retryAfter,
    );
  }
}

/// In-memory (per-isolate) response cache. Bodies are never persisted to disk,
/// so private-repo data is never written unencrypted and cache hits incur no
/// disk writes. The cache resets on app restart (a within-session cache is what
/// matters for rate-limit relief).
class ResponseCache {
  static const int maxEntries = 200;

  final Map<String, CachedResponse> _entries = <String, CachedResponse>{};

  Future<CachedResponse?> get(String key) async {
    final cached = _entries[key];
    if (cached == null) return null;
    final touched = cached.copyWith(lastUsed: DateTime.now().toUtc());
    _entries[key] = touched;
    return touched;
  }

  Future<void> put(String key, CachedResponse resp) async {
    _entries[key] = resp.copyWith(lastUsed: DateTime.now().toUtc());
    _evictOldEntries(_entries);
  }

  void _evictOldEntries(Map<String, CachedResponse> entries) {
    if (entries.length <= maxEntries) return;
    final newest = entries.entries.toList()
      ..sort((a, b) => b.value.lastUsed.compareTo(a.value.lastUsed));
    entries
      ..clear()
      ..addEntries(newest.take(maxEntries));
  }
}

class CachedResponse {
  CachedResponse({
    required this.etag,
    required this.body,
    required this.statusCode,
    required this.storedAt,
    DateTime? lastUsed,
    Map<String, String> headers = const <String, String>{},
  })  : lastUsed = lastUsed ?? storedAt,
        headers = Map.unmodifiable(headers);

  final String etag;
  final String body;
  final int statusCode;
  final DateTime storedAt;
  final DateTime lastUsed;
  final Map<String, String> headers;

  CachedResponse copyWith({
    String? etag,
    String? body,
    int? statusCode,
    DateTime? storedAt,
    DateTime? lastUsed,
    Map<String, String>? headers,
  }) {
    return CachedResponse(
      etag: etag ?? this.etag,
      body: body ?? this.body,
      statusCode: statusCode ?? this.statusCode,
      storedAt: storedAt ?? this.storedAt,
      lastUsed: lastUsed ?? this.lastUsed,
      headers: headers ?? this.headers,
    );
  }
}

class RateLimitStatus {
  const RateLimitStatus({
    this.remaining,
    this.resetAt,
    this.retryAfter,
  });

  final int? remaining;
  final DateTime? resetAt;
  final Duration? retryAfter;

  bool get hasValues =>
      remaining != null || resetAt != null || retryAfter != null;

  RateLimitStatus merge(RateLimitStatus update) {
    return RateLimitStatus(
      remaining: update.remaining ?? remaining,
      resetAt: update.resetAt ?? resetAt,
      retryAfter: update.retryAfter ?? retryAfter,
    );
  }
}

RateLimitStatus parseRateLimit(Map<String, String> headers) {
  final remaining = int.tryParse(
    _headerValue(headers, 'x-ratelimit-remaining')?.trim() ?? '',
  );
  final resetSeconds = int.tryParse(
    _headerValue(headers, 'x-ratelimit-reset')?.trim() ?? '',
  );
  final retryAfterSeconds = int.tryParse(
    _headerValue(headers, 'retry-after')?.trim() ?? '',
  );

  return RateLimitStatus(
    remaining: remaining,
    resetAt: resetSeconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            resetSeconds * 1000,
            isUtc: true,
          ),
    retryAfter:
        retryAfterSeconds == null ? null : Duration(seconds: retryAfterSeconds),
  );
}

bool shouldUseCachedResponseForRateLimit(
  RateLimitStatus status,
  DateTime now,
) {
  final resetAt = status.resetAt;
  return status.remaining == 0 && resetAt != null && resetAt.isAfter(now);
}

String cacheKey(http.BaseRequest request) {
  final authorization = _headerValue(request.headers, 'authorization');
  final authScope = authorization == null || authorization.isEmpty
      ? ''
      : ' auth=${_stableHash(authorization)}';
  return '${request.method} ${request.url}$authScope';
}

http.StreamedResponse _streamedFromCached(
    CachedResponse cached, http.BaseRequest request,
    {int? statusCode}) {
  final bytes = utf8.encode(cached.body);
  final headers = Map<String, String>.from(cached.headers);
  headers.putIfAbsent('etag', () => cached.etag);
  final effectiveStatusCode = statusCode ?? cached.statusCode;
  return _streamedFromBytes(
    bytes,
    effectiveStatusCode,
    request,
    headers: headers,
    reasonPhrase: effectiveStatusCode == 200 ? 'OK' : null,
  );
}

http.StreamedResponse _streamedText(
  String body,
  int statusCode,
  http.BaseRequest request, {
  String? reasonPhrase,
}) {
  final bytes = utf8.encode(body);
  return _streamedFromBytes(
    bytes,
    statusCode,
    request,
    headers: const {'content-type': 'text/plain; charset=utf-8'},
    reasonPhrase: reasonPhrase,
  );
}

http.StreamedResponse _streamedFromBytes(
  List<int> bytes,
  int statusCode,
  http.BaseRequest request, {
  Map<String, String> headers = const <String, String>{},
  bool isRedirect = false,
  bool persistentConnection = true,
  String? reasonPhrase,
}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    contentLength: bytes.length,
    request: request,
    headers: headers,
    isRedirect: isRedirect,
    persistentConnection: persistentConnection,
    reasonPhrase: reasonPhrase,
  );
}

String? _headerValue(Map<String, String> headers, String name) {
  final lowerName = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == lowerName) return entry.value;
  }
  return null;
}

String _stableHash(String value) {
  // 64-bit FNV-1a (via BigInt to stay exact on all platforms) so auth-scope
  // collisions are negligible and token-scoped cache isolation holds.
  final mask = (BigInt.one << 64) - BigInt.one;
  final prime = BigInt.parse('1099511628211'); // 0x100000001b3
  var hash = BigInt.parse('14695981039346656037'); // 0xcbf29ce484222325
  for (final codeUnit in value.codeUnits) {
    hash = (hash ^ BigInt.from(codeUnit)) & mask;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
