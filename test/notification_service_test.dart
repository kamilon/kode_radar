import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/attention_service.dart';
import 'package:kode_radar/notification_service.dart';

void main() {
  test('diffNew returns current ids not already seen', () {
    expect(
      NotificationService.diffNew(<String>{'a', 'b'}, <String>['b', 'c', 'c']),
      <String>{'c'},
    );
  });

  test('diffNew returns an empty set when all current ids are seen', () {
    expect(
      NotificationService.diffNew(<String>{'a', 'b'}, <String>['a', 'b']),
      isEmpty,
    );
  });

  group('shouldAdvanceBaseline', () {
    test('quiet hours defer (hold the baseline)', () {
      expect(
        NotificationService.shouldAdvanceBaseline(
          firstRun: false,
          inQuietHours: true,
        ),
        isFalse,
      );
    });

    test('first run always seeds even during quiet hours', () {
      expect(
        NotificationService.shouldAdvanceBaseline(
          firstRun: true,
          inQuietHours: true,
        ),
        isTrue,
      );
    });

    test('non-quiet advances (disabled toggle drops, no replay)', () {
      expect(
        NotificationService.shouldAdvanceBaseline(
          firstRun: false,
          inQuietHours: false,
        ),
        isTrue,
      );
    });
  });

  AttentionItem item(String id, String repo) => AttentionItem(
    id: id,
    category: 'reviewRequested',
    severity: 3000,
    titleTemplate: id,
    subtitleTemplate: '',
    repoDisplay: repo,
  );

  group('monitoredRepoDisplays', () {
    test('derives owner/name and org/project/name displays', () {
      final displays = NotificationService.monitoredRepoDisplays(
        ['{"owner":"acme","repoName":"api"}', 'not-json'],
        ['{"organization":"org","project":"proj","repoName":"repo"}'],
      );
      expect(displays, {'acme/api', 'org/proj/repo'});
    });

    test('skips malformed / incomplete entries', () {
      final displays = NotificationService.monitoredRepoDisplays([
        '{"owner":"acme"}',
        '42',
      ], const []);
      expect(displays, isEmpty);
    });
  });

  group('pendingIds', () {
    test('first run notifies nothing (silent seed)', () {
      expect(
        NotificationService.pendingIds(
          seen: const {},
          knownRepos: const {},
          items: [item('a', 'r1'), item('b', 'r1')],
          firstRun: true,
        ),
        isEmpty,
      );
    });

    test('notifies ids new since the baseline', () {
      expect(
        NotificationService.pendingIds(
          seen: const {'a'},
          knownRepos: const {'r1'},
          items: [item('a', 'r1'), item('b', 'r1')],
          firstRun: false,
        ),
        {'b'},
      );
    });

    test('suppresses items from a repo appearing for the first time', () {
      // r2 is not yet known, so its items are seeded silently, not notified.
      final pending = NotificationService.pendingIds(
        seen: const {'a'},
        knownRepos: const {'r1'},
        items: [item('b', 'r1'), item('c', 'r2'), item('d', 'r2')],
        firstRun: false,
      );
      expect(pending, {'b'});
    });

    test('excludes per-repo error items (offline failure never notifies)', () {
      final errorItem = AttentionItem(
        id: 'error:r1',
        category: AttentionService.errorCategory,
        severity: 0,
        titleTemplate: 'Could not load',
        subtitleTemplate: 'r1',
        repoDisplay: 'r1',
      );
      final pending = NotificationService.pendingIds(
        seen: const {'a'},
        knownRepos: const {'r1'},
        items: [errorItem],
        firstRun: false,
      );
      expect(pending, isEmpty);
    });
  });
}
