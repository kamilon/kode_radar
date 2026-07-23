import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/cycle_time_service.dart';

void main() {
  group('parseGithubGraphqlMergedPulls', () {
    test('maps nodes and derives first-review from earliest submission', () {
      final body = jsonDecode('''
      {"data":{"repository":{"pullRequests":{"nodes":[
        {"number":10,"title":"Add feature","url":"https://gh/pr/10",
         "createdAt":"2026-01-10T00:00:00Z","mergedAt":"2026-01-10T06:00:00Z",
         "author":{"login":"alice"},
         "reviews":{"nodes":[
           {"submittedAt":"2026-01-10T04:00:00Z","state":"COMMENTED","author":{"login":"bob"}},
           {"submittedAt":"2026-01-10T02:00:00Z","state":"APPROVED","author":{"login":"carol"}}
         ]}}
      ]}}}}
      ''');
      final samples = CycleTimeService.parseGithubGraphqlMergedPulls(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      );
      expect(samples, hasLength(1));
      final s = samples.single;
      expect(s.prKey, 'github:o/r:10');
      expect(s.provider, 'github');
      expect(s.createdAt, DateTime.utc(2026, 1, 10, 0));
      expect(s.mergedAt, DateTime.utc(2026, 1, 10, 6));
      expect(s.firstReviewAt, DateTime.utc(2026, 1, 10, 2));
      expect(s.author, 'alice');
      expect(s.title, 'Add feature');
      expect(s.url, 'https://gh/pr/10');
    });

    test('ignores reviews authored by the PR author', () {
      final body = jsonDecode('''
      {"data":{"repository":{"pullRequests":{"nodes":[
        {"number":11,"title":"Self","url":"https://gh/pr/11",
         "createdAt":"2026-01-10T00:00:00Z","mergedAt":"2026-01-10T06:00:00Z",
         "author":{"login":"alice"},
         "reviews":{"nodes":[
           {"submittedAt":"2026-01-10T01:00:00Z","state":"COMMENTED","author":{"login":"alice"}},
           {"submittedAt":"2026-01-10T05:00:00Z","state":"APPROVED","author":{"login":"bob"}}
         ]}}
      ]}}}}
      ''');
      final s = CycleTimeService.parseGithubGraphqlMergedPulls(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      ).single;
      // alice's own review is skipped; first real review is bob's at 05:00.
      expect(s.firstReviewAt, DateTime.utc(2026, 1, 10, 5));
    });

    test('ignores pending drafts and reviews submitted after the merge', () {
      final body = jsonDecode('''
      {"data":{"repository":{"pullRequests":{"nodes":[
        {"number":15,"title":"Late","url":"https://gh/pr/15",
         "createdAt":"2026-01-10T00:00:00Z","mergedAt":"2026-01-10T06:00:00Z",
         "author":{"login":"alice"},
         "reviews":{"nodes":[
           {"submittedAt":null,"state":"PENDING","author":{"login":"bob"}},
           {"submittedAt":"2026-01-10T03:00:00Z","state":"PENDING","author":{"login":"carol"}},
           {"submittedAt":"2026-01-10T09:00:00Z","state":"APPROVED","author":{"login":"dave"}},
           {"submittedAt":"2026-01-10T05:00:00Z","state":"CHANGES_REQUESTED","author":{"login":"erin"}}
         ]}}
      ]}}}}
      ''');
      final s = CycleTimeService.parseGithubGraphqlMergedPulls(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      ).single;
      // null/PENDING drafts skipped; dave's 09:00 is after merge (06:00) and
      // skipped; the earliest qualifying submission is erin's at 05:00.
      expect(s.firstReviewAt, DateTime.utc(2026, 1, 10, 5));
    });

    test('null first-review when there are no qualifying reviews', () {
      final body = jsonDecode('''
      {"data":{"repository":{"pullRequests":{"nodes":[
        {"number":12,"title":"No review","url":"https://gh/pr/12",
         "createdAt":"2026-01-10T00:00:00Z","mergedAt":"2026-01-11T00:00:00Z",
         "author":{"login":"alice"},
         "reviews":{"nodes":[]}}
      ]}}}}
      ''');
      final s = CycleTimeService.parseGithubGraphqlMergedPulls(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      ).single;
      expect(s.firstReviewAt, isNull);
    });

    test('skips PRs missing number or timestamps', () {
      final body = jsonDecode('''
      {"data":{"repository":{"pullRequests":{"nodes":[
        {"title":"no number","createdAt":"2026-01-10T00:00:00Z",
         "mergedAt":"2026-01-11T00:00:00Z"},
        {"number":13,"title":"no merged","createdAt":"2026-01-10T00:00:00Z"},
        {"number":14,"title":"ok","createdAt":"2026-01-10T00:00:00Z",
         "mergedAt":"2026-01-11T00:00:00Z","author":{"login":"x"},
         "reviews":{"nodes":[]}}
      ]}}}}
      ''');
      final samples = CycleTimeService.parseGithubGraphqlMergedPulls(
        body,
        repoKey: 'github:o/r',
        repoDisplay: 'o/r',
      );
      expect(samples.map((s) => s.prKey), ['github:o/r:14']);
    });

    test('malformed response yields empty list', () {
      expect(
        CycleTimeService.parseGithubGraphqlMergedPulls(
          jsonDecode('{"data":{"repository":null}}'),
          repoKey: 'github:o/r',
          repoDisplay: 'o/r',
        ),
        isEmpty,
      );
    });
  });

  group('parseAdoMergedPulls', () {
    test('maps completed PRs with a null first-review time', () {
      final body = jsonDecode('''
      {"value":[
        {"pullRequestId":42,"title":"ADO PR","status":"completed",
         "creationDate":"2026-01-10T00:00:00Z","closedDate":"2026-01-12T00:00:00Z",
         "createdBy":{"displayName":"Dana"}}
      ]}
      ''');
      final s = CycleTimeService.parseAdoMergedPulls(
        body,
        repoKey: 'ado:org/proj/repo',
        repoDisplay: 'org/proj/repo',
        organization: 'org',
        project: 'proj',
        name: 'repo',
      ).single;
      expect(s.prKey, 'ado:org/proj/repo:42');
      expect(s.provider, 'ado');
      expect(s.firstReviewAt, isNull);
      expect(s.timeToMergeMs, const Duration(days: 2).inMilliseconds);
      expect(s.author, 'Dana');
      expect(s.url, 'https://dev.azure.com/org/proj/_git/repo/pullrequest/42');
    });

    test('skips non-completed and timestamp-less PRs', () {
      final body = jsonDecode('''
      {"value":[
        {"pullRequestId":1,"status":"active",
         "creationDate":"2026-01-10T00:00:00Z","closedDate":"2026-01-12T00:00:00Z"},
        {"pullRequestId":2,"status":"completed",
         "creationDate":"2026-01-10T00:00:00Z"},
        {"pullRequestId":3,"status":"completed",
         "creationDate":"2026-01-10T00:00:00Z","closedDate":"2026-01-11T00:00:00Z"}
      ]}
      ''');
      final samples = CycleTimeService.parseAdoMergedPulls(
        body,
        repoKey: 'ado:org/proj/repo',
        repoDisplay: 'org/proj/repo',
        organization: 'org',
        project: 'proj',
        name: 'repo',
      );
      expect(samples.map((s) => s.prKey), ['ado:org/proj/repo:3']);
    });
  });
}
