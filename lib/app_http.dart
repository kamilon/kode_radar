import 'api_cache.dart';

/// App-wide HTTP client with ETag caching + rate-limit awareness.
///
/// It lives for the whole app lifetime (never closed) so its response cache and
/// rate-limit state are shared across every page that fetches from GitHub/ADO.
class AppHttp {
  AppHttp._();

  static final CachedHttpClient client = CachedHttpClient();
}
