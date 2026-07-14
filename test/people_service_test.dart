import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/people_service.dart';
import 'package:kode_radar/person.dart';

void main() {
  final now = DateTime.parse('2026-07-14T12:00:00Z');

  test('aggregateGithub counts authors and requested reviewers', () {
    final people = PeopleService.aggregateGithub(
      now: now,
      prs: [
        {
          'user': {'login': 'Alice'},
          'created_at': '2026-07-12T12:00:00Z',
          'requested_reviewers': [
            {'login': 'Bob'},
            {'login': 'carol'},
          ],
        },
        {
          'user': {'login': 'alice'},
          'created_at': '2026-07-13T12:00:00Z',
          'requested_reviewers': [
            {'login': 'bob'},
          ],
        },
        {
          'draft': true,
          'user': {'login': 'draft-author'},
          'requested_reviewers': [
            {'login': 'draft-reviewer'},
          ],
        },
      ],
    );

    final alice = people.singleWhere((person) => person.key == 'github:alice');
    final bob = people.singleWhere((person) => person.key == 'github:bob');
    final carol = people.singleWhere((person) => person.key == 'github:carol');

    expect(alice.authoredOpenPrs, 2);
    expect(alice.reviewRequests, 0);
    expect(alice.lastSeen, DateTime.parse('2026-07-13T12:00:00Z'));
    expect(bob.authoredOpenPrs, 0);
    expect(bob.reviewRequests, 2);
    expect(carol.reviewRequests, 1);
    expect(
        people.any((person) => person.key == 'github:draft-author'), isFalse);
  });

  test('mergePeople merges shared logins, sums counts, and marks self', () {
    final people = PeopleService.mergePeople([
      Person(
        key: 'one',
        displayName: 'Alice',
        githubLogins: {'alice'},
        authoredOpenPrs: 1,
        reviewRequests: 2,
        lastSeen: DateTime.parse('2026-07-12T12:00:00Z'),
        isSelf: true,
      ),
      Person(
        key: 'two',
        displayName: 'Alice B',
        githubLogins: {'ALICE'},
        adoNames: {'Ada Lovelace'},
        authoredOpenPrs: 3,
        reviewRequests: 4,
        lastSeen: DateTime.parse('2026-07-13T12:00:00Z'),
      ),
      Person(
        key: 'three',
        displayName: 'Bob',
        githubLogins: {'bob'},
        reviewRequests: 5,
      ),
    ]);

    expect(people, hasLength(2));
    final alice = people.singleWhere((person) => person.key == 'github:alice');
    expect(alice.authoredOpenPrs, 4);
    expect(alice.reviewRequests, 6);
    expect(alice.githubLogins, {'alice'});
    expect(alice.adoNames, {'Ada Lovelace'});
    expect(alice.lastSeen, DateTime.parse('2026-07-13T12:00:00Z'));
    expect(alice.isSelf, isTrue);
    expect(people.first.key, 'github:alice');
  });

  test('aggregateAdo counts only pending (vote 0) reviewers', () {
    final people = PeopleService.aggregateAdo(
      now: now,
      prs: [
        {
          'createdBy': {'displayName': 'Jane Doe'},
          'creationDate': '2026-07-13T12:00:00Z',
          'reviewers': [
            {'displayName': 'Rev Pending', 'vote': 0},
            {'displayName': 'Rev Approved', 'vote': 10},
            {'displayName': 'Rev Rejected', 'vote': -10},
          ],
        },
      ],
    );

    // Only the author + the pending reviewer are registered.
    expect(people, hasLength(2));
    final reviewSum =
        people.map((p) => p.reviewRequests).fold<int>(0, (a, b) => a + b);
    final authorSum =
        people.map((p) => p.authoredOpenPrs).fold<int>(0, (a, b) => a + b);
    expect(reviewSum, 1);
    expect(authorSum, 1);
  });

  test('malformed entries do not throw', () {
    expect(
      () => PeopleService.aggregateGithub(
        now: now,
        prs: [
          'not-a-map',
          {
            'user': {'login': 42},
            'created_at': 'not-a-date',
            'requested_reviewers': [
              'bad-reviewer',
              {'login': 7},
            ],
          },
        ],
      ),
      returnsNormally,
    );

    final people = PeopleService.aggregateAdo(
      now: now,
      prs: [
        null,
        {
          'createdBy': {'displayName': false},
          'creationDate': 123,
          'reviewers': [
            {'displayName': 9},
          ],
        },
      ],
    );
    expect(people, isEmpty);
  });
}
