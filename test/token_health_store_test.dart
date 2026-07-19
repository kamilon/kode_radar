import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/api_cache.dart';
import 'package:kode_radar/token_health_service.dart';
import 'package:kode_radar/token_health_store.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'records and reads back a check with its account and timestamp',
    () async {
      final now = DateTime.utc(2026, 7, 15, 12);
      await TokenHealthStore.record(
        'tok-1',
        const TokenCheck(TokenHealth.valid, account: 'octocat'),
        now: now,
      );

      final all = await TokenHealthStore.all();
      expect(all.keys, ['tok-1']);
      expect(all['tok-1']!.health, TokenHealth.valid);
      expect(all['tok-1']!.account, 'octocat');
      expect(all['tok-1']!.checkedAt, now);
    },
  );

  test('record overwrites the previous result for the same token', () async {
    await TokenHealthStore.record(
      'tok-1',
      const TokenCheck(TokenHealth.valid, account: 'octocat'),
      now: DateTime.utc(2026, 1, 1),
    );
    await TokenHealthStore.record(
      'tok-1',
      const TokenCheck(TokenHealth.invalid, message: 'nope'),
      now: DateTime.utc(2026, 2, 1),
    );

    final all = await TokenHealthStore.all();
    expect(all['tok-1']!.health, TokenHealth.invalid);
    expect(all['tok-1']!.message, 'nope');
    expect(all['tok-1']!.account, isNull);
  });

  test('remove drops only the given token', () async {
    await TokenHealthStore.record(
      'a',
      const TokenCheck(TokenHealth.valid, account: 'x'),
    );
    await TokenHealthStore.record(
      'b',
      const TokenCheck(TokenHealth.error, message: 'oops'),
    );

    await TokenHealthStore.remove('a');
    final all = await TokenHealthStore.all();
    expect(all.keys, ['b']);
  });

  test('malformed stored entries are skipped, not thrown', () {
    final good = StoredTokenCheck.fromJson({
      'health': 'valid',
      'checkedAt': 123,
      'account': 'x',
    });
    expect(good, isNotNull);
    expect(good!.health, TokenHealth.valid);

    // Unknown health, missing/invalid timestamp, and non-maps are dropped.
    expect(
      StoredTokenCheck.fromJson({'health': 'bogus', 'checkedAt': 1}),
      isNull,
    );
    expect(StoredTokenCheck.fromJson({'health': 'valid'}), isNull);
    expect(
      StoredTokenCheck.fromJson({'health': 'valid', 'checkedAt': 'nope'}),
      isNull,
    );
    expect(StoredTokenCheck.fromJson('not-a-map'), isNull);
  });

  test(
    'an out-of-range timestamp is skipped, not fatal to other entries',
    () async {
      // fromJson must not throw on an int beyond DateTime's supported range.
      expect(
        StoredTokenCheck.fromJson({
          'health': 'valid',
          'checkedAt': 9000000000000000000,
        }),
        isNull,
      );

      // A corrupt entry alongside a good one must not discard the good one.
      SharedPreferences.setMockInitialValues({
        'token_health': jsonEncode({
          'good': {'health': 'valid', 'checkedAt': 123, 'account': 'x'},
          'bad': {'health': 'valid', 'checkedAt': 9000000000000000000},
        }),
      });
      final all = await TokenHealthStore.all();
      expect(all.keys, ['good']);
    },
  );

  test('all() returns empty on a fresh store', () async {
    expect(await TokenHealthStore.all(), isEmpty);
  });

  test('persists and reads back the rate-limit budget', () async {
    final now = DateTime.utc(2026, 7, 15, 12);
    final reset = DateTime.utc(2026, 7, 15, 12, 41);
    await TokenHealthStore.record(
      'tok-1',
      const TokenCheck(
        TokenHealth.valid,
        account: 'octocat',
      ).withRateLimit(RateLimitStatus(remaining: 4823, resetAt: reset)),
      now: now,
    );

    final all = await TokenHealthStore.all();
    expect(all['tok-1']!.rateLimitRemaining, 4823);
    expect(all['tok-1']!.rateLimitResetAt, reset);
  });

  test('StoredTokenCheck JSON round-trips the rate-limit fields', () {
    final reset = DateTime.utc(2026, 7, 15, 12, 41);
    final original = StoredTokenCheck(
      health: TokenHealth.valid,
      checkedAt: DateTime.utc(2026, 7, 15, 12),
      account: 'octocat',
      rateLimitRemaining: 12,
      rateLimitResetAt: reset,
    );

    final restored = StoredTokenCheck.fromJson(
      jsonDecode(jsonEncode(original.toJson())),
    );
    expect(restored, isNotNull);
    expect(restored!.rateLimitRemaining, 12);
    expect(restored.rateLimitResetAt, reset);
  });

  test('a check without a rate-limit stores null budget fields', () async {
    await TokenHealthStore.record(
      'tok-1',
      const TokenCheck(TokenHealth.valid, account: 'octocat'),
    );
    final all = await TokenHealthStore.all();
    expect(all['tok-1']!.rateLimitRemaining, isNull);
    expect(all['tok-1']!.rateLimitResetAt, isNull);
  });
}
