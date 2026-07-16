import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/work_item_service.dart';

void main() {
  group('parseGithubIssues', () {
    test('keeps issues assigned to self, skips PRs and unassigned', () {
      final items = WorkItemService.parseGithubIssues(
        [
          {
            'number': 7,
            'title': 'Fix bug',
            'state': 'open',
            'html_url': 'https://github.com/acme/api/issues/7',
            'updated_at': '2026-07-14T10:00:00Z',
            'assignees': [
              {'login': 'OctoCat'},
            ],
          },
          {
            // A PR is returned by /issues but has a pull_request key.
            'number': 8,
            'title': 'A PR',
            'pull_request': {'url': 'https://api.github.com/...'},
            'assignees': [
              {'login': 'octocat'},
            ],
          },
          {
            'number': 9,
            'title': 'Someone else',
            'assignees': [
              {'login': 'other'},
            ],
          },
        ],
        repoKey: 'github:acme/api',
        repoDisplay: 'acme/api',
        selfGithubLogins: {'octocat'},
      );

      expect(items, hasLength(1));
      expect(items.single.reference, '#7');
      expect(items.single.provider, 'github');
      expect(items.single.groupKey, 'github:acme/api');
      expect(items.single.assignees, {'OctoCat'});
    });

    test('returns nothing when no identity is provided', () {
      final items = WorkItemService.parseGithubIssues(
        [
          {
            'number': 1,
            'title': 'x',
            'assignees': [
              {'login': 'octocat'},
            ],
          },
        ],
        repoKey: 'github:acme/api',
        repoDisplay: 'acme/api',
        selfGithubLogins: const {},
      );
      expect(items, isEmpty);
    });
  });

  group('parseAdoWorkItems / parseWiqlIds', () {
    test('parses work item fields and builds the edit URL', () {
      final items = WorkItemService.parseAdoWorkItems(
        {
          'value': [
            {
              'id': 42,
              'fields': {
                'System.Title': 'Do the thing',
                'System.State': 'Active',
                'System.AssignedTo': {'displayName': 'Jane Doe'},
                'System.ChangedDate': '2026-07-14T09:00:00Z',
              },
            },
          ],
        },
        organization: 'contoso',
        project: 'web',
      );
      expect(items, hasLength(1));
      expect(items.single.id, 'ado-wi:contoso:42');
      expect(items.single.reference, 'WI 42');
      expect(items.single.title, 'Do the thing');
      expect(items.single.state, 'Active');
      expect(items.single.assignees, {'Jane Doe'});
      expect(items.single.groupKey, 'ado:contoso/web');
      expect(
        items.single.url,
        'https://dev.azure.com/contoso/web/_workitems/edit/42',
      );
    });

    test('parseWiqlIds extracts ids and caps the list', () {
      final ids = WorkItemService.parseWiqlIds({
        'workItems': [
          {'id': 1},
          {'id': 2},
          {'id': 'nope'},
          {'id': 3},
        ],
      });
      expect(ids, [1, 2, 3]);
    });

    test('assignedWiql targets @Me and excludes terminal states', () {
      final wiql = WorkItemService.assignedWiql();
      expect(wiql, contains('@Me'));
      expect(wiql, contains("<> 'Closed'"));
      expect(wiql, contains("<> 'Removed'"));
      expect(wiql, contains("<> 'Done'"));
      expect(wiql, contains("<> 'Completed'"));
    });
  });
}
