import 'package:flutter/material.dart';

import 'background_sync.dart';
import 'preferences_store.dart';

/// Settings screen: notification enablement, quiet hours, the Activity Feed
/// lookback window, and background sync.
class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  AppPreferences _prefs = const AppPreferences();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PreferencesStore.load();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
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
                  value: _prefs.backgroundSyncEnabled,
                  onChanged: BackgroundSync.isSupported
                      ? (value) async {
                          await PreferencesStore.setBackgroundSyncEnabled(
                            value,
                          );
                          if (value) {
                            await BackgroundSync.enable();
                          } else {
                            await BackgroundSync.disable();
                          }
                          if (!mounted) return;
                          setState(
                            () => _prefs = _prefs.copyWith(
                              backgroundSyncEnabled: value,
                            ),
                          );
                        }
                      : null,
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

  String _formatHour(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $period';
  }
}
