import 'dart:async';

import 'package:flutter/material.dart';

import 'attention_service.dart';
import 'background_sync.dart';
import 'background_sync_status_store.dart';
import 'preferences_store.dart';

/// Settings screen: notification enablement, quiet hours, the Activity Feed
/// lookback window, and background sync.
class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage>
    with WidgetsBindingObserver {
  AppPreferences _prefs = const AppPreferences();
  BackgroundSyncStatus? _bgStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A background run may have recorded a new status while we were backgrounded
    // with Settings open; refresh it on resume so the tile isn't stale.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshBackgroundStatus());
    }
  }

  Future<void> _load() async {
    final prefs = await PreferencesStore.load();
    final bgStatus = BackgroundSync.isSupported
        ? await BackgroundSyncStatusStore.read()
        : null;
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _bgStatus = bgStatus;
      _loading = false;
    });
  }

  Future<void> _refreshBackgroundStatus() async {
    if (!BackgroundSync.isSupported) return;
    final bgStatus = await BackgroundSyncStatusStore.read();
    if (!mounted) return;
    setState(() => _bgStatus = bgStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionHeader('Notifications'),
                SwitchListTile(
                  title: const Text('Attention notifications'),
                  subtitle: const Text(
                    'Notify when new items need your attention',
                  ),
                  value: _prefs.notificationsEnabled,
                  onChanged: (value) async {
                    await PreferencesStore.setNotificationsEnabled(value);
                    if (!mounted) return;
                    setState(
                      () =>
                          _prefs = _prefs.copyWith(notificationsEnabled: value),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Quiet hours'),
                  subtitle: Text(_quietHoursSubtitle()),
                  value: _prefs.quietHoursEnabled,
                  onChanged: _prefs.notificationsEnabled
                      ? (value) async {
                          await PreferencesStore.setQuietHoursEnabled(value);
                          if (!mounted) return;
                          setState(
                            () => _prefs = _prefs.copyWith(
                              quietHoursEnabled: value,
                            ),
                          );
                        }
                      : null,
                ),
                if (_prefs.notificationsEnabled &&
                    _prefs.quietHoursEnabled) ...[
                  _hourTile(
                    label: 'From',
                    hour: _prefs.quietStartHour,
                    onChanged: (hour) async {
                      await PreferencesStore.setQuietStartHour(hour);
                      if (!mounted) return;
                      setState(
                        () => _prefs = _prefs.copyWith(quietStartHour: hour),
                      );
                    },
                  ),
                  _hourTile(
                    label: 'Until',
                    hour: _prefs.quietEndHour,
                    onChanged: (hour) async {
                      await PreferencesStore.setQuietEndHour(hour);
                      if (!mounted) return;
                      setState(
                        () => _prefs = _prefs.copyWith(quietEndHour: hour),
                      );
                    },
                  ),
                ],
                SwitchListTile(
                  title: const Text('Daily digest'),
                  subtitle: const Text(
                    'One summary a day instead of per-change alerts',
                  ),
                  value: _prefs.digestModeEnabled,
                  onChanged: _prefs.notificationsEnabled
                      ? (value) async {
                          await PreferencesStore.setDigestModeEnabled(value);
                          if (!mounted) return;
                          setState(
                            () => _prefs = _prefs.copyWith(
                              digestModeEnabled: value,
                            ),
                          );
                        }
                      : null,
                ),
                if (_prefs.notificationsEnabled && _prefs.digestModeEnabled)
                  _hourTile(
                    label: 'Digest time',
                    hour: _prefs.digestHour,
                    onChanged: (hour) async {
                      await PreferencesStore.setDigestHour(hour);
                      if (!mounted) return;
                      setState(
                        () => _prefs = _prefs.copyWith(digestHour: hour),
                      );
                    },
                  ),
                SwitchListTile(
                  title: const Text('Only my PRs & reviews'),
                  subtitle: const Text(
                    'Notify only for items you authored or were asked to '
                    'review',
                  ),
                  value: _prefs.notifyMineOnly,
                  onChanged: _prefs.notificationsEnabled
                      ? (value) async {
                          await PreferencesStore.setNotifyMineOnly(value);
                          if (!mounted) return;
                          setState(
                            () =>
                                _prefs = _prefs.copyWith(notifyMineOnly: value),
                          );
                        }
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Notify me about',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final category in AttentionService.notifiableCategories)
                  SwitchListTile(
                    dense: true,
                    title: Text(AttentionService.categoryLabel(category)),
                    value: !_prefs.silencedNotifyCategories.contains(category),
                    onChanged: _prefs.notificationsEnabled
                        ? (enabled) async {
                            await PreferencesStore.setCategorySilenced(
                              category,
                              !enabled,
                            );
                            if (!mounted) return;
                            setState(() {
                              final next = {..._prefs.silencedNotifyCategories};
                              if (enabled) {
                                next.remove(category);
                              } else {
                                next.add(category);
                              }
                              _prefs = _prefs.copyWith(
                                silencedNotifyCategories: next,
                              );
                            });
                          }
                        : null,
                  ),
                const Divider(),
                _sectionHeader('Activity Feed'),
                ListTile(
                  title: const Text('Lookback window'),
                  subtitle: const Text('How far back the feed reaches'),
                  trailing: DropdownButton<int>(
                    value: _prefs.feedLookbackDays,
                    onChanged: (value) async {
                      if (value == null) return;
                      await PreferencesStore.setFeedLookbackDays(value);
                      if (!mounted) return;
                      setState(
                        () => _prefs = _prefs.copyWith(feedLookbackDays: value),
                      );
                    },
                    items: [
                      for (final days in PreferencesStore.lookbackOptions)
                        DropdownMenuItem(
                          value: days,
                          child: Text('$days days'),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                _sectionHeader('Sync'),
                SwitchListTile(
                  title: const Text('Background sync'),
                  subtitle: Text(
                    BackgroundSync.isSupported
                        ? 'Refresh periodically in the background (best-effort '
                              'on iOS). “Sync now” in the menu works anytime.'
                        : 'This desktop app refreshes while it is running.',
                  ),
                  value:
                      _prefs.backgroundSyncEnabled &&
                      BackgroundSync.isSupported,
                  onChanged: BackgroundSync.isSupported
                      ? (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = value
                              ? await BackgroundSync.enable()
                              : await BackgroundSync.disable();
                          if (!ok) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? 'Could not enable background sync.'
                                      : 'Could not disable background sync.',
                                ),
                              ),
                            );
                            return; // leave the switch and stored pref as-is
                          }
                          await PreferencesStore.setBackgroundSyncEnabled(
                            value,
                          );
                          if (!mounted) return;
                          setState(
                            () => _prefs = _prefs.copyWith(
                              backgroundSyncEnabled: value,
                            ),
                          );
                        }
                      : null,
                ),
                if (BackgroundSync.isSupported)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 20),
                    title: const Text('Last background run'),
                    subtitle: Text(_backgroundRunSubtitle()),
                  ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _hourTile({
    required String label,
    required int hour,
    required ValueChanged<int> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      title: Text(label),
      trailing: DropdownButton<int>(
        value: hour,
        onChanged: (value) => value == null ? null : onChanged(value),
        items: [
          for (var h = 0; h < 24; h++)
            DropdownMenuItem(value: h, child: Text(_formatHour(h))),
        ],
      ),
    );
  }

  String _quietHoursSubtitle() {
    if (!_prefs.quietHoursEnabled) return 'Notifications are never silenced';
    return 'Silence ${_formatHour(_prefs.quietStartHour)} – '
        '${_formatHour(_prefs.quietEndHour)}';
  }

  /// Describes the most recent background run for the read-only status tile.
  String _backgroundRunSubtitle() {
    final status = _bgStatus;
    if (status == null) return 'Hasn\'t run yet';
    final when = _relativeTime(status.at);
    if (!status.finished) return 'Started $when · didn\'t finish';
    if (!status.activityOk) return 'Ran $when · activity refresh failed';
    final repos = status.repoCount == 1
        ? '1 repo'
        : '${status.repoCount} repos';
    return 'Ran $when · $repos';
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.isNegative || diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }

  String _formatHour(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $period';
  }
}
