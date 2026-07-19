import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attention_service.dart';
import 'preferences_store.dart';
import 'repo_store.dart';

class NotificationService {
  NotificationService._();

  static const String _seenKey = 'seen_attention';

  /// Repos whose first snapshot has been seeded, so adding a repo doesn't
  /// replay its whole existing backlog as "new".
  static const String _knownReposKey = 'known_attention_repos';

  /// Safety cap on the monotonic seen-id set (the baseline only grows via
  /// union); a very long uptime resets to the current snapshot rather than
  /// growing without bound.
  static const int _maxSeenIds = 5000;

  static const int _summaryNotificationId = 42001;
  static const String _channelId = 'attention_inbox';
  static const String _channelName = 'Attention Inbox';
  static const String _channelDescription =
      'Notifications for new Attention Inbox items';

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
      final currentIds = items.map((item) => item.id).toSet();
      final prefs = await SharedPreferences.getInstance();
      // Refresh the in-memory cache from disk first: the background-sync isolate
      // and the resident foreground isolate each cache prefs independently, so
      // without this a resident foreground could re-notify items the background
      // sync already alerted on (and clobber its advanced baseline).
      await prefs.reload();
      // Mark every monitored repo "known" — including ones that currently have
      // zero attention items — so adding a repo silences only its existing
      // backlog while the first attention item that later appears in a
      // quiet-at-add repo still notifies.
      final monitoredRepos = monitoredRepoDisplays(
        prefs.getStringList(RepoStore.githubKey) ?? const <String>[],
        prefs.getStringList(RepoStore.adoKey) ?? const <String>[],
      );
      // On the very first run there is no baseline, so seed silently instead of
      // notifying for every existing item.
      final firstRun = !prefs.containsKey(_seenKey);
      final seen = (prefs.getStringList(_seenKey) ?? const <String>[]).toSet();
      final knownRepos =
          (prefs.getStringList(_knownReposKey) ?? const <String>[]).toSet();
      final newIds = pendingIds(
        seen: seen,
        knownRepos: knownRepos,
        items: items,
        firstRun: firstRun,
      );
      final now = DateTime.now();
      final appPrefs = await PreferencesStore.load();
      // Quiet hours *defer*: we hold the notification and, crucially, do NOT
      // advance the baseline, so these items surface on the next refresh after
      // quiet hours end. A disabled toggle instead *drops* (baseline advances
      // below) so re-enabling never replays a backlog.
      final inQuietHours =
          appPrefs.notificationsEnabled &&
          appPrefs.quietHoursEnabled &&
          PreferencesStore.isWithinQuietHours(
            now,
            appPrefs.quietStartHour,
            appPrefs.quietEndHour,
          );

      if (newIds.isNotEmpty &&
          PreferencesStore.notificationsAllowed(appPrefs, now)) {
        final newItems = items
            .where((item) => newIds.contains(item.id))
            .toList(growable: false);
        await _showSummaryNotification(newItems);
      }

      // Seed on first run always; otherwise hold the baseline while deferring
      // for quiet hours.
      if (shouldAdvanceBaseline(
        firstRun: firstRun,
        inQuietHours: inQuietHours,
      )) {
        // Union so ids are never dropped: a transiently-failed repo keeps its
        // baseline (recovery doesn't re-notify) and one caller's snapshot can't
        // clobber another's. Repos are recorded so their first appearance is
        // only ever seeded once.
        await prefs.setStringList(
          _seenKey,
          mergeSeen(seen, currentIds).toList()..sort(),
        );
        await prefs.setStringList(
          _knownReposKey,
          knownRepos.union(monitoredRepos).toList()..sort(),
        );
      }
    } catch (e) {
      debugPrint('Failed to process attention notifications: $e');
    }
  }

  static Set<String> diffNew(Set<String> seen, Iterable<String> current) =>
      current.toSet().difference(seen);

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
    final currentIds = items.map((item) => item.id).toSet();
    final newRepoItemIds = items
        .where((item) => !knownRepos.contains(item.repoDisplay))
        .map((item) => item.id)
        .toSet();
    return diffNew(seen, currentIds).difference(newRepoItemIds);
  }

  /// The next baseline: the union of the existing [seen] set and the current
  /// snapshot, so ids are never dropped. A very large set (long uptime) resets
  /// to the current snapshot to bound growth.
  @visibleForTesting
  static Set<String> mergeSeen(Set<String> seen, Set<String> currentIds) {
    final merged = seen.union(currentIds);
    return merged.length > _maxSeenIds ? currentIds : merged;
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
      await _plugin.initialize(settings: settings);
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
}
