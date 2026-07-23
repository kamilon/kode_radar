import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kode_radar/attention_service.dart';
import 'package:kode_radar/token_store.dart';

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
          'author': {'login': 'alice'},
          'createdAt': daysAgo(3).toIso8601String(),
          'url': 'https://github.com/acme/api/pull/12',
          'reviewDecision': null,
          'reviewRequests': {
            'totalCount': 1,
            'nodes': [
              {
                'requestedReviewer': {'login': 'bob'},
              },
            ],
          },
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
          'author': {'login': 'alice'},
          'createdAt': daysAgo(1).toIso8601String(),
          'reviewDecision': null,
          // A team review request has no reviewer login but still counts.
          'reviewRequests': {
            'totalCount': 1,
            'nodes': [
              {
                'requestedReviewer': {'__typename': 'Team', 'slug': 'platform'},
              },
            ],
          },
        },
      ],
    );
    expect(items.single.category, 'reviewRequested');
  });

  test('GitHub: CHANGES_REQUESTED -> changesRequested', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 33,
          'title': 'Needs work',
          'author': {'login': 'alice'},
          'createdAt': daysAgo(2).toIso8601String(),
          'url': 'https://github.com/acme/api/pull/33',
          'reviewDecision': 'CHANGES_REQUESTED',
          'reviewRequests': {'totalCount': 0, 'nodes': []},
        },
      ],
    );
    expect(items.single.category, 'changesRequested');
    expect(items.single.title, 'PR #33 has changes requested');
  });

  test('GitHub: APPROVED -> nothing unless old (then oldOpenPr)', () {
    List<AttentionItem> approvedAged(int days) => AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 44,
          'title': 'Ready',
          'author': {'login': 'alice'},
          'createdAt': daysAgo(days).toIso8601String(),
          'reviewDecision': 'APPROVED',
          'reviewRequests': {'totalCount': 0, 'nodes': []},
        },
      ],
    );
    expect(approvedAged(2), isEmpty);
    expect(approvedAged(40).single.category, 'oldOpenPr');
  });

  test('GitHub: my APPROVED PR -> approved (ready to merge)', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      selfGithubLogins: {'alice'},
      prs: [
        {
          'number': 44,
          'title': 'Ready',
          'author': {'login': 'alice'},
          'createdAt': daysAgo(2).toIso8601String(),
          'url': 'https://github.com/acme/api/pull/44',
          'reviewDecision': 'APPROVED',
          'reviewRequests': {'totalCount': 0, 'nodes': []},
        },
      ],
    );
    expect(items.single.category, 'approved');
    expect(items.single.isMine, isTrue);
    expect(items.single.title, 'PR #44 approved');
  });

  test(
    'GitHub: my PR approved via review on a null-decision repo -> approved',
    () {
      final items = AttentionService.githubItems(
        repoDisplay: 'acme/api',
        now: now,
        selfGithubLogins: {'alice'},
        prs: [
          {
            'number': 45,
            'title': 'Ready',
            'author': {'login': 'alice'},
            'createdAt': daysAgo(1).toIso8601String(),
            'reviewDecision': null,
            'latestOpinionatedReviews': {
              'nodes': [
                {'state': 'APPROVED'},
              ],
            },
            'reviewRequests': {'totalCount': 0, 'nodes': []},
          },
        ],
      );
      expect(items.single.category, 'approved');
    },
  );

  test('ADO: my approved PR -> approved', () {
    final items = AttentionService.adoItems(
      repoDisplay: 'org/proj/repo',
      organization: 'org',
      project: 'proj',
      name: 'repo',
      now: now,
      selfAdoNames: {'Ada'},
      prs: [
        {
          'pullRequestId': 7,
          'title': 'Ready',
          'createdBy': {'displayName': 'Ada'},
          'creationDate': daysAgo(1).toIso8601String(),
          'reviewers': [
            {'vote': 10, 'displayName': 'Reviewer'},
          ],
        },
      ],
    );
    expect(items.single.category, 'approved');
    expect(items.single.isMine, isTrue);
  });

  test('GitHub: a reviewer (not author) does not get approved', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      selfGithubLogins: {'bob'},
      prs: [
        {
          'number': 46,
          'title': 'Ready',
          'author': {'login': 'alice'},
          'createdAt': daysAgo(1).toIso8601String(),
          'reviewDecision': 'APPROVED',
          'reviewRequests': {
            'totalCount': 1,
            'nodes': [
              {
                'requestedReviewer': {'login': 'bob'},
              },
            ],
          },
        },
      ],
    );
    // Bob is a requested reviewer, not the author -> not "approved".
    expect(items.single.category, isNot('approved'));
  });

  test('ADO: a reviewer (not author) does not get approved', () {
    final items = AttentionService.adoItems(
      repoDisplay: 'org/proj/repo',
      organization: 'org',
      project: 'proj',
      name: 'repo',
      now: now,
      selfAdoNames: {'Bob'},
      prs: [
        {
          'pullRequestId': 8,
          'title': 'Ready',
          'createdBy': {'displayName': 'Ada'},
          'creationDate': daysAgo(1).toIso8601String(),
          'reviewers': [
            {'vote': 10, 'displayName': 'Bob'},
          ],
        },
      ],
    );
    // Bob reviewed (approved) Ada's PR, but isn't the author -> no item.
    expect(items.where((i) => i.category == 'approved'), isEmpty);
  });

  test('GitHub: REVIEW_REQUIRED decision -> reviewRequested', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 55,
          'title': 'Required',
          'author': {'login': 'alice'},
          'createdAt': daysAgo(1).toIso8601String(),
          'reviewDecision': 'REVIEW_REQUIRED',
          'reviewRequests': {'totalCount': 0, 'nodes': []},
        },
      ],
    );
    expect(items.single.category, 'reviewRequested');
  });

  test(
    'GitHub: unprotected repo (null decision) with a changes-requested review '
    '-> changesRequested',
    () {
      final items = AttentionService.githubItems(
        repoDisplay: 'acme/api',
        now: now,
        prs: [
          {
            'number': 66,
            'title': 'No branch protection',
            'author': {'login': 'alice'},
            'createdAt': daysAgo(2).toIso8601String(),
            // reviewDecision is null when the repo has no required reviews.
            'reviewDecision': null,
            'latestOpinionatedReviews': {
              'nodes': [
                {'state': 'CHANGES_REQUESTED'},
              ],
            },
            'reviewRequests': {'totalCount': 0, 'nodes': []},
          },
        ],
      );
      expect(items.single.category, 'changesRequested');
    },
  );

  test(
    'GitHub: changes-requested outranks a pending review on the same PR',
    () {
      final items = AttentionService.githubItems(
        repoDisplay: 'acme/api',
        now: now,
        prs: [
          {
            'number': 77,
            'title': 'Both',
            'author': {'login': 'alice'},
            'createdAt': daysAgo(2).toIso8601String(),
            'reviewDecision': 'CHANGES_REQUESTED',
            'latestOpinionatedReviews': {
              'nodes': [
                {'state': 'CHANGES_REQUESTED'},
              ],
            },
            'reviewRequests': {
              'totalCount': 1,
              'nodes': [
                {
                  'requestedReviewer': {'login': 'bob'},
                },
              ],
            },
          },
        ],
      );
      expect(items.single.category, 'changesRequested');
    },
  );

  test('GitHub: a DISMISSED review is not treated as changes requested', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 99,
          'title': 'Dismissed',
          'author': {'login': 'alice'},
          'createdAt': daysAgo(2).toIso8601String(),
          'reviewDecision': null,
          'latestOpinionatedReviews': {
            'nodes': [
              {'state': 'DISMISSED'},
            ],
          },
          'reviewRequests': {'totalCount': 0, 'nodes': []},
        },
      ],
    );
    expect(items, isEmpty);
  });

  test('GitHub: an approval superseding a change request -> not changes', () {
    // latestOpinionatedReviews already collapses to the author's latest stance,
    // so a later approval means no CHANGES_REQUESTED node remains.
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 88,
          'title': 'Approved after changes',
          'author': {'login': 'alice'},
          'createdAt': daysAgo(2).toIso8601String(),
          'reviewDecision': null,
          'latestOpinionatedReviews': {
            'nodes': [
              {'state': 'APPROVED'},
            ],
          },
          'reviewRequests': {'totalCount': 0, 'nodes': []},
        },
      ],
    );
    expect(items, isEmpty);
  });

  test(
    'GitHub: old PR with no pending review -> oldOpenPr; fresh -> nothing',
    () {
      final items = AttentionService.githubItems(
        repoDisplay: 'acme/api',
        now: now,
        prs: [
          {
            'number': 1,
            'title': 'Old',
            'author': {'login': 'alice'},
            'createdAt': daysAgo(40).toIso8601String(),
            'reviewDecision': null,
            'reviewRequests': {'totalCount': 0, 'nodes': []},
          },
          {
            'number': 2,
            'title': 'Fresh',
            'author': {'login': 'alice'},
            'createdAt': daysAgo(1).toIso8601String(),
            'reviewDecision': null,
            'reviewRequests': {'totalCount': 0, 'nodes': []},
          },
        ],
      );
      expect(items.length, 1);
      expect(items.single.category, 'oldOpenPr');
      expect(items.single.title, 'PR #1 open for 40 days');
    },
  );

  test('GitHub: draft PRs are ignored', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 3,
          'title': 'WIP',
          'isDraft': true,
          'author': {'login': 'alice'},
          'createdAt': daysAgo(30).toIso8601String(),
          'reviewDecision': null,
          'reviewRequests': {
            'totalCount': 1,
            'nodes': [
              {
                'requestedReviewer': {'login': 'bob'},
              },
            ],
          },
        },
      ],
    );
    expect(items, isEmpty);
  });

  test(
    'category dominates age: old oldOpenPr never outranks a fresh review',
    () {
      final review = AttentionService.githubItems(
        repoDisplay: 'r',
        now: now,
        prs: [
          {
            'number': 1,
            'title': 't',
            'author': {'login': 'a'},
            'createdAt': daysAgo(0).toIso8601String(),
            'reviewDecision': null,
            'reviewRequests': {
              'totalCount': 1,
              'nodes': [
                {
                  'requestedReviewer': {'login': 'b'},
                },
              ],
            },
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
            'author': {'login': 'a'},
            'createdAt': daysAgo(300).toIso8601String(),
            'reviewDecision': null,
            'reviewRequests': {'totalCount': 0, 'nodes': []},
          },
        ],
      ).single;
      expect(review.severity, greaterThan(oldOpen.severity));
    },
  );

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
            {'vote': 0},
          ],
        },
      ],
    ).single;
    expect(waiting.category, 'reviewRequested');
    expect(
      waiting.url,
      'https://dev.azure.com/org/proj/_git/repo/pullrequest/42',
    );

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
            {'vote': -5},
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
            {'vote': 10},
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

  test('non-string title/user/url fields fall back instead of throwing', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      prs: [
        {
          'number': 9,
          'title': 123,
          'author': {'login': 42},
          'createdAt': daysAgo(2).toIso8601String(),
          'reviewDecision': null,
          'reviewRequests': {
            'totalCount': 1,
            'nodes': [
              {
                'requestedReviewer': {'login': 'bob'},
              },
            ],
          },
          'url': 99,
        },
      ],
    );
    expect(items.single.category, 'reviewRequested');
    expect(items.single.title, 'PR #9 waiting on review');
    expect(items.single.url, isNull);
  });

  test('githubItems tags isMine for the self login (author or reviewer)', () {
    final items = AttentionService.githubItems(
      repoDisplay: 'acme/api',
      now: now,
      selfGithubLogins: {'Me'},
      prs: [
        {
          'number': 1,
          'title': 't',
          'author': {'login': 'alice'},
          'createdAt': daysAgo(1).toIso8601String(),
          'reviewDecision': null,
          'reviewRequests': {
            'totalCount': 1,
            'nodes': [
              {
                'requestedReviewer': {'login': 'me'},
              },
            ],
          },
        },
        {
          'number': 2,
          'title': 't',
          'author': {'login': 'me'},
          'createdAt': daysAgo(40).toIso8601String(),
          'reviewDecision': null,
          'reviewRequests': {'totalCount': 0, 'nodes': []},
        },
        {
          'number': 3,
          'title': 't',
          'author': {'login': 'bob'},
          'createdAt': daysAgo(1).toIso8601String(),
          'reviewDecision': null,
          'reviewRequests': {
            'totalCount': 1,
            'nodes': [
              {
                'requestedReviewer': {'login': 'carol'},
              },
            ],
          },
        },
      ],
    );
    final byId = {for (final i in items) i.id: i};
    expect(byId['reviewRequested:acme/api:PR #1']!.isMine, isTrue);
    expect(byId['oldOpenPr:acme/api:PR #2']!.isMine, isTrue);
    expect(byId['reviewRequested:acme/api:PR #3']!.isMine, isFalse);
  });

  test('adoItems tags isMine matching self names with whitespace trimming', () {
    final items = AttentionService.adoItems(
      repoDisplay: 'org/proj/repo',
      organization: 'org',
      project: 'proj',
      name: 'repo',
      now: now,
      selfAdoNames: {'  Jane Doe '},
      prs: [
        {
          'pullRequestId': 5,
          'title': 't',
          'createdBy': {'displayName': 'Jane Doe'},
          'creationDate': daysAgo(1).toIso8601String(),
          'reviewers': [
            {'vote': 0, 'displayName': 'Someone'},
          ],
        },
      ],
    );
    expect(items.single.isMine, isTrue);
  });

  group('applyFilters / categoryCounts', () {
    final items = [
      const AttentionItem(
        id: 'a',
        category: 'reviewRequested',
        severity: 3000,
        titleTemplate: 'a',
        subtitleTemplate: '',
        repoDisplay: 'r',
        isMine: true,
      ),
      const AttentionItem(
        id: 'b',
        category: 'changesRequested',
        severity: 2000,
        titleTemplate: 'b',
        subtitleTemplate: '',
        repoDisplay: 'r',
      ),
      const AttentionItem(
        id: 'c',
        category: 'reviewRequested',
        severity: 3000,
        titleTemplate: 'c',
        subtitleTemplate: '',
        repoDisplay: 'r',
      ),
    ];

    test('mineOnly keeps only the user\'s items', () {
      final mine = AttentionService.applyFilters(items, mineOnly: true);
      expect(mine.map((i) => i.id), ['a']);
    });

    test('category keeps only the matching category', () {
      final changes = AttentionService.applyFilters(
        items,
        category: 'changesRequested',
      );
      expect(changes.map((i) => i.id), ['b']);
    });

    test('mineOnly and category combine (AND)', () {
      final both = AttentionService.applyFilters(
        items,
        mineOnly: true,
        category: 'changesRequested',
      );
      expect(both, isEmpty);
    });

    test('no filters returns everything', () {
      expect(AttentionService.applyFilters(items).length, 3);
    });

    test('categoryCounts tallies per category', () {
      expect(AttentionService.categoryCounts(items), {
        'reviewRequested': 2,
        'changesRequested': 1,
      });
    });

    test('categoryLabel maps known categories to friendly labels', () {
      expect(
        AttentionService.categoryLabel('changesRequested'),
        'Changes requested',
      );
      expect(AttentionService.categoryLabel('oldOpenPr'), 'Old open');
    });
  });

  group('computeAll', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'uses the injected clock so age is deterministic (not wall clock)',
      () async {
        final token = await TokenStore.addToken(
          provider: TokenStore.providerGithub,
          label: 'Acme',
          scope: 'acme',
          secret: 'ghp_secret',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('github_repos', [
          jsonEncode({'owner': 'acme', 'repoName': 'api', 'tokenId': token.id}),
        ]);

        final client = MockClient((request) async {
          if (request.url.path == '/graphql') {
            return http.Response(
              jsonEncode({
                'data': {
                  'repository': {
                    'pullRequests': {
                      'nodes': [
                        {
                          'number': 7,
                          'title': 'Waiting',
                          'author': {'login': 'alice'},
                          // Created a decade before the injected clock; if the
                          // code used the wall clock this age would be far
                          // larger than 10 days.
                          'createdAt': '2020-01-01T00:00:00Z',
                          'reviewDecision': null,
                          'reviewRequests': {
                            'totalCount': 1,
                            'nodes': [
                              {
                                'requestedReviewer': {'login': 'bob'},
                              },
                            ],
                          },
                          'url': 'https://github.com/acme/api/pull/7',
                        },
                      ],
                    },
                  },
                },
              }),
              200,
            );
          }
          return http.Response('[]', 200);
        });

        final items = await AttentionService.computeAll(
          client: client,
          now: DateTime.parse('2020-01-11T00:00:00Z'),
        );

        expect(items, hasLength(1));
        expect(items.single.category, 'reviewRequested');
        expect(items.single.ageDays, 10);
      },
    );

    test('filters out snoozed item ids', () async {
      final token = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Acme',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('github_repos', [
        jsonEncode({'owner': 'acme', 'repoName': 'api', 'tokenId': token.id}),
      ]);
      final client = MockClient((request) async {
        if (request.url.path == '/graphql') {
          return http.Response(
            jsonEncode({
              'data': {
                'repository': {
                  'pullRequests': {
                    'nodes': [
                      {
                        'number': 7,
                        'title': 't',
                        'author': {'login': 'a'},
                        'createdAt': '2020-01-01T00:00:00Z',
                        'reviewDecision': null,
                        'reviewRequests': {
                          'totalCount': 1,
                          'nodes': [
                            {
                              'requestedReviewer': {'login': 'b'},
                            },
                          ],
                        },
                        'url': 'https://github.com/acme/api/pull/7',
                      },
                    ],
                  },
                },
              },
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final now = DateTime.parse('2020-01-11T00:00:00Z');
      final all = await AttentionService.computeAll(client: client, now: now);
      expect(all, hasLength(1));

      final filtered = await AttentionService.computeAll(
        client: client,
        now: now,
        snoozedIds: {all.single.id},
      );
      expect(filtered, isEmpty);
    });

    test('POSTs a GraphQL query with the owner/name variables', () async {
      final token = await TokenStore.addToken(
        provider: TokenStore.providerGithub,
        label: 'Acme',
        scope: 'acme',
        secret: 'ghp_secret',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('github_repos', [
        jsonEncode({'owner': 'acme', 'repoName': 'api', 'tokenId': token.id}),
      ]);

      String? method;
      Map<String, dynamic>? gqlBody;
      final client = MockClient((request) async {
        if (request.url.path == '/graphql') {
          method = request.method;
          gqlBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'repository': {
                  'pullRequests': {'nodes': []},
                },
              },
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final items = await AttentionService.computeAll(client: client, now: now);
      expect(items, isEmpty);
      expect(method, 'POST');
      expect(gqlBody?['variables'], {'owner': 'acme', 'name': 'api'});
      final query = gqlBody?['query'] as String? ?? '';
      expect(query, contains('reviewDecision'));
      expect(query, contains('latestOpinionatedReviews'));
    });

    test(
      'surfaces an error item on non-200, GraphQL errors, or bad shape',
      () async {
        Future<void> check(http.Response graphqlResponse) async {
          SharedPreferences.setMockInitialValues({});
          FlutterSecureStorage.setMockInitialValues({});
          final token = await TokenStore.addToken(
            provider: TokenStore.providerGithub,
            label: 'Acme',
            scope: 'acme',
            secret: 'ghp_secret',
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('github_repos', [
            jsonEncode({
              'owner': 'acme',
              'repoName': 'api',
              'tokenId': token.id,
            }),
          ]);
          final client = MockClient((request) async {
            if (request.url.path == '/graphql') return graphqlResponse;
            return http.Response('[]', 200);
          });
          final items = await AttentionService.computeAll(
            client: client,
            now: now,
          );
          expect(items, hasLength(1));
          expect(items.single.category, 'error');
        }

        await check(http.Response('nope', 502));
        await check(
          http.Response(
            jsonEncode({
              'errors': [
                {'message': 'boom'},
              ],
            }),
            200,
          ),
        );
        await check(http.Response(jsonEncode({'data': {}}), 200));
      },
    );
  });
}
