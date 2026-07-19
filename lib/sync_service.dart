import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_event_store.dart';
import 'activity_feed_service.dart';
import 'activity_service.dart';
import 'app_http.dart';
import 'attention_service.dart';
import 'attention_store.dart';
import 'identity_store.dart';
import 'metric_store.dart';
import 'monitored_repos.dart';
import 'notification_service.dart';
import 'preferences_store.dart';
import 'repo_store.dart';
import 'snooze_store.dart';
import 'sync_state_store.dart';

/// Outcome of a sync. [activityOk] reflects whether the repo-activity + trend
/// capture half succeeded (the part a manual "Sync now" reports on); attention
/// notifications are best-effort and don't affect it.
class SyncResult {
  const SyncResult({required this.activityOk, required this.repoCount});
  final bool activityOk;
  final int repoCount;
}

/// The "refresh everything" path shared by the manual "Sync now" action and the
/// background-sync isolate. (The foreground surfaces still capture on load and
/// poll attention on their own timers; this centralizes the on-demand and
/// background paths.)
///
/// It refreshes repo activity and records a trend snapshot, refreshes the
/// attention inbox (notifying for anything new and persisting its cache), and
/// refreshes the activity-feed cache, so the offline caches and their "Updated"
/// provenance are current even when the sync ran in the background. It never
/// throws — each phase is isolated so a failure in one doesn't skip the others.
class SyncService {
  SyncService._();

  /// Runs one full sync. Pass [force] to bypass the trend-capture interval (used
  /// by "Sync now" so it always records a data point). Pass [background] to run
  /// the phases concurrently under a deadline that fits iOS's tight
  /// `BGAppRefreshTask` budget.
  static Future<SyncResult> runOnce({
    http.Client? client,
    bool force = false,
    bool background = false,
  }) async {
    final httpClient = client ?? AppHttp.client;
    final deadline = background ? const Duration(seconds: 25) : null;

    // Freshen the config cache from disk: a reused background isolate could hold
    // a stale monitored-repo list / preferences, which would skew the
    // `restrictToMonitored` cache prune and the provenance monitored-count.
    // Swallow failures so runOnce keeps its never-throw contract.
    try {
      await (await SharedPreferences.getInstance()).reload();
    } catch (e, st) {
      debugPrint('SyncService: prefs reload failed: $e\n$st');
    }

    // NOTE: the per-repo cache writes below are serialized only within an
    // isolate (each store's static lock). A background run happens while the app
    // is suspended, so it rarely overlaps a foreground write; if it did, the
    // later snapshot could briefly overwrite a newer one — self-corrected on the
    // next foreground load. A cross-isolate write-generation guard is a possible
    // follow-up.

    Future<T> withDeadline<T>(Future<T> future) =>
        deadline == null ? future : future.timeout(deadline);

    Future<SyncResult> activityPhase() async {
      try {
        final activities = await withDeadline(
          ActivityService.computeAll(client: httpClient),
        );
        await MetricStore.capture(
          activities,
          restrictToMonitored: true,
          force: force,
        );
        return SyncResult(activityOk: true, repoCount: activities.length);
      } catch (e, st) {
        debugPrint('SyncService: activity/capture failed: $e\n$st');
        return const SyncResult(activityOk: false, repoCount: 0);
      }
    }

    Future<void> attentionPhase() async {
      try {
        final snoozed = await SnoozeStore.snoozedIds();
        final selfGithub = await IdentityStore.selfGithubLogins();
        final selfAdo = await IdentityStore.selfAdoNames();
        // Compute WITHOUT snooze filtering so the persisted cache sees each
        // repo's true success/failure (matching the inbox page); snooze is
        // applied only when notifying.
        final items = await withDeadline(
          AttentionService.computeAll(
            client: httpClient,
            selfGithubLogins: selfGithub,
            selfAdoNames: selfAdo,
          ),
        );
        await AttentionStore.save(items);
        // Provenance: a real sync unless every monitored repo errored. Count
        // errored repos by distinct repoDisplay to line up with monitoredCount
        // (which parseMonitoredRepos de-dupes by repoKey).
        final erroredRepos = items
            .where((i) => i.category == AttentionStore.errorCategory)
            .map((i) => i.repoDisplay)
            .toSet()
            .length;
        final prefs = await SharedPreferences.getInstance();
        final monitoredCount = parseMonitoredRepos(
          prefs.getStringList(RepoStore.githubKey) ?? const <String>[],
          prefs.getStringList(RepoStore.adoKey) ?? const <String>[],
        ).length;
        if (monitoredCount == 0 || erroredRepos < monitoredCount) {
          await SyncStateStore.markSuccess(SyncStateStore.attentionScope);
        }
        await NotificationService.notifyNewAttention(
          items.where((i) => !snoozed.contains(i.id)).toList(),
        );
      } catch (e, st) {
        debugPrint('SyncService: attention failed: $e\n$st');
      }
    }

    Future<void> feedPhase() async {
      try {
        final appPrefs = await PreferencesStore.load();
        final lookback = Duration(days: appPrefs.feedLookbackDays);
        final selfGithub = await IdentityStore.selfGithubLogins();
        final selfAdo = await IdentityStore.selfAdoNames();
        final result = await withDeadline(
          ActivityFeedService.computeAll(
            client: httpClient,
            lookback: lookback,
            // Pass identities so cached events keep their correct `isMine`
            // instead of being overwritten as not-mine.
            selfGithubLogins: selfGithub,
            selfAdoNames: selfAdo,
          ),
        );
        await ActivityEventStore.save(result.events, restrictToMonitored: true);
        if (result.failedSources == 0 || result.okSources > 0) {
          await SyncStateStore.markSuccess(SyncStateStore.feedScope);
        }
      } catch (e, st) {
        debugPrint('SyncService: feed cache failed: $e\n$st');
      }
    }

    if (background) {
      // Concurrent to fit the budget; each phase is independently deadlined and
      // its errors isolated.
      late SyncResult result;
      await Future.wait([
        activityPhase().then((r) => result = r),
        attentionPhase(),
        feedPhase(),
      ]);
      return result;
    }

    final result = await activityPhase();
    await attentionPhase();
    await feedPhase();
    return result;
  }
}
