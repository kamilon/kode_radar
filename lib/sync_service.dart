import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'activity_service.dart';
import 'app_http.dart';
import 'attention_service.dart';
import 'identity_store.dart';
import 'metric_store.dart';
import 'notification_service.dart';
import 'snooze_store.dart';

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
/// It refreshes repo activity and records a trend snapshot, then recomputes the
/// attention inbox and notifies for anything new. It never throws — each half
/// is isolated so a failure in one doesn't skip the other.
class SyncService {
  SyncService._();

  /// Runs one full sync. Pass [force] to bypass the trend-capture interval (used
  /// by "Sync now" so it always records a data point). Pass [background] to run
  /// the two halves concurrently under a deadline that fits iOS's tight
  /// `BGAppRefreshTask` budget.
  static Future<SyncResult> runOnce({
    http.Client? client,
    bool force = false,
    bool background = false,
  }) async {
    final httpClient = client ?? AppHttp.client;
    final deadline = background ? const Duration(seconds: 25) : null;

    Future<SyncResult> activityPhase() async {
      try {
        final future = ActivityService.computeAll(client: httpClient);
        final activities = deadline == null
            ? await future
            : await future.timeout(deadline);
        await MetricStore.capture(
          activities,
          restrictToMonitored: true,
          force: force,
        );
        return SyncResult(activityOk: true, repoCount: activities.length);
      } catch (e) {
        debugPrint('SyncService: activity/capture failed: $e');
        return const SyncResult(activityOk: false, repoCount: 0);
      }
    }

    Future<void> attentionPhase() async {
      try {
        final snoozed = await SnoozeStore.snoozedIds();
        final selfGithub = await IdentityStore.selfGithubLogins();
        final selfAdo = await IdentityStore.selfAdoNames();
        final future = AttentionService.computeAll(
          client: httpClient,
          snoozedIds: snoozed,
          selfGithubLogins: selfGithub,
          selfAdoNames: selfAdo,
        );
        final items = deadline == null
            ? await future
            : await future.timeout(deadline);
        await NotificationService.notifyNewAttention(items);
      } catch (e) {
        debugPrint('SyncService: attention failed: $e');
      }
    }

    if (background) {
      // Concurrent to fit the budget; each phase is independently deadlined and
      // its errors isolated.
      late SyncResult result;
      await Future.wait([
        activityPhase().then((r) => result = r),
        attentionPhase(),
      ]);
      return result;
    }

    final result = await activityPhase();
    await attentionPhase();
    return result;
  }
}
