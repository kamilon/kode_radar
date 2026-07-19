import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'sync_service.dart';

/// The background task identifier. Must match the iOS `BGTaskScheduler`
/// identifier in `Info.plist` and the one registered in `AppDelegate.swift`.
const String backgroundSyncTask = 'com.kamilon.koderadar.sync';

/// Entry point invoked by workmanager on a background isolate. Must be a
/// top-level function annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await NotificationService.init();
      final result = await SyncService.runOnce(background: true);
      // Report failure so the OS can retry/reschedule when nothing useful ran.
      return result.activityOk;
    } catch (e, st) {
      debugPrint('Background sync task failed: $e\n$st');
      return false;
    }
  });
}

/// Registers/cancels the periodic background sync. Mobile only; on desktop the
/// app keeps polling while it runs, so this is a no-op. iOS execution is
/// OS-scheduled/best-effort; Android runs roughly every 15 minutes.
class BackgroundSync {
  BackgroundSync._();

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await Workmanager().initialize(backgroundSyncCallbackDispatcher);
    _initialized = true;
  }

  /// Registers the periodic task. On unsupported platforms (desktop) this is a
  /// no-op and returns true. Returns false (and logs) only if registration
  /// actually fails, so the caller can surface a real error.
  static Future<bool> enable() async {
    if (!isSupported) return true;
    try {
      await _ensureInitialized();
      if (Platform.isAndroid) {
        await Workmanager().registerPeriodicTask(
          backgroundSyncTask,
          backgroundSyncTask,
          frequency: const Duration(minutes: 15),
          initialDelay: const Duration(minutes: 5),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      } else {
        // iOS: frequency is ignored (the OS schedules BGAppRefreshTask at its
        // own discretion, minimum ~15 min).
        await Workmanager().registerPeriodicTask(
          backgroundSyncTask,
          backgroundSyncTask,
          initialDelay: const Duration(minutes: 1),
          inputData: <String, dynamic>{},
        );
      }
      return true;
    } catch (e) {
      debugPrint('BackgroundSync.enable failed: $e');
      return false;
    }
  }

  static Future<bool> disable() async {
    if (!isSupported) return true;
    try {
      await _ensureInitialized();
      // Cancel only our task, not any other work the app might schedule later.
      await Workmanager().cancelByUniqueName(backgroundSyncTask);
      return true;
    } catch (e) {
      debugPrint('BackgroundSync.disable failed: $e');
      return false;
    }
  }
}
