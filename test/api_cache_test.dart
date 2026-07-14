import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kode_radar/api_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('caches a 200 with an ETag and serves cached body for 304', () async {
    var calls = 0;
    final ifNoneMatchHeaders = <String?>[];
    final inner = MockClient((request) async {
      calls++;
      ifNoneMatchHeaders.add(request.headers['If-None-Match']);
      if (calls == 1) {
        return http.Response(
          '{"value":1}',
          200,
          headers: {
            'etag': '"v1"',
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      return http.Response('', 304);
    });
    final client = CachedHttpClient(inner: inner);
    addTearDown(client.close);

    final uri = Uri.parse('https://api.github.com/repos/acme/api/pulls');
    final first = await client.get(uri);
    final second = await client.get(uri);

    expect(first.statusCode, 200);
    expect(first.body, '{"value":1}');
    expect(calls, 2);
    expect(ifNoneMatchHeaders, [null, '"v1"']);
    expect(second.statusCode, 200);
    expect(second.body, '{"value":1}');
    expect(second.headers['content-type'], 'application/json; charset=utf-8');
  });

  test('exhausted rate limit serves a cached GET response', () async {
    var calls = 0;
    final resetSeconds = DateTime.utc(2100).millisecondsSinceEpoch ~/
        Duration.millisecondsPerSecond;
    final inner = MockClient((_) async {
      calls++;
      return http.Response(
        'cached body',
        200,
        headers: {
          'etag': '"rate"',
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '$resetSeconds',
        },
      );
    });
    final client = CachedHttpClient(inner: inner);
    addTearDown(client.close);

    final uri = Uri.parse('https://api.github.com/repos/acme/api/pulls');
    final first = await client.get(uri);
    final second = await client.get(uri);

    expect(first.body, 'cached body');
    expect(second.statusCode, 200);
    expect(second.body, 'cached body');
    expect(calls, 1);
    expect(client.githubRateLimit.remaining, 0);
    expect(client.githubRateLimit.resetAt, DateTime.utc(2100));
  });

  test('an exhausted GitHub scope does not gate other hosts (Azure DevOps)',
      () async {
    final resetSeconds = DateTime.utc(2100).millisecondsSinceEpoch ~/
        Duration.millisecondsPerSecond;
    var adoCalls = 0;
    final inner = MockClient((request) async {
      if (request.url.host == 'api.github.com') {
        return http.Response('gh', 200, headers: {
          'etag': '"gh"',
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '$resetSeconds',
        });
      }
      adoCalls++;
      return http.Response('ado', 200);
    });
    final client = CachedHttpClient(inner: inner);
    addTearDown(client.close);

    // Exhaust the GitHub scope.
    await client.get(Uri.parse('https://api.github.com/repos/acme/api/pulls'));
    // Azure DevOps must still reach the network (not gated by GitHub's limit).
    final adoResponse = await client.get(Uri.parse(
        'https://dev.azure.com/org/proj/_apis/git/repositories/r/pullrequests'));

    expect(adoResponse.statusCode, 200);
    expect(adoResponse.body, 'ado');
    expect(adoCalls, 1);
  });

  test('parseRateLimit parses GitHub rate limit headers', () {
    final resetAt = DateTime.utc(2026, 7, 14, 8, 30);
    final resetSeconds =
        resetAt.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

    final status = parseRateLimit({
      'X-RateLimit-Remaining': '0',
      'x-ratelimit-reset': '$resetSeconds',
      'Retry-After': '45',
    });

    expect(status.remaining, 0);
    expect(status.resetAt, resetAt);
    expect(status.retryAfter, const Duration(seconds: 45));
  });
}
