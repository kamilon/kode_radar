import 'package:flutter/widgets.dart';

/// Decides how the home shell's periodic polling should react to app lifecycle
/// transitions, so we stop hitting the network — draining battery and burning
/// GitHub / Azure DevOps API rate limit — while the app is backgrounded, and
/// refresh promptly when it returns to the foreground.
///
/// This is deliberately pure (no timers, no I/O) so it can be unit tested; the
/// widget owns the actual timers and network calls and delegates the decisions
/// here.
class PollingLifecyclePolicy {
  const PollingLifecyclePolicy({
    this.foregroundPollInterval = const Duration(seconds: 15),
    this.backgroundPollInterval = const Duration(minutes: 2),
    this.autoAddInterval = const Duration(minutes: 10),
    this.keepPollingInBackground = false,
  });

  /// Attention poll cadence while the app is in the foreground.
  final Duration foregroundPollInterval;

  /// Attention poll cadence while the app is backgrounded but still running
  /// (desktop tray). Only used when [keepPollingInBackground] is true.
  final Duration backgroundPollInterval;

  /// Foreground cadence of the auto-add discovery pass; also the threshold for
  /// running a catch-up pass on resume.
  final Duration autoAddInterval;

  /// Whether the app keeps running — and should keep delivering notifications —
  /// while backgrounded. True on desktop, where the window hides to the system
  /// tray but the process keeps running, so polling continues at the slower
  /// [backgroundPollInterval] instead of stopping. False on mobile, where the
  /// OS suspends the process, so polling is fully paused.
  final bool keepPollingInBackground;

  /// Whether [state] means the app is backgrounded (not visible) and polling
  /// should be suspended or slowed.
  ///
  /// True for [AppLifecycleState.paused] (mobile background) and
  /// [AppLifecycleState.hidden] (e.g. a minimized/tray desktop window), but not
  /// for [AppLifecycleState.inactive] — that also fires for a merely-unfocused
  /// but still-visible desktop window or a transient iOS app-switcher peek,
  /// where the foreground cadence should continue (see [isForeground]).
  bool isBackground(AppLifecycleState state) =>
      state == AppLifecycleState.paused || state == AppLifecycleState.hidden;

  /// Whether [state] means the app is at least visible (foreground), so polling
  /// should run at the foreground cadence.
  ///
  /// True for [AppLifecycleState.resumed] and [AppLifecycleState.inactive].
  /// Including `inactive` matters on the way back from the background: the
  /// lifecycle ladder is paused↔hidden↔inactive↔resumed, so a returning app
  /// always passes through `inactive`, and a desktop window shown without focus
  /// may settle on `inactive` without ever reaching `resumed`. Resuming there
  /// too avoids getting stuck at the slow background cadence while visible.
  bool isForeground(AppLifecycleState state) =>
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  /// Whether polling should be fully suspended while backgrounded (mobile),
  /// rather than continuing at [backgroundPollInterval] (desktop tray app).
  bool get suspendsInBackground => !keepPollingInBackground;

  /// The attention poll cadence for the given foreground state.
  Duration pollInterval({required bool foreground}) =>
      foreground ? foregroundPollInterval : backgroundPollInterval;

  /// Whether a resume after being backgrounded for [backgroundedFor] should run
  /// an immediate auto-add discovery pass. True once the background duration
  /// reaches [autoAddInterval], since by then at least one scheduled pass was
  /// skipped.
  bool shouldRunAutoAddOnResume(Duration backgroundedFor) =>
      backgroundedFor >= autoAddInterval;
}
