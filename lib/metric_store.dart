import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_service.dart';
import 'metric_snapshot.dart';

class MetricStore {
  MetricStore._();

  static const String storageKey = 'metric_history';
  static const int maxPerRepo = 60;
  static const Duration minCaptureInterval = Duration(hours: 24);

  static Future<void> _lock = Future<void>.value();

  static Future<T> runLocked<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    // Keep the chain alive whether the action succeeds or fails.
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }

  static bool shouldCapture(DateTime? lastAt, DateTime now) =>
      lastAt == null || now.difference(lastAt) >= minCaptureInterval;

  static Future<void> capture(List<RepoActivity> activities, {DateTime? now}) {
    final capturedAt = (now ?? DateTime.now()).toUtc();
    return runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final histories = _readFrom(prefs);
      var changed = false;

      for (final activity in activities) {
        if (activity.error != null) {
          continue;
        }

        final history = histories.putIfAbsent(
          activity.repoKey,
          () => <MetricSnapshot>[],
        );
        final lastAt = history.isEmpty ? null : history.last.at;
        if (!shouldCapture(lastAt, capturedAt)) {
          continue;
        }

        history.add(
          MetricSnapshot(
            at: capturedAt,
            openPrs: activity.openPrCount,
            needsReview: activity.needsReviewCount,
            activityScore: activity.activityScore,
          ),
        );
        if (history.length > maxPerRepo) {
          history.removeRange(0, history.length - maxPerRepo);
        }
        changed = true;
      }

      if (changed) {
        await _writeTo(prefs, histories);
      }
    });
  }

  static Future<Map<String, List<MetricSnapshot>>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return _readFrom(prefs);
  }

  static Future<List<MetricSnapshot>> historyFor(String repoKey) async {
    final histories = await all();
    return List<MetricSnapshot>.of(
      histories[repoKey] ?? const <MetricSnapshot>[],
    );
  }

  static Future<List<num>> seriesFor(
    String repoKey, {
    String metric = 'activityScore',
  }) async {
    final history = await historyFor(repoKey);
    return switch (metric) {
      'openPrs' => history.map<num>((snapshot) => snapshot.openPrs).toList(),
      'needsReview' =>
        history.map<num>((snapshot) => snapshot.needsReview).toList(),
      'activityScore' =>
        history.map<num>((snapshot) => snapshot.activityScore).toList(),
      _ => _unknownMetric(metric),
    };
  }

  static List<num> _unknownMetric(String metric) {
    debugPrint('MetricStore unknown metric "$metric"');
    return <num>[];
  }

  static Map<String, List<MetricSnapshot>> _readFrom(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, List<MetricSnapshot>>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        debugPrint('MetricStore expected $storageKey to be a JSON map.');
        return <String, List<MetricSnapshot>>{};
      }

      final histories = <String, List<MetricSnapshot>>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! List) {
          continue;
        }

        final snapshots = <MetricSnapshot>[];
        for (final item in value) {
          if (item is! Map) {
            continue;
          }

          final snapshot = MetricSnapshot.fromJson(item);
          if (snapshot != null) {
            snapshots.add(snapshot);
          }
        }
        histories[key] = snapshots;
      }
      return histories;
    } catch (e) {
      debugPrint('MetricStore failed to read $storageKey: $e');
      return <String, List<MetricSnapshot>>{};
    }
  }

  static Future<void> _writeTo(
    SharedPreferences prefs,
    Map<String, List<MetricSnapshot>> histories,
  ) {
    final encoded = histories.map(
      (repoKey, snapshots) => MapEntry(
        repoKey,
        snapshots.map((snapshot) => snapshot.toJson()).toList(),
      ),
    );
    return prefs.setString(storageKey, jsonEncode(encoded));
  }
}
