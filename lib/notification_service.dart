import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attention_service.dart';
import 'mute_store.dart';
import 'notification_seen_store.dart';
import 'preferences_store.dart';
import 'repo_store.dart';
import 'trend_digest.dart';

class NotificationService {
  NotificationService._();

  static const int _summaryNotificationId = 42001;
  static const int _digestNotificationId = 42002;
  static const int _regressionNotificationId = 42003;
  static const String _channelId = 'attention_inbox';
  static const String _channelName = 'Attention Inbox';
  static const String _channelDescription =
      'Notifications for new Attention Inbox items';

  /// Payload marking a summary notification whose tap should open the Attention
  /// Inbox (used when there isn't a single obvious item to deep-link to).
  static const String attentionPayload = 'attention';

  /// The payload of the most recently tapped notification, for the app shell to
  /// route (open the inbox, or launch a single item's URL). The shell resets it
  /// to null once consumed.
  static final ValueNotifier<String?> tappedPayload = ValueNotifier<String?>(
    null,
  );

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static Future<void>? _initFuture;

  // Serializes the read-modify-write of the seen baseline so the background
  // poll and a visible Attention Inbox refresh can't double-notify or clobber
  // one another's baseline.
  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static Future<void> init() async {
    if (_initialized || !_isSupportedPlatform) return;

    final existing = _initFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final initFuture = _initPlugin();
    _initFuture = initFuture;
    await initFuture;
  }

  static Future<void> notifyNewAttention(List<AttentionItem> items) =>
      _runLocked(() => _notifyNewAttention(items));

  static Future<void> _notifyNewAttention(List<AttentionItem> items) async {
    try {
      // Error items are per-repo fetch failures, not attention: never notify on
      // them and never record them in the baseline, so an offline/failed refresh
      // can't emit a spurious "items need attention" (the ids would otherwise be
      // "new" for an already-known repo).
      final attention = items
          .where((item) => item.category != AttentionService.errorCategory)
          .toList();
      final currentIds = attention.map((item) => item.id).toSet();
      final prefs = await SharedPreferences.getInstance();
      // Freshen the cached prefs from disk: the seen baseline is now atomic in
      // the DB, but the repo lists and notification settings are still read from
      // SharedPreferences here, so a reused background isolate should still pick
      // up foreground config changes (e.g. a repo added, or notifications
      // disabled) before deciding.
      await prefs.reload();
      // Mark every monitored repo "known" — including ones that currently have
      // zero attention items — so adding a repo silences only its existing
      // backlog while the first attention item that later appears in a
      // quiet-at-add repo still notifies. (Repo lists remain configuration in
      // SharedPreferences.)
      final monitoredRepos = monitoredRepoDisplays(
        prefs.getStringList(RepoStore.githubKey) ?? const <String>[],
        prefs.getStringList(RepoStore.adoKey) ?? const <String>[],
      );
      // The seen baseline lives in the DB (Phase 4): the foreground and the
      // background-sync isolate record it additively, so neither clobbers the
      // other's snapshot. (The notification *decision* itself — read baseline,
      // notify, then record — is still per-isolate, so a truly-simultaneous
      // foreground+background run could each notify the same item once; that is
      // rare because the background task runs while the app is suspended and not
      // actively notifying, and the additive baseline prevents any re-notify on
      // the following cycle.)
      final firstRun = !await NotificationSeenStore.isSeeded();
      final seen = await NotificationSeenStore.seenIds();
      final knownRepos = await NotificationSeenStore.knownRepos();
      final newIds = pendingIds(
        seen: seen,
        knownRepos: knownRepos,
        items: attention,
        firstRun: firstRun,
      );
      final now = DateTime.now();
      final appPrefs = await PreferencesStore.load();
      // Quiet hours *defer*: we hold the notification and, for unmuted items,
      // do NOT advance the baseline, so they surface on the next refresh after
      // quiet hours end. Muted items still have their baseline advanced (below)
      // so unmuting never replays a backlog — muting drops, it doesn't defer. A
      // disabled notifications toggle likewise drops (baseline advances below).
      final inQuietHours =
          appPrefs.notificationsEnabled &&
          appPrefs.quietHoursEnabled &&
          PreferencesStore.isWithinQuietHours(
            now,
            appPrefs.quietStartHour,
            appPrefs.quietEndHour,
          );

      // Read the muted repos once: used both to filter notifications and to
      // still advance the baseline for muted items during quiet hours (below).
      final muted = await MuteStore.mutedDisplays();
      final silenced = appPrefs.silencedNotifyCategories;
      final mineOnly = appPrefs.notifyMineOnly;
      final notificationsAllowed = PreferencesStore.notificationsAllowed(
        appPrefs,
        now,
      );

      // Digest mode: suppress per-change alerts and instead show at most one
      // summary a day. Advance the baseline as in per-item mode but WITHOUT
      // quiet-hours deferral (the digest owns its own timing) — muted/silenced
      // still drop and mine-only not-mine items still defer (preserving the
      // becomes-mine invariant), so switching back to per-item alerts can't
      // replay yet a not-mine item can still notify if it becomes the user's.
      if (appPrefs.digestModeEnabled) {
        final baselineIds = baselineIdsToRecord(
          currentIds: currentIds,
          items: attention,
          mutedDisplays: muted,
          silencedCategories: silenced,
          mineOnly: mineOnly,
          notificationsEnabled: appPrefs.notificationsEnabled,
          firstRun: firstRun,
          inQuietHours: false,
        );
        await NotificationSeenStore.recordBaseline(baselineIds, monitoredRepos);
        // `attention` already excludes error items (filtered at the top of this
        // method), so the digest's count and per-category breakdown stay
        // consistent; here we only apply the notification filters.
        final digestItems = attention
            .where(
              (item) => notifiesFor(
                item,
                mutedDisplays: muted,
                silencedCategories: silenced,
                mineOnly: mineOnly,
              ),
            )
            .toList(growable: false);
        if (digestItems.isNotEmpty &&
            _isSupportedPlatform &&
            shouldShowDigest(
              now: now,
              digestHour: appPrefs.digestHour,
              notificationsEnabled: appPrefs.notificationsEnabled,
              quietHoursEnabled: appPrefs.quietHoursEnabled,
              quietStartHour: appPrefs.quietStartHour,
              quietEndHour: appPrefs.quietEndHour,
            )) {
          // Atomic once-per-day claim (serialized across isolates in the DB);
          // release it if the notification fails so a later sync retries.
          final date = PreferencesStore.localDateString(now);
          if (await NotificationSeenStore.claimDailyDigest(date)) {
            final shown = await _showDigestNotification(digestItems);
            if (!shown) {
              await NotificationSeenStore.releaseDailyDigest(date);
            }
          }
        }
        return;
      }

      if (newIds.isNotEmpty && notificationsAllowed) {
        // Exclude muted repos, silenced categories, and (when mine-only) items
        // that aren't the user's — they still appear in the inbox.
        final newItems = notifiableItems(
          attention,
          newIds,
          mutedDisplays: muted,
          silencedCategories: silenced,
          mineOnly: mineOnly,
        );
        await _showSummaryNotification(newItems);
      }

      // Advance the seen baseline. Normally (first run / outside quiet hours) we
      // record every current id + mark repos known. During quiet hours we defer
      // unmuted items (hold their baseline so they surface after quiet hours)
      // but still record muted items, so unmuting never replays a backlog —
      // muting drops, it doesn't defer.
      final advanceAll = shouldAdvanceBaseline(
        firstRun: firstRun,
        inQuietHours: inQuietHours,
      );
      final baselineIds = baselineIdsToRecord(
        currentIds: currentIds,
        items: attention,
        mutedDisplays: muted,
        silencedCategories: silenced,
        mineOnly: mineOnly,
        notificationsEnabled: appPrefs.notificationsEnabled,
        firstRun: firstRun,
        inQuietHours: inQuietHours,
      );
      if (advanceAll || baselineIds.isNotEmpty) {
        // Additive, atomic union in the DB: ids are never dropped (a
        // transiently-failed repo keeps its baseline) and concurrent isolates
        // can't clobber each other's snapshot. Repos are recorded (only in the
        // full-advance case) so their first appearance is only ever seeded once.
        await NotificationSeenStore.recordBaseline(
          baselineIds,
          advanceAll ? monitoredRepos : const <String>{},
        );
      }
    } catch (e) {
      debugPrint('Failed to process attention notifications: $e');
    }
  }

  /// The item ids to record into the seen baseline this cycle.
  ///
  /// - Notifications fully off: drop the whole backlog (record every id) — never
  ///   defer, or re-enabling notifications would replay everything held.
  /// - Muted repos / silenced categories **drop**: record their baseline so
  ///   un-muting or re-enabling the category never replays a backlog. (They also
  ///   won't notify on becoming the user's — correct, they were silenced.)
  /// - Mine-only **defers** a not-mine item — including on the first run — by
  ///   NOT recording it, so if it later becomes the user's (e.g. they're added
  ///   as a reviewer, same id) it's still unseen and can notify.
  /// - Otherwise a would-notify item is seeded on the first run (so the existing
  ///   backlog isn't announced on install) and recorded whenever it's actually
  ///   notified; during quiet hours it's held to notify once quiet hours end.
  @visibleForTesting
  static Set<String> baselineIdsToRecord({
    required Set<String> currentIds,
    required List<AttentionItem> items,
    required Set<String> mutedDisplays,
    required Set<String> silencedCategories,
    required bool mineOnly,
    required bool notificationsEnabled,
    required bool firstRun,
    required bool inQuietHours,
  }) {
    if (!notificationsEnabled) return currentIds;
    final ids = <String>{};
    for (final item in items) {
      if (mutedDisplays.contains(item.repoDisplay) ||
          silencedCategories.contains(item.category)) {
        ids.add(item.id); // dropped: record so re-enabling can't replay
        continue;
      }
      if (mineOnly && !item.isMine) continue; // deferred by audience
      if (firstRun || !inQuietHours) ids.add(item.id); // seeded / notified
    }
    return ids;
  }

  static Set<String> diffNew(Set<String> seen, Iterable<String> current) =>
      current.toSet().difference(seen);

  /// The items to actually notify about: those whose id is in [newIds] and that
  /// pass the notification filters ([notifiesFor]). Suppressed items still show
  /// in the inbox; their seen baseline advances when they're dropped (muted /
  /// silenced), but a not-mine item under mine-only is instead deferred so it
  /// can still notify if it later becomes the user's (see [baselineIdsToRecord]).
  @visibleForTesting
  static List<AttentionItem> notifiableItems(
    List<AttentionItem> items,
    Set<String> newIds, {
    required Set<String> mutedDisplays,
    required Set<String> silencedCategories,
    required bool mineOnly,
  }) {
    return items
        .where(
          (item) =>
              newIds.contains(item.id) &&
              notifiesFor(
                item,
                mutedDisplays: mutedDisplays,
                silencedCategories: silencedCategories,
                mineOnly: mineOnly,
              ),
        )
        .toList(growable: false);
  }

  /// Whether [item] should raise a notification given the user's filters: its
  /// repo isn't muted, its category isn't silenced, and — when [mineOnly] — it
  /// concerns the user. Pure; the inbox is unaffected by any of these.
  @visibleForTesting
  static bool notifiesFor(
    AttentionItem item, {
    required Set<String> mutedDisplays,
    required Set<String> silencedCategories,
    required bool mineOnly,
  }) {
    return !mutedDisplays.contains(item.repoDisplay) &&
        !silencedCategories.contains(item.category) &&
        (!mineOnly || item.isMine);
  }

  /// The payload for a summary notification. When exactly one new item is being
  /// notified and it has a trusted PR URL, the payload is that URL so a tap can
  /// open that PR directly; otherwise it is [attentionPayload], so a tap opens
  /// the Attention Inbox (the right target for a multi-item summary).
  @visibleForTesting
  static String payloadFor(List<AttentionItem> newItems) {
    if (newItems.length == 1 && isTrustedPrUrl(newItems.single.url)) {
      return newItems.single.url!;
    }
    return attentionPayload;
  }

  /// Whether [url] is a PR URL we're willing to open from a notification tap:
  /// `https` on a known provider host **and** matching that provider's PR path
  /// shape. This rejects a forged payload (e.g. an Android intent crafted with
  /// an arbitrary URL) from opening some other page on a trusted host.
  static bool isTrustedPrUrl(String? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    final path = uri.path;
    // GitHub: /{owner}/{repo}/pull/{number}
    if (uri.host == 'github.com') {
      return RegExp(r'^/[^/]+/[^/]+/pull/\d+/?$').hasMatch(path);
    }
    // Azure DevOps: /{org}/{project}/_git/{repo}/pullrequest/{id}
    if (uri.host == 'dev.azure.com') {
      return RegExp(
        r'^/[^/]+/[^/]+/_git/[^/]+/pullrequest/\d+/?$',
      ).hasMatch(path);
    }
    return false;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    tappedPayload.value = response.payload;
  }

  static bool _launchPayloadTaken = false;

  /// The payload of the notification that launched the app from a terminated
  /// state (cold start), or null. Returns it at most once per process, so a
  /// shell rebuild can't re-open the same launch URL; live taps arrive via
  /// [tappedPayload].
  static Future<String?> takeLaunchPayload() async {
    if (_launchPayloadTaken || !_isSupportedPlatform) return null;
    _launchPayloadTaken = true;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details!.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('Failed to read notification launch details: $e');
    }
    return null;
  }

  /// The ids to notify about: ids new since [seen], minus ids that belong to a
  /// repo appearing for the first time (a newly added repo's existing backlog
  /// is seeded silently rather than replayed). Returns nothing on the first run.
  @visibleForTesting
  static Set<String> pendingIds({
    required Set<String> seen,
    required Set<String> knownRepos,
    required List<AttentionItem> items,
    required bool firstRun,
  }) {
    if (firstRun) return const <String>{};
    // Never treat per-repo fetch failures as new attention.
    final attention = items
        .where((item) => item.category != AttentionService.errorCategory)
        .toList();
    final currentIds = attention.map((item) => item.id).toSet();
    final newRepoItemIds = attention
        .where((item) => !knownRepos.contains(item.repoDisplay))
        .map((item) => item.id)
        .toSet();
    return diffNew(seen, currentIds).difference(newRepoItemIds);
  }

  /// The `repoDisplay` of every monitored repository, derived from the persisted
  /// GitHub/Azure DevOps repo lists. Matches [AttentionItem.repoDisplay]
  /// (`owner/name` for GitHub, `org/project/name` for Azure DevOps).
  @visibleForTesting
  static Set<String> monitoredRepoDisplays(
    List<String> githubRaw,
    List<String> adoRaw,
  ) {
    final displays = <String>{};
    for (final raw in githubRaw) {
      final map = _tryDecodeMap(raw);
      final owner = map?['owner'];
      final name = map?['repoName'];
      if (owner is String && name is String) displays.add('$owner/$name');
    }
    for (final raw in adoRaw) {
      final map = _tryDecodeMap(raw);
      final org = map?['organization'];
      final project = map?['project'];
      final name = map?['repoName'];
      if (org is String && project is String && name is String) {
        displays.add('$org/$project/$name');
      }
    }
    return displays;
  }

  static Map<String, dynamic>? _tryDecodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether to advance the seen baseline. Quiet hours defer (hold the baseline
  /// so items notify on the next refresh after quiet hours end); the first run
  /// and every non-quiet case advance (a disabled toggle therefore drops rather
  /// than replays a backlog).
  @visibleForTesting
  static bool shouldAdvanceBaseline({
    required bool firstRun,
    required bool inQuietHours,
  }) => firstRun || !inQuietHours;

  static Future<void> _initPlugin() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      // Android 13+ (API 33+) requires the runtime POST_NOTIFICATIONS grant.
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    } finally {
      _initFuture = null;
    }
  }

  static Future<void> _showSummaryNotification(
    List<AttentionItem> newItems,
  ) async {
    try {
      if (newItems.isEmpty || !_isSupportedPlatform) return;

      await init();
      if (!_initialized) return;

      final details = _notificationDetails();
      if (details == null) return;

      await _plugin.show(
        id: _summaryNotificationId,
        title: _summaryTitle(newItems.length),
        body: _summaryBody(newItems),
        notificationDetails: details,
        payload: payloadFor(newItems),
      );
    } catch (e) {
      debugPrint('Failed to show attention notification: $e');
    }
  }

  static NotificationDetails? _notificationDetails() {
    if (!_isSupportedPlatform) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
      ),
      TargetPlatform.iOS => const NotificationDetails(
        iOS: DarwinNotificationDetails(),
      ),
      TargetPlatform.macOS => const NotificationDetails(
        macOS: DarwinNotificationDetails(),
      ),
      _ => null,
    };
  }

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  static String _summaryTitle(int count) =>
      count == 1 ? '1 item needs attention' : '$count items need attention';

  static String _summaryBody(List<AttentionItem> items) {
    final titles = items.take(3).map((item) => item.title).toList();
    final remaining = items.length - titles.length;
    if (remaining > 0) {
      titles.add('+$remaining more');
    }
    return titles.join('\n');
  }

  /// Whether the once-daily digest should be shown now, by timing alone (the
  /// once-per-day guarantee is a separate atomic claim). True when notifications
  /// are enabled, it's not currently quiet hours, and either we've reached the
  /// digest hour today OR the digest hour falls inside an overnight (wrapping)
  /// quiet window — in which case it can never be reached while allowed, so we
  /// fire it once quiet hours lift. Pure.
  @visibleForTesting
  static bool shouldShowDigest({
    required DateTime now,
    required int digestHour,
    required bool notificationsEnabled,
    required bool quietHoursEnabled,
    required int quietStartHour,
    required int quietEndHour,
  }) {
    if (!notificationsEnabled) return false;
    final inQuiet =
        quietHoursEnabled &&
        PreferencesStore.isWithinQuietHours(now, quietStartHour, quietEndHour);
    if (inQuiet) return false;
    if (now.hour >= digestHour) return true;
    // Overnight quiet window (start > end) that contains the digest hour: the
    // digest hour is unreachable while notifications are allowed, so deliver at
    // the first allowed moment after the window lifts.
    final quietWraps = quietHoursEnabled && quietStartHour > quietEndHour;
    return quietWraps &&
        digestHour >= quietStartHour &&
        now.hour >= quietEndHour;
  }

  /// The digest notification's title (the total count). Pure.
  @visibleForTesting
  static String digestTitle(int count) => count == 1
      ? '1 item needs your attention'
      : '$count items need your attention';

  /// The digest notification's body: a per-category breakdown of [items] in
  /// priority order (e.g. "3 review requested · 1 changes requested"). Pure.
  @visibleForTesting
  static String digestBody(List<AttentionItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    final parts = <String>[];
    for (final category in AttentionService.notifiableCategories) {
      final n = counts[category] ?? 0;
      if (n > 0) {
        parts.add(
          '$n ${AttentionService.categoryLabel(category).toLowerCase()}',
        );
      }
    }
    return parts.join(' · ');
  }

  static Future<bool> _showDigestNotification(List<AttentionItem> items) async {
    try {
      if (items.isEmpty || !_isSupportedPlatform) return false;
      await init();
      if (!_initialized) return false;
      final details = _notificationDetails();
      if (details == null) return false;
      await _plugin.show(
        id: _digestNotificationId,
        title: digestTitle(items.length),
        body: digestBody(items),
        notificationDetails: details,
        payload: attentionPayload,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to show digest notification: $e');
      return false;
    }
  }

  /// Raises a notification for team trend regressions (review latency, merge
  /// time, or CI failure rate up week-over-week). No-ops unless regression
  /// alerts are enabled and notifications are currently allowed. De-duplicates
  /// via [NotificationSeenStore.claimNewRegressionKeys] keyed by [periodKey],
  /// so a standing regression alerts at most once per period. Never throws.
  static Future<void> notifyRegressions(
    List<TrendRegression> regressions, {
    required String periodKey,
    DateTime? now,
    AppPreferences? prefs,
  }) async {
    try {
      if (!_isSupportedPlatform || regressions.isEmpty) return;
      final at = now ?? DateTime.now();
      final appPrefs = prefs ?? await PreferencesStore.load();
      if (!appPrefs.regressionAlertsEnabled) return;
      if (!PreferencesStore.notificationsAllowed(appPrefs, at)) return;
      // Only claim (mark as notified) once we can actually show, so a failed
      // init/show lets a later sync retry instead of silently swallowing it.
      await init();
      if (!_initialized) return;
      final details = _notificationDetails();
      if (details == null) return;
      final fresh = await NotificationSeenStore.claimNewRegressionKeys(
        regressions.map((r) => r.key).toSet(),
        periodKey,
      );
      if (fresh.isEmpty) return;
      final freshRegressions = regressions
          .where((r) => fresh.contains(r.key))
          .toList(growable: false);
      if (freshRegressions.isEmpty) return;
      try {
        await _plugin.show(
          id: _regressionNotificationId,
          title: regressionTitle(freshRegressions.length),
          body: regressionBody(freshRegressions),
          notificationDetails: details,
          payload: attentionPayload,
        );
      } catch (e) {
        // Showing failed after we claimed the keys — release them so a later
        // sync retries instead of silently dropping the alert for the period.
        await NotificationSeenStore.releaseRegressionKeys(fresh);
        rethrow;
      }
    } catch (e, st) {
      debugPrint('Failed to show regression notification: $e\n$st');
    }
  }

  /// Title for a regression alert covering [count] regressions. Pure.
  static String regressionTitle(int count) =>
      count == 1 ? 'A team trend regressed' : '$count team trends regressed';

  /// Body for a regression alert: up to three "Team: metric a → b" lines, then
  /// a "+N more" overflow. Pure.
  static String regressionBody(List<TrendRegression> regressions) {
    final lines = regressions
        .take(3)
        .map((r) => '${r.teamName}: ${r.summary}')
        .toList();
    final remaining = regressions.length - lines.length;
    if (remaining > 0) lines.add('+$remaining more');
    return lines.join('\n');
  }
}
