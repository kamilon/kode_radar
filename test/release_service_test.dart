import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/release_service.dart';
import 'package:kode_radar/repo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 3, 1);

  group('releasesFromGithub', () {
    test('keeps in-window dated releases, tagged with the repo', () {
      final body = jsonDecode('''
      [
        {"tag_name":"v2.0","name":"Two","published_at":"2026-02-20T00:00:00Z",
         "author":{"login":"alice"},"html_url":"https://gh/r/v2"},
        {"tag_name":"v1.0","name":"One","published_at":"2025-10-01T00:00:00Z"}
      ]
      ''');
      final items = ReleaseService.releasesFromGithub(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
        now: now,
      );
      // v1.0 is >90 days old → dropped.
      expect(items, hasLength(1));
      expect(items.single.tag, 'v2.0');
      expect(items.single.repoKey, 'github:o/r');
      expect(items.single.author, 'alice');
      expect(items.single.publishedAt, DateTime.utc(2026, 2, 20));
    });

    test('drops undated (draft) releases and non-list bodies', () {
      final withDraft = jsonDecode('''
      [
        {"tag_name":"v3.0"},
        {"tag_name":"v2.9","published_at":"2026-02-25T00:00:00Z"}
      ]
      ''');
      final items = ReleaseService.releasesFromGithub(
        withDraft,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
        now: now,
      );
      expect(items.map((r) => r.tag), ['v2.9']);
      expect(
        ReleaseService.releasesFromGithub(
          jsonDecode('{"message":"Not Found"}'),
          repoKey: 'github:o/r',
          repoDisplay: 'o/r',
          now: now,
        ),
        isEmpty,
      );
    });

    test('sortReleases orders newest first, nulls last', () {
      final items = [
        const ReleaseItem(
          repoKey: 'github:o/a',
          repoDisplay: 'o/a',
          tag: 'old',
        ), // null published
        ReleaseItem(
          repoKey: 'github:o/b',
          repoDisplay: 'o/b',
          tag: 'newer',
          publishedAt: DateTime.utc(2026, 2, 28),
        ),
        ReleaseItem(
          repoKey: 'github:o/c',
          repoDisplay: 'o/c',
          tag: 'newest',
          publishedAt: DateTime.utc(2026, 3, 1),
        ),
      ];
      final sorted = ReleaseService.sortReleases(items);
      expect(sorted.map((r) => r.tag), ['newest', 'newer', 'old']);
    });
  });

  group('securityFromGithubAlerts', () {
    test('counts open alerts by severity, ignoring closed/stateless', () {
      final body = jsonDecode('''
      [
        {"state":"open","security_advisory":{"severity":"critical"}},
        {"state":"open","security_advisory":{"severity":"high"}},
        {"state":"open","security_advisory":{"severity":"HIGH"}},
        {"state":"fixed","security_advisory":{"severity":"critical"}},
        {"state":"open","security_vulnerability":{"severity":"medium"}},
        {"security_advisory":{"severity":"high"}},
        {"state":"open"}
      ]
      ''');
      final s = ReleaseService.securityFromGithubAlerts(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      )!;
      expect(s.critical, 1);
      expect(s.high, 2, reason: 'the stateless alert is not assumed open');
      expect(s.medium, 1);
      expect(s.low, 0);
      expect(s.total, 4);
      expect(s.capped, isFalse);
    });

    test('a full alerts page marks the counts capped', () {
      final body = [
        for (var i = 0; i < 100; i++)
          {
            'state': 'open',
            'security_advisory': {'severity': 'low'},
          },
      ];
      final s = ReleaseService.securityFromGithubAlerts(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      )!;
      expect(s.low, 100);
      expect(s.capped, isTrue);
    });

    test('non-list body (e.g. 403 object) → null (unavailable)', () {
      final s = ReleaseService.securityFromGithubAlerts(
        jsonDecode('{"message":"Dependabot alerts are disabled"}'),
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      );
      expect(s, isNull);
    });

    test('empty list → a zero (all-clear) snapshot, not null', () {
      final s = ReleaseService.securityFromGithubAlerts(
        jsonDecode('[]'),
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      );
      expect(s, isNotNull);
      expect(s!.isEmpty, isTrue);
    });
  });

  group('SecurityStats.rankRepos', () {
    RepoSecurity sec(
      String key, {
      int critical = 0,
      int high = 0,
      int medium = 0,
      int low = 0,
    }) => RepoSecurity(
      repoKey: key,
      repoDisplay: key,
      critical: critical,
      high: high,
      medium: medium,
      low: low,
    );

    test('drops clear repos and sorts worst-severity first', () {
      final ranked = SecurityStats.rankRepos([
        sec('github:o/clean'),
        sec('github:o/low', low: 9),
        sec('github:o/crit', critical: 1),
        sec('github:o/high', high: 3),
      ]);
      expect(ranked.map((r) => r.repoKey), [
        'github:o/crit', // any critical outranks
        'github:o/high',
        'github:o/low',
      ]);
    });

    test('a single critical outranks many highs', () {
      final ranked = SecurityStats.rankRepos([
        sec('github:o/manyhigh', high: 100),
        sec('github:o/onecrit', critical: 1),
      ]);
      expect(ranked.first.repoKey, 'github:o/onecrit');
    });
  });

  group('computeAll', () {
    test(
      'malformed monitored entries count toward releasesFailedRepos',
      () async {
        SharedPreferences.setMockInitialValues({
          RepoStore.githubKey: <String>['not json', '{"owner":"o"}'],
        });
        final result = await ReleaseService.computeAll(now: now);
        expect(result.releases, isEmpty);
        expect(result.security, isEmpty);
        expect(result.releasesFailedRepos, 2);
        expect(result.securityUnavailableRepos, 2);
      },
    );
  });
}
