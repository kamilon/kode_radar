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

  group('payloadFor', () {
    AttentionItem itemWithUrl(String id, String? url) => AttentionItem(
      id: id,
      category: 'reviewRequested',
      severity: 3000,
      titleTemplate: id,
      subtitleTemplate: '',
      repoDisplay: 'owner/repo',
      url: url,
    );

    test('a single item with a trusted https PR URL deep-links to it', () {
      expect(
        NotificationService.payloadFor([
          itemWithUrl('a', 'https://github.com/owner/repo/pull/1'),
        ]),
        'https://github.com/owner/repo/pull/1',
      );
    });

    test('a single item without a URL opens the inbox', () {
      expect(
        NotificationService.payloadFor([itemWithUrl('a', null)]),
        NotificationService.attentionPayload,
      );
    });

    test('a single item with a non-https URL opens the inbox', () {
      expect(
        NotificationService.payloadFor([
          itemWithUrl('a', 'http://github.com/owner/repo/pull/1'),
        ]),
        NotificationService.attentionPayload,
      );
    });

    test('a single item on an untrusted host opens the inbox', () {
      expect(
        NotificationService.payloadFor([
          itemWithUrl('a', 'https://evil.example.com/owner/repo/pull/1'),
        ]),
        NotificationService.attentionPayload,
      );
    });

    test('multiple items open the inbox', () {
      expect(
        NotificationService.payloadFor([
          itemWithUrl('a', 'https://github.com/owner/repo/pull/1'),
          itemWithUrl('b', 'https://github.com/owner/repo/pull/2'),
        ]),
        NotificationService.attentionPayload,
      );
    });

    test('an empty list opens the inbox', () {
      expect(
        NotificationService.payloadFor(const []),
        NotificationService.attentionPayload,
      );
    });
  });

  group('isTrustedPrUrl', () {
    test('accepts well-formed github.com and dev.azure.com PR URLs', () {
      expect(
        NotificationService.isTrustedPrUrl(
          'https://github.com/owner/repo/pull/1',
        ),
        isTrue,
      );
      expect(
        NotificationService.isTrustedPrUrl(
          'https://dev.azure.com/org/proj/_git/repo/pullrequest/2',
        ),
        isTrue,
      );
    });

    test('rejects null, non-https, and other hosts', () {
      expect(NotificationService.isTrustedPrUrl(null), isFalse);
      expect(
        NotificationService.isTrustedPrUrl('http://github.com/o/r/pull/1'),
        isFalse,
      );
      expect(
        NotificationService.isTrustedPrUrl('https://evil.example.com/x'),
        isFalse,
      );
      expect(NotificationService.isTrustedPrUrl('not a url'), isFalse);
    });

    test('rejects non-PR paths on a trusted host', () {
      // A forged payload can't open arbitrary pages on github.com/dev.azure.com.
      expect(
        NotificationService.isTrustedPrUrl(
          'https://github.com/owner/repo/issues/1',
        ),
        isFalse,
      );
      expect(
        NotificationService.isTrustedPrUrl('https://github.com/settings'),
        isFalse,
      );
      expect(
        NotificationService.isTrustedPrUrl('https://dev.azure.com/org/proj'),
        isFalse,
      );
      // Missing the leading /{org}/{project} segments (regex fully anchored).
      expect(
        NotificationService.isTrustedPrUrl(
          'https://dev.azure.com/_git/repo/pullrequest/1',
        ),
        isFalse,
      );
    });
  });

  group('notifiableItems', () {
    AttentionItem item(String id, String repo) => AttentionItem(
      id: id,
      category: 'reviewRequested',
      severity: 3000,
      titleTemplate: id,
      subtitleTemplate: '',
      repoDisplay: repo,
    );

    test('excludes items from muted repos', () {
      final items = [
        item('a', 'acme/api'),
        item('b', 'acme/web'),
        item('c', 'acme/api'),
      ];
      final result = NotificationService.notifiableItems(
        items,
        {'a', 'b', 'c'},
        {'acme/api'},
      );
      expect(result.map((i) => i.id), ['b']);
    });

    test('keeps only new ids when nothing is muted', () {
      final items = [item('a', 'acme/api'), item('b', 'acme/web')];
      final result = NotificationService.notifiableItems(items, {
        'a',
      }, const {});
      expect(result.map((i) => i.id), ['a']);
    });
  });

  group('baselineIdsToRecord', () {
    AttentionItem item(String id, String repo) => AttentionItem(
      id: id,
      category: 'reviewRequested',
      severity: 3000,
      titleTemplate: id,
      subtitleTemplate: '',
      repoDisplay: repo,
    );

    final items = [item('a', 'acme/api'), item('b', 'acme/web')];

    test('records all current ids outside quiet hours', () {
      expect(
        NotificationService.baselineIdsToRecord(
          currentIds: {'a', 'b'},
          items: items,
          mutedDisplays: {'acme/api'},
          firstRun: false,
          inQuietHours: false,
        ),
        {'a', 'b'},
      );
    });

    test('records all current ids on the first run during quiet hours', () {
      expect(
        NotificationService.baselineIdsToRecord(
          currentIds: {'a', 'b'},
          items: items,
          mutedDisplays: const {},
          firstRun: true,
          inQuietHours: true,
        ),
        {'a', 'b'},
      );
    });

    test('during quiet hours records only muted ids (defers the rest)', () {
      // 'a' (muted repo) is recorded so unmute can't replay it; 'b' is deferred.
      expect(
        NotificationService.baselineIdsToRecord(
          currentIds: {'a', 'b'},
          items: items,
          mutedDisplays: {'acme/api'},
          firstRun: false,
          inQuietHours: true,
        ),
        {'a'},
      );
    });
  });
}
