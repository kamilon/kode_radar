import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Receive notification taps so flutter_local_notifications can forward the
    // tapped payload (and launch details) to Dart. The iOS plugin registers as
    // an application delegate but does not set the UNUserNotificationCenter
    // delegate itself, so we must — otherwise taps are never delivered.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    // Make plugins available to the background isolate that workmanager spins up
    // for BGTaskScheduler work.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // Must match backgroundSyncTask in lib/background_sync.dart and the
    // BGTaskSchedulerPermittedIdentifiers entry in Info.plist. iOS schedules it
    // at its own discretion (minimum ~15 min).
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.kamilon.koderadar.sync",
      frequency: NSNumber(value: 15 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
