import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kode_radar/polling_lifecycle.dart';

void main() {
  const policy = PollingLifecyclePolicy(autoAddInterval: Duration(minutes: 10));

  group('isBackground', () {
    test('suspends polling when paused or hidden', () {
      expect(policy.isBackground(AppLifecycleState.paused), isTrue);
      expect(policy.isBackground(AppLifecycleState.hidden), isTrue);
    });

    test('keeps polling when resumed, inactive, or detached', () {
      expect(policy.isBackground(AppLifecycleState.resumed), isFalse);
      expect(policy.isBackground(AppLifecycleState.inactive), isFalse);
      expect(policy.isBackground(AppLifecycleState.detached), isFalse);
    });
  });

  group('isForeground', () {
    test('true when the app is visible (resumed or inactive)', () {
      expect(policy.isForeground(AppLifecycleState.resumed), isTrue);
      expect(policy.isForeground(AppLifecycleState.inactive), isTrue);
    });

    test('false when hidden, paused, or detached', () {
      for (final state in const [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        expect(policy.isForeground(state), isFalse, reason: '$state');
      }
    });

    test('inactive resumes without being treated as background', () {
      // On the way back from the background (paused→hidden→inactive→resumed) the
      // app can settle on inactive; it must count as foreground, not background.
      expect(policy.isBackground(AppLifecycleState.inactive), isFalse);
      expect(policy.isForeground(AppLifecycleState.inactive), isTrue);
    });
  });

  group('shouldRunAutoAddOnResume', () {
    test('runs once the background duration reaches the auto-add interval', () {
      expect(
        policy.shouldRunAutoAddOnResume(const Duration(minutes: 10)),
        isTrue,
      );
      expect(
        policy.shouldRunAutoAddOnResume(const Duration(minutes: 25)),
        isTrue,
      );
    });

    test('does not run for short background stints', () {
      expect(policy.shouldRunAutoAddOnResume(Duration.zero), isFalse);
      expect(
        policy.shouldRunAutoAddOnResume(
          const Duration(minutes: 9, seconds: 59),
        ),
        isFalse,
      );
    });

    test('honors a custom interval', () {
      const custom = PollingLifecyclePolicy(
        autoAddInterval: Duration(minutes: 2),
      );
      expect(
        custom.shouldRunAutoAddOnResume(const Duration(minutes: 2)),
        isTrue,
      );
      expect(
        custom.shouldRunAutoAddOnResume(const Duration(minutes: 1)),
        isFalse,
      );
    });
  });

  group('suspendsInBackground', () {
    test('mobile (default) fully suspends while backgrounded', () {
      expect(policy.suspendsInBackground, isTrue);
    });

    test('desktop tray app keeps polling in the background', () {
      const desktop = PollingLifecyclePolicy(keepPollingInBackground: true);
      expect(desktop.suspendsInBackground, isFalse);
    });
  });

  group('pollInterval', () {
    test('uses the foreground cadence in the foreground', () {
      expect(
        policy.pollInterval(foreground: true),
        const Duration(seconds: 15),
      );
    });

    test('uses the slower background cadence in the background', () {
      expect(
        policy.pollInterval(foreground: false),
        const Duration(minutes: 2),
      );
    });

    test('honors custom cadences', () {
      const custom = PollingLifecyclePolicy(
        foregroundPollInterval: Duration(seconds: 5),
        backgroundPollInterval: Duration(minutes: 5),
      );
      expect(custom.pollInterval(foreground: true), const Duration(seconds: 5));
      expect(
        custom.pollInterval(foreground: false),
        const Duration(minutes: 5),
      );
    });
  });

  test('defaults: 15s foreground, 2m background, 10m auto-add, suspends', () {
    const defaults = PollingLifecyclePolicy();
    expect(defaults.foregroundPollInterval, const Duration(seconds: 15));
    expect(defaults.backgroundPollInterval, const Duration(minutes: 2));
    expect(defaults.autoAddInterval, const Duration(minutes: 10));
    expect(defaults.keepPollingInBackground, isFalse);
  });
}
