import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The recorded state of the most recent *background* sync run.
///
/// Only background runs are recorded (a foreground "Sync now" is user-initiated
/// and self-evident), so this is an honest signal for "did the OS actually run
/// my background task, and did it finish?".
///
/// A run is recorded in two steps: [BackgroundSyncStatusStore.recordStarted]
/// when the OS launches the task (so a task that is later killed or expires
/// still shows it started), then [BackgroundSyncStatusStore.recordFinished]
/// with the outcome once the work completes.
@immutable
class BackgroundSyncStatus {
  const BackgroundSyncStatus({
    required this.at,
    required this.finished,
    required this.activityOk,
    required this.repoCount,
  });

  /// When this state was recorded (task launch, or completion).
  final DateTime at;

  /// Whether the run completed. False means the task started but was killed /
  /// expired / failed before finishing (a common iOS background outcome).
  final bool finished;

  /// Whether the repo-activity/trend half of the sync succeeded (only
  /// meaningful when [finished]). This mirrors what "Sync now" reports and what
  /// the OS uses to decide whether to reschedule.
  final bool activityOk;

  /// How many repositories the run processed (only meaningful when [finished]).
  final int repoCount;

  Map<String, dynamic> toJson() => {
    'at': at.toUtc().millisecondsSinceEpoch,
    'finished': finished,
    'activityOk': activityOk,
    'repoCount': repoCount,
  };

  /// Parses a stored entry, or null if it is malformed (missing/invalid
  /// timestamp, or not a map).
  static BackgroundSyncStatus? fromJson(Object? json) {
    if (json is! Map) return null;
    final atMillis = json['at'];
    if (atMillis is! int) return null;
    final DateTime at;
    try {
      at = DateTime.fromMillisecondsSinceEpoch(atMillis, isUtc: true);
    } catch (_) {
      return null;
    }
    final finished = json['finished'];
    final activityOk = json['activityOk'];
    final repoCount = json['repoCount'];
    return BackgroundSyncStatus(
      at: at,
      // Default to finished for a partial/legacy record so it never sticks on
      // "didn't finish".
      finished: finished is bool ? finished : true,
      activityOk: activityOk is bool ? activityOk : false,
      repoCount: repoCount is int ? repoCount : 0,
    );
  }
}

/// Persists [BackgroundSyncStatus] in SharedPreferences so the foreground UI can
/// show when the background sync last ran (and whether it finished). The value
/// is written from the background isolate and read from the foreground, so
/// [read] reloads from disk first to cross the isolate boundary.
class BackgroundSyncStatusStore {
  BackgroundSyncStatusStore._();

  static const String _key = 'background_sync_status';

  static Future<void> _lock = Future<void>.value();

  static Future<T> _runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static Future<void> _write(BackgroundSyncStatus status) {
    return _runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(status.toJson()));
    });
  }

  /// Records that the OS just launched the background task (defaults [at] to
  /// now). If the task is later killed/expires this leaves an honest
  /// "started but didn't finish" marker.
  static Future<void> recordStarted({DateTime? at}) {
    return _write(
      BackgroundSyncStatus(
        at: at ?? DateTime.now(),
        finished: false,
        activityOk: false,
        repoCount: 0,
      ),
    );
  }

  /// Records that the background run finished with [activityOk]/[repoCount]
  /// (defaults [at] to now).
  static Future<void> recordFinished({
    required bool activityOk,
    required int repoCount,
    DateTime? at,
  }) {
    return _write(
      BackgroundSyncStatus(
        at: at ?? DateTime.now(),
        finished: true,
        activityOk: activityOk,
        repoCount: repoCount,
      ),
    );
  }

  /// The most recent recorded background state, or null if it has never run (or
  /// the stored value is malformed).
  static Future<BackgroundSyncStatus?> read() async {
    final prefs = await SharedPreferences.getInstance();
    // The record is written on a background isolate, so refresh this isolate's
    // cached view from disk before reading. Swallow failures (best-effort).
    try {
      await prefs.reload();
    } catch (e) {
      debugPrint('BackgroundSyncStatusStore: reload failed: $e');
    }
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return BackgroundSyncStatus.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
