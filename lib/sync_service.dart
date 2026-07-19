import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'activity_service.dart';
import 'app_http.dart';
import 'attention_service.dart';
import 'identity_store.dart';
import 'metric_store.dart';
import 'notification_service.dart';
import 'snooze_store.dart';

/// The single "refresh everything" path, shared by the foreground poll, the
/// manual "Sync now" action, and the background-sync isolate.
///
/// It refreshes repo activity and records a trend snapshot, then recomputes the
/// attention inbox and notifies for anything new. It never throws — each half
/// is isolated so a failure in one doesn't skip the other.
class SyncService {
  SyncService._();

  /// Runs one full sync. Pass [force] to bypass the trend-capture interval (used
  /// by "Sync now" so it always records a data point). Returns the number of
  /// monitored repos observed, for a lightweight UI confirmation.
  static Future<int> runOnce({http.Client? client, bool force = false}) async {
    final httpClient = client ?? AppHttp.client;

    var repoCount = 0;
    try {
      final activities = await ActivityService.computeAll(client: httpClient);
      repoCount = activities.length;
      await MetricStore.capture(
        activities,
        restrictToMonitored: true,
        force: force,
      );
    } catch (e) {
      debugPrint('SyncService: activity/capture failed: $e');
    }

    try {
      final snoozed = await SnoozeStore.snoozedIds();
      final selfGithub = await IdentityStore.selfGithubLogins();
      final selfAdo = await IdentityStore.selfAdoNames();
      final items = await AttentionService.computeAll(
        client: httpClient,
        snoozedIds: snoozed,
        selfGithubLogins: selfGithub,
        selfAdoNames: selfAdo,
      );
      await NotificationService.notifyNewAttention(items);
    } catch (e) {
      debugPrint('SyncService: attention failed: $e');
    }

    return repoCount;
  }
}
