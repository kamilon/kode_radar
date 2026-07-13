import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/attention_service.dart';

void main() {
  final now = DateTime.parse('2026-07-13T12:00:00Z');
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  test('GitHub: individual reviewer request -> reviewRequested', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 12,
          'title': 'Add feature',
          'user': {'login': 'alice'},
          'created_at': daysAgo(3).toIso8601String(),
          'html_url': 'https://github.com/acme/api/pull/12',
          'requested_reviewers': [
            {'login': 'bob'}
          ],
        },
      ],
    );
    expect(items.single.category, 'reviewRequested');
    expect(items.single.title, 'PR #12 waiting on review');
    expect(items.single.url, 'https://github.com/acme/api/pull/12');
    expect(items.single.ageDays, 3);
  });

  test('GitHub: team review request (no individual) -> reviewRequested', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 20,
          'title': 'Team review',
          'user': {'login': 'alice'},
          'created_at': daysAgo(1).toIso8601String(),
          'requested_reviewers': [],
          'requested_teams': [
            {'slug': 'platform'}
          ],
        },
      ],
    );
    expect(items.single.category, 'reviewRequested');
  });

  test('GitHub: old PR with no pending review -> oldOpenPr; fresh -> nothing',
      () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 1,
          'title': 'Old',
          'user': {'login': 'alice'},
          'created_at': daysAgo(40).toIso8601String(),
          'requested_reviewers': [],
        },
        {
          'number': 2,
          'title': 'Fresh',
          'user': {'login': 'alice'},
          'created_at': daysAgo(1).toIso8601String(),
          'requested_reviewers': [],
        },
      ],
    );
    expect(items.length, 1);
    expect(items.single.category, 'oldOpenPr');
    expect(items.single.title, 'PR #1 open for 40 days');
  });

  test('GitHub: draft PRs are ignored', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 3,
          'title': 'WIP',
          'draft': true,
          'user': {'login': 'alice'},
          'created_at': daysAgo(30).toIso8601String(),
          'requested_reviewers': [
            {'login': 'bob'}
          ],
        },
      ],
    );
    expect(items, isEmpty);
  });

  test('category dominates age: old oldOpenPr never outranks a fresh review',
      () {
    final review = AttentionService.githubItems(
      repoDisplay: 'r',
      now: now,
      prs: [
        {
          'number': 1,
          'title': 't',
          'user': {'login': 'a'},
          'created_at': daysAgo(0).toIso8601String(),
          'requested_reviewers': [
            {'login': 'b'}
          ],
        },
      ],
    ).single;
    final oldOpen = AttentionService.githubItems(
      repoDisplay: 'r',
      now: now,
      prs: [
        {
          'number': 2,
          'title': 't',
          'user': {'login': 'a'},
          'created_at': daysAgo(300).toIso8601String(),
          'requested_reviewers': [],
        },
      ],
    ).single;
    expect(review.severity, greaterThan(oldOpen.severity));
  });

  test('ADO: vote 0 -> reviewRequested; negative vote -> changesRequested', () {
    final waiting = AttentionService.adoItems(
      repoDisplay: 'org/proj/repo',
      organization: 'org',
      project: 'proj',
      name: 'repo',
      now: now,
      prs: [
        {
          'pullRequestId': 42,
          'title': 'Fix',
          'createdBy': {'displayName': 'Carol'},
          'creationDate': daysAgo(5).toIso8601String(),
          'reviewers': [
            {'vote': 0}
          ],
        },
      ],
    ).single;
    expect(waiting.category, 'reviewRequested');
    expect(
        waiting.url, 'https://dev.azure.com/org/proj/_git/repo/pullrequest/42');

    final changes = AttentionService.adoItems(
      repoDisplay: 'org/proj/repo',
      organization: 'org',
      project: 'proj',
      name: 'repo',
      now: now,
      prs: [
        {
          'pullRequestId': 43,
          'title': 'Fix',
          'createdBy': {'displayName': 'Carol'},
          'creationDate': daysAgo(2).toIso8601String(),
          'reviewers': [
            {'vote': -5}
          ],
        },
      ],
    ).single;
    expect(changes.category, 'changesRequested');
    expect(changes.title, 'PR #43 has changes requested');
  });

  test('ADO: all-approved reviewers, old -> oldOpenPr (not review)', () {
    final items = AttentionService.adoItems(
      repoDisplay: 'org/proj/repo',
      organization: 'org',
      project: 'proj',
      name: 'repo',
      now: now,
      prs: [
        {
          'pullRequestId': 44,
          'title': 'Approved',
          'createdBy': {'displayName': 'Carol'},
          'creationDate': daysAgo(30).toIso8601String(),
          'reviewers': [
            {'vote': 10}
          ],
        },
      ],
    );
    expect(items.single.category, 'oldOpenPr');
  });

  test('malformed / non-map PR entries are skipped without throwing', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        'not-a-map',
        {'number': 5},
      ],
    );
    expect(items, isEmpty);
  });
}
