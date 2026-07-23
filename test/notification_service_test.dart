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
    AttentionItem item(
      String id,
      String repo, {
      String category = 'reviewRequested',
      bool isMine = false,
    }) => AttentionItem(
      id: id,
      category: category,
      severity: 3000,
      titleTemplate: id,
      subtitleTemplate: '',
      repoDisplay: repo,
      isMine: isMine,
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
        mutedDisplays: {'acme/api'},
        silencedCategories: const {},
        mineOnly: false,
      );
      expect(result.map((i) => i.id), ['b']);
    });

    test('keeps only new ids when nothing is filtered', () {
      final items = [item('a', 'acme/api'), item('b', 'acme/web')];
      final result = NotificationService.notifiableItems(
        items,
        {'a'},
        mutedDisplays: const {},
        silencedCategories: const {},
        mineOnly: false,
      );
      expect(result.map((i) => i.id), ['a']);
    });

    test('excludes items in silenced categories', () {
      final items = [
        item('a', 'acme/api', category: 'reviewRequested'),
        item('b', 'acme/web', category: 'oldOpenPr'),
      ];
      final result = NotificationService.notifiableItems(
        items,
        {'a', 'b'},
        mutedDisplays: const {},
        silencedCategories: {'oldOpenPr'},
        mineOnly: false,
      );
      expect(result.map((i) => i.id), ['a']);
    });

    test('mineOnly excludes items that are not the user\'s', () {
      final items = [
        item('a', 'acme/api', isMine: true),
        item('b', 'acme/web', isMine: false),
      ];
      final result = NotificationService.notifiableItems(
        items,
        {'a', 'b'},
        mutedDisplays: const {},
        silencedCategories: const {},
        mineOnly: true,
      );
      expect(result.map((i) => i.id), ['a']);
    });
  });

  group('baselineIdsToRecord', () {
    AttentionItem item(
      String id,
      String repo, {
      String category = 'reviewRequested',
      bool isMine = false,
    }) => AttentionItem(
      id: id,
      category: category,
      severity: 3000,
      titleTemplate: id,
      subtitleTemplate: '',
      repoDisplay: repo,
      isMine: isMine,
    );

    final items = [item('a', 'acme/api'), item('b', 'acme/web')];

    test('records all current ids outside quiet hours', () {
      expect(
        NotificationService.baselineIdsToRecord(
          currentIds: {'a', 'b'},
          items: items,
          mutedDisplays: {'acme/api'},
          silencedCategories: const {},
          mineOnly: false,
          notificationsEnabled: true,
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
          silencedCategories: const {},
          mineOnly: false,
          notificationsEnabled: true,
          firstRun: true,
          inQuietHours: true,
        ),
        {'a', 'b'},
      );
    });

    test('records all ids when notifications are disabled (drops backlog)', () {
      // Master off: never defer, or re-enabling would replay the backlog — even
      // the not-mine item under mine-only is recorded.
      final mixed = [
        item('mine', 'acme/api', isMine: true),
        item('other', 'acme/web', isMine: false),
      ];
      expect(
        NotificationService.baselineIdsToRecord(
          currentIds: {'mine', 'other'},
          items: mixed,
          mutedDisplays: const {},
          silencedCategories: const {},
          mineOnly: true,
          notificationsEnabled: false,
          firstRun: false,
          inQuietHours: false,
        ),
        {'mine', 'other'},
      );
    });

    test('during quiet hours records only muted ids (defers the rest)', () {
      // 'a' (muted repo) is recorded so unmute can't replay it; 'b' is deferred.
      expect(
        NotificationService.baselineIdsToRecord(
          currentIds: {'a', 'b'},
          items: items,
          mutedDisplays: {'acme/api'},
          silencedCategories: const {},
          mineOnly: false,
          notificationsEnabled: true,
          firstRun: false,
          inQuietHours: true,
        ),
        {'a'},
      );
    });

    test(
      'quiet hours: silenced drops (records); would-notify & not-mine defer',
      () {
        final mixed = [
          item('rev', 'acme/api', category: 'reviewRequested', isMine: true),
          item('old', 'acme/web', category: 'oldOpenPr', isMine: true),
          item('other', 'acme/db', category: 'reviewRequested', isMine: false),
        ];
        // 'old' (silenced category) never notifies -> its baseline advances.
        // 'rev' (would-notify) is deferred by quiet hours; 'other' (not mine,
        // mine-only) is deferred by audience so it can notify if it becomes mine.
        expect(
          NotificationService.baselineIdsToRecord(
            currentIds: {'rev', 'old', 'other'},
            items: mixed,
            mutedDisplays: const {},
            silencedCategories: {'oldOpenPr'},
            mineOnly: true,
            notificationsEnabled: true,
            firstRun: false,
            inQuietHours: true,
          ),
          {'old'},
        );
      },
    );

    test(
      'mine-only defers a not-mine item outside quiet hours (records rest)',
      () {
        // Regression for the "becomes mine later" miss: a not-mine item must NOT
        // be recorded (dropped) under mine-only, or it could never notify once it
        // becomes the user's.
        final mixed = [
          item('mine', 'acme/api', isMine: true),
          item('other', 'acme/web', isMine: false),
        ];
        expect(
          NotificationService.baselineIdsToRecord(
            currentIds: {'mine', 'other'},
            items: mixed,
            mutedDisplays: const {},
            silencedCategories: const {},
            mineOnly: true,
            notificationsEnabled: true,
            firstRun: false,
            inQuietHours: false,
          ),
          {'mine'},
        );
      },
    );

    test('first run seeds all but defers not-mine under mine-only', () {
      // The pre-existing backlog is seeded (so it isn't announced on install),
      // except a not-mine item under mine-only, which stays unseen so it can
      // notify if it later becomes the user's.
      final mixed = [
        item('mine', 'acme/api', isMine: true),
        item('other', 'acme/web', isMine: false),
      ];
      expect(
        NotificationService.baselineIdsToRecord(
          currentIds: {'mine', 'other'},
          items: mixed,
          mutedDisplays: const {},
          silencedCategories: const {},
          mineOnly: true,
          notificationsEnabled: true,
          firstRun: true,
          inQuietHours: false,
        ),
        {'mine'},
      );
    });
  });

  group('daily digest', () {
    AttentionItem item(String id, String category) => AttentionItem(
      id: id,
      category: category,
      severity: 1000,
      titleTemplate: id,
      subtitleTemplate: '',
      repoDisplay: 'acme/api',
    );

    test('shouldShowDigest only at/after the hour, respecting quiet hours', () {
      bool show({
        required int hour,
        int digestHour = 9,
        bool notificationsEnabled = true,
        bool quietHoursEnabled = false,
        int quietStartHour = 22,
        int quietEndHour = 8,
      }) => NotificationService.shouldShowDigest(
        now: DateTime(2026, 7, 23, hour),
        digestHour: digestHour,
        notificationsEnabled: notificationsEnabled,
        quietHoursEnabled: quietHoursEnabled,
        quietStartHour: quietStartHour,
        quietEndHour: quietEndHour,
      );

      // Before / at / after the digest hour.
      expect(show(hour: 8), isFalse);
      expect(show(hour: 9), isTrue);
      expect(show(hour: 14), isTrue);
      // Notifications disabled.
      expect(show(hour: 10, notificationsEnabled: false), isFalse);
      // Digest hour inside a normal (non-wrapping) quiet window: blocked during
      // it, fires once it lifts.
      expect(
        show(
          hour: 9,
          quietHoursEnabled: true,
          quietStartHour: 8,
          quietEndHour: 10,
        ),
        isFalse,
      );
      expect(
        show(
          hour: 10,
          quietHoursEnabled: true,
          quietStartHour: 8,
          quietEndHour: 10,
        ),
        isTrue,
      );
      // Not premature before the digest hour when quiet doesn't cover it.
      expect(
        show(
          hour: 7,
          quietHoursEnabled: true,
          quietStartHour: 8,
          quietEndHour: 10,
        ),
        isFalse,
      );
    });

    test('shouldShowDigest is not starved by an overnight quiet window', () {
      // Regression: digest hour 23 with quiet hours 22->8 has no allowed hour
      // >= 23, so it must fire once quiet lifts (from 08:00) rather than never.
      bool show(int hour) => NotificationService.shouldShowDigest(
        now: DateTime(2026, 7, 23, hour),
        digestHour: 23,
        notificationsEnabled: true,
        quietHoursEnabled: true,
        quietStartHour: 22,
        quietEndHour: 8,
      );
      expect(show(3), isFalse, reason: 'quiet hours (night)');
      expect(show(22), isFalse, reason: 'quiet hours (evening)');
      expect(show(8), isTrue, reason: 'fires when quiet lifts');
      expect(show(15), isTrue);
    });

    test('digestTitle counts items', () {
      expect(NotificationService.digestTitle(1), '1 item needs your attention');
      expect(NotificationService.digestTitle(4), '4 items need your attention');
    });

    test('digestBody breaks down by category in priority order', () {
      final items = [
        item('r1', 'reviewRequested'),
        item('r2', 'reviewRequested'),
        item('c1', 'changesRequested'),
        item('a1', 'approved'),
      ];
      expect(
        NotificationService.digestBody(items),
        '2 review requested · 1 changes requested · 1 approved',
      );
    });
  });
}
