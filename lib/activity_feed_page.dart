import 'package:flutter/material.dart';

import 'activity_event.dart';
import 'activity_event_list.dart';
import 'activity_feed_service.dart';
import 'app_http.dart';
import 'home_menu.dart';
import 'identity_store.dart';
import 'preferences_store.dart';
import 'saved_view_store.dart';
import 'seen_store.dart';
import 'team.dart';
import 'team_store.dart';

/// A reverse-chronological stream of normalized activity across all monitored
/// repositories (PRs opened/merged/closed, reviews, pushes, releases, and CI
/// failures). Filterable by kind, team, and "mine"; tap an item to open it.
class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({super.key});

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  List<ActivityEvent> _events = const [];
  List<Team> _teams = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _mineOnly = false;
  bool _identitySet = false;
  int _failedSources = 0;
  bool _truncated = false;
  int _lookbackDays = ActivityFeedService.defaultLookback.inDays;
  String? _error;
  DateTime? _lastChecked;

  /// The previous "last seen" time, captured once, used to flag new events.
  DateTime? _newSince;
  bool _seenCaptured = false;

  /// Selected type groups; empty means "all kinds".
  final Set<String> _groups = <String>{};

  /// Selected team id; null means "all teams".
  String? _teamId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Capture the previous last-seen once (so "new" highlights stay stable
      // across in-session refreshes). The persisted watermark is advanced only
      // after a successful load, below.
      if (!_seenCaptured) {
        _seenCaptured = true;
        _newSince = await SeenStore.lastSeen(SeenStore.feedKey);
      }
      final teams = await TeamStore.list();
      final selfGithub = await IdentityStore.selfGithubLogins();
      final selfAdo = await IdentityStore.selfAdoNames();
      final appPrefs = await PreferencesStore.load();
      final result = await ActivityFeedService.computeAll(
        client: AppHttp.client,
        selfGithubLogins: selfGithub,
        selfAdoNames: selfAdo,
        lookback: Duration(days: appPrefs.feedLookbackDays),
      );
      if (!mounted) return;
      // Advance the watermark to the newest event we actually loaded — a
      // provider timestamp, so device-clock skew can't poison it, and only on
      // a successful load so a failure/quick pop never consumes unseen items.
      // markSeen never moves the marker backwards.
      if (result.events.isNotEmpty) {
        await SeenStore.markSeen(
          SeenStore.feedKey,
          result.events.first.occurredAt,
        );
        if (!mounted) return;
      }
      setState(() {
        _events = result.events;
        _failedSources = result.failedSources;
        _truncated = result.truncated;
        _lookbackDays = appPrefs.feedLookbackDays;
        _teams = teams;
        // Drop a stale team filter if the team was deleted.
        if (_teamId != null && !teams.any((t) => t.id == _teamId)) {
          _teamId = null;
        }
        _identitySet = selfGithub.isNotEmpty || selfAdo.isNotEmpty;
        _lastChecked = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      debugPrint('ActivityFeed failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Something went wrong while loading the feed. Pull down to try again.';
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  List<ActivityEvent> get _visibleEvents {
    Set<String>? teamRepoKeys;
    if (_teamId != null) {
      final team = _teams.firstWhere(
        (t) => t.id == _teamId,
        orElse: () => const Team(id: '', name: ''),
      );
      teamRepoKeys = team.repoKeys;
    }
    return _events.where((event) {
      if (_mineOnly && !event.isMine) return false;
      if (_groups.isNotEmpty && !_groups.contains(event.group)) return false;
      if (teamRepoKeys != null && !teamRepoKeys.contains(event.repoKey)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// How many currently-visible events are new since the last visit.
  int get _newCount {
    final since = _newSince;
    if (since == null) return 0;
    return _visibleEvents.where((e) => e.occurredAt.isAfter(since)).length;
  }

  void _applyView(SavedView view) {
    setState(() {
      // Keep only groups that still exist (tolerate a renamed/removed group).
      _groups
        ..clear()
        ..addAll(view.groups.where(ActivityType.groups.contains));
      final teamId = view.teamId;
      if (teamId != null &&
          _teams.isNotEmpty &&
          !_teams.any((t) => t.id == teamId)) {
        _teamId = null; // the team was deleted
      } else {
        _teamId = teamId; // keep as-is (also when teams haven't loaded yet)
      }
      _mineOnly = view.mineOnly;
    });
  }

  Future<void> _openSavedViews() async {
    final views = await SavedViewStore.list();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Save current filters as a view…'),
              onTap: () {
                Navigator.pop(sheetContext);
                _saveCurrentView();
              },
            ),
            if (views.isNotEmpty) const Divider(height: 1),
            for (final view in views)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(view.name),
                subtitle: Text(_viewSummary(view)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () async {
                    await SavedViewStore.delete(view.id);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _applyView(view);
                },
              ),
            if (views.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No saved views yet.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentView() async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save view'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      await SavedViewStore.add(
        name: name,
        groups: {..._groups},
        teamId: _teamId,
        mineOnly: _mineOnly,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved view "${name.trim()}"')));
    } finally {
      controller.dispose();
    }
  }

  String _viewSummary(SavedView view) {
    final parts = <String>[];
    if (view.groups.isEmpty) {
      parts.add('All kinds');
    } else {
      parts.add(view.groups.map(ActivityType.groupLabel).join(', '));
    }
    if (view.teamId != null) {
      final team = _teams.firstWhere(
        (t) => t.id == view.teamId,
        orElse: () => const Team(id: '', name: 'a team'),
      );
      parts.add('team: ${team.name}');
    }
    if (view.mineOnly) parts.add('mine');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: Icon(_mineOnly ? Icons.person : Icons.people_outline),
            tooltip: _mineOnly
                ? 'Showing yours — tap for all'
                : 'Show only mine',
            onPressed: _loading
                ? null
                : () => setState(() => _mineOnly = !_mineOnly),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: 'Saved views',
            onPressed: _loading ? null : _openSavedViews,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
          const HomeMenuButton(),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          if (!_loading && _error == null) sinceLastLookedBanner(_newCount),
          if (!_loading && _error == null)
            activitySourceNotice(
              failedSources: _failedSources,
              truncated: _truncated,
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(onRefresh: _load, child: _buildContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final chips = <Widget>[
      FilterChip(
        label: const Text('All'),
        selected: _groups.isEmpty,
        onSelected: _loading ? null : (_) => setState(_groups.clear),
      ),
      for (final group in ActivityType.groups)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: FilterChip(
            label: Text(ActivityType.groupLabel(group)),
            selected: _groups.contains(group),
            onSelected: _loading
                ? null
                : (selected) => setState(() {
                    if (selected) {
                      _groups.add(group);
                    } else {
                      _groups.remove(group);
                    }
                  }),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
          if (_teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.groups, size: 18),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: _teamId,
                    isDense: true,
                    hint: const Text('All teams'),
                    onChanged: _loading
                        ? null
                        : (value) => setState(() => _teamId = value),
                    items: [
                      const DropdownMenuItem<String?>(child: Text('All teams')),
                      for (final team in _teams)
                        DropdownMenuItem<String?>(
                          value: team.id,
                          child: Text(team.name),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    final visible = _visibleEvents;
    if (visible.isEmpty) return _buildEmptyState();

    return ActivityEventList(events: visible, newSince: _newSince);
  }

  Widget _buildEmptyState() {
    final String message;
    if (_events.isEmpty && _failedSources > 0) {
      message = 'Couldn\'t load activity right now. Pull down to retry.';
    } else if (_events.isEmpty) {
      final days = _lookbackDays;
      message = 'No recent activity in the last $days days.';
    } else if (_mineOnly && !_identitySet) {
      message = 'Set your identity in People to use the "Mine" filter.';
    } else {
      message = 'No activity matches the current filters.';
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Center(child: Icon(Icons.timeline, size: 56, color: Colors.grey[400])),
        const SizedBox(height: 12),
        Center(child: Text(message, textAlign: TextAlign.center)),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _lastChecked == null
                ? 'Pull down to refresh.'
                : 'Checked ${activityRelativeTime(_lastChecked!)} · pull down to refresh.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      ],
    );
  }
}
