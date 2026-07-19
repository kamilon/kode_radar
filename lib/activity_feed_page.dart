import 'package:flutter/material.dart';

import 'activity_event.dart';
import 'activity_event_list.dart';
import 'activity_event_store.dart';
import 'activity_feed_service.dart';
import 'app_http.dart';
import 'config_revision.dart';
import 'home_menu.dart';
import 'identity_store.dart';
import 'preferences_store.dart';
import 'saved_view_store.dart';
import 'seen_store.dart';
import 'sync_state_store.dart';
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

  /// A load (cache render + network refresh) is in flight. Gates the manual
  /// Refresh action so a user can't stack overlapping network fetches/DB writes
  /// on top of an in-flight refresh; cache-first renders still update the UI
  /// underneath it.
  bool _refreshing = true;
  bool _mineOnly = false;
  bool _identitySet = false;
  int _failedSources = 0;
  bool _truncated = false;
  int _lookbackDays = ActivityFeedService.defaultLookback.inDays;
  String? _error;

  /// When the feed last refreshed successfully from the network (persisted), so
  /// the "updated" label stays honest while showing stale cache offline.
  DateTime? _lastSynced;

  /// The previous "last seen" time, captured once, used to flag new events.
  DateTime? _newSince;
  bool _seenCaptured = false;

  // Guards against a stale in-flight load applying after a newer one (e.g. a
  // config-triggered reload); the newest load always wins.
  int _loadSeq = 0;

  /// Selected type groups; empty means "all kinds".
  final Set<String> _groups = <String>{};

  /// Selected team id; null means "all teams".
  String? _teamId;

  @override
  void initState() {
    super.initState();
    configRevision.addListener(_onConfigChanged);
    _load();
  }

  @override
  void dispose() {
    configRevision.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _refreshing = true;
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
      final lookback = Duration(days: appPrefs.feedLookbackDays);

      // Phase A: render the cached feed immediately so a cold start isn't a
      // blank spinner while the network fetch runs (or if it's offline). Only
      // meaningful when we don't already have events on screen.
      if (_events.isEmpty) {
        final cached = await ActivityEventStore.cached(lookback: lookback);
        final lastSynced = await SyncStateStore.lastSuccess(
          SyncStateStore.feedScope,
        );
        if (!mounted || seq != _loadSeq) return;
        if (cached.isNotEmpty) {
          setState(() {
            _events = cached;
            _teams = teams;
            _lookbackDays = appPrefs.feedLookbackDays;
            _lastSynced = lastSynced;
            // The cached render carries no source-health signal, so clear any
            // stale failed/truncated notice from a previous refresh while the
            // new network refresh is still in flight.
            _failedSources = 0;
            _truncated = false;
            if (_teamId != null && !teams.any((t) => t.id == _teamId)) {
              _teamId = null;
            }
            _identitySet = selfGithub.isNotEmpty || selfAdo.isNotEmpty;
          });
        }
      }

      // Phase B: refresh from the network and persist the result to the cache.
      final result = await ActivityFeedService.computeAll(
        client: AppHttp.client,
        selfGithubLogins: selfGithub,
        selfAdoNames: selfAdo,
        lookback: lookback,
      );
      if (!mounted || seq != _loadSeq) return;
      await ActivityEventStore.save(result.events, restrictToMonitored: true);
      if (!mounted || seq != _loadSeq) return;
      // Render the persisted cache (not `result.events` directly) so a fully
      // offline load — where per-source failures yield an empty result rather
      // than an exception — keeps showing cached events instead of blanking,
      // and a partial failure shows the union of fresh + still-cached events.
      final merged = await ActivityEventStore.cached(lookback: lookback);
      if (!mounted || seq != _loadSeq) return;
      // Advance the watermark to the newest event this network refresh
      // returned — a provider timestamp, so device-clock skew can't poison it,
      // and only on a successful load so a failure/quick pop never consumes
      // unseen items. markSeen never moves the marker backwards.
      if (result.events.isNotEmpty) {
        await SeenStore.markSeen(
          SeenStore.feedKey,
          result.events.first.occurredAt,
        );
        if (!mounted || seq != _loadSeq) return;
      }
      // The refresh counts as a successful sync unless it came back empty
      // *because* sources failed (fully offline). Record it so the "updated"
      // label reflects the last real sync, not a cache render.
      final syncedOk = result.events.isNotEmpty || result.failedSources == 0;
      if (syncedOk) {
        await SyncStateStore.markSuccess(SyncStateStore.feedScope);
        if (!mounted || seq != _loadSeq) return;
      }
      setState(() {
        _events = merged;
        _failedSources = result.failedSources;
        _truncated = result.truncated;
        _lookbackDays = appPrefs.feedLookbackDays;
        _teams = teams;
        // Drop a stale team filter if the team was deleted.
        if (_teamId != null && !teams.any((t) => t.id == _teamId)) {
          _teamId = null;
        }
        _identitySet = selfGithub.isNotEmpty || selfAdo.isNotEmpty;
        if (syncedOk) _lastSynced = DateTime.now();
        _refreshing = false;
      });
    } catch (e) {
      debugPrint('ActivityFeed failed to load: $e');
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        // If we already rendered cached events (Phase A), keep them on screen
        // rather than replacing them with an error state; the refresh simply
        // didn't land this time. Only show the error when we have nothing.
        if (_events.isEmpty) {
          _error =
              'Something went wrong while loading the feed. Pull down to try again.';
        }
        _refreshing = false;
      });
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

  /// Show the full-screen spinner only when a load is in flight and there's
  /// nothing cached to render yet; once cache (or fresh) events are on screen,
  /// content stays visible while the network refresh continues underneath.
  bool get _showSpinner => _refreshing && _events.isEmpty && _error == null;

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
            onPressed: _showSpinner
                ? null
                : () => setState(() => _mineOnly = !_mineOnly),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: 'Saved views',
            onPressed: _showSpinner ? null : _openSavedViews,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _load,
          ),
          const HomeMenuButton(),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          if (!_showSpinner && _error == null) sinceLastLookedBanner(_newCount),
          if (!_showSpinner && _error == null)
            activitySourceNotice(
              failedSources: _failedSources,
              truncated: _truncated,
            ),
          Expanded(
            child: _showSpinner
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
        onSelected: _showSpinner ? null : (_) => setState(_groups.clear),
      ),
      for (final group in ActivityType.groups)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: FilterChip(
            label: Text(ActivityType.groupLabel(group)),
            selected: _groups.contains(group),
            onSelected: _showSpinner
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
                    onChanged: _showSpinner
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
            _lastSynced == null
                ? 'Pull down to refresh.'
                : 'Updated ${activityRelativeTime(_lastSynced!)} · pull down to refresh.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      ],
    );
  }
}
