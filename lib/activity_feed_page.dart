import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_event.dart';
import 'activity_feed_service.dart';
import 'app_http.dart';
import 'identity_store.dart';
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
  String? _error;
  DateTime? _lastChecked;

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
      final teams = await TeamStore.list();
      final selfGithub = await IdentityStore.selfGithubLogins();
      final selfAdo = await IdentityStore.selfAdoNames();
      final result = await ActivityFeedService.computeAll(
        client: AppHttp.client,
        selfGithubLogins: selfGithub,
        selfAdoNames: selfAdo,
      );
      if (!mounted) return;
      setState(() {
        _events = result.events;
        _failedSources = result.failedSources;
        _truncated = result.truncated;
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          if (!_loading && _error == null && (_failedSources > 0 || _truncated))
            _buildNotice(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(onRefresh: _load, child: _buildContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    final parts = <String>[];
    if (_failedSources > 0) {
      parts.add(
        '$_failedSources source${_failedSources == 1 ? '' : 's'} '
        'couldn\'t be loaded',
      );
    }
    if (_truncated) parts.add('older items may be omitted');
    // Retrying only helps when a source actually failed; truncation won't
    // change on refresh.
    final suffix = _failedSources > 0 ? ' Pull to retry.' : '';
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${parts.join(' · ')}.$suffix',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
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

    final rows = _buildRows(visible);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.header != null) return _buildDayHeader(row.header!);
        return _buildEventTile(row.event!);
      },
    );
  }

  Widget _buildEmptyState() {
    final String message;
    if (_events.isEmpty && _failedSources > 0) {
      message = 'Couldn\'t load activity right now. Pull down to retry.';
    } else if (_events.isEmpty) {
      final days = ActivityFeedService.defaultLookback.inDays;
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
                : 'Checked ${_relativeTime(_lastChecked!)} · pull down to refresh.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      ],
    );
  }

  List<_FeedRow> _buildRows(List<ActivityEvent> events) {
    final rows = <_FeedRow>[];
    String? currentDay;
    for (final event in events) {
      final day = _dayLabel(event.occurredAt.toLocal());
      if (day != currentDay) {
        currentDay = day;
        rows.add(_FeedRow.header(day));
      }
      rows.add(_FeedRow.event(event));
    }
    return rows;
  }

  Widget _buildDayHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEventTile(ActivityEvent event) {
    final visual = _visualFor(event.type);
    return ListTile(
      leading: Icon(visual.icon, color: visual.color),
      title: Text(event.title),
      subtitle: Text(
        '${event.subtitle} · ${_relativeTime(event.occurredAt.toLocal())}',
      ),
      trailing: event.url != null
          ? const Icon(Icons.open_in_new, size: 16)
          : null,
      onTap: event.url == null ? null : () => _open(event.url!),
    );
  }

  ({IconData icon, Color color}) _visualFor(String type) {
    switch (type) {
      case ActivityType.prOpened:
        return (icon: Icons.merge_type, color: Colors.green);
      case ActivityType.prMerged:
        return (icon: Icons.merge, color: Colors.purple);
      case ActivityType.prClosed:
        return (icon: Icons.cancel_outlined, color: Colors.blueGrey);
      case ActivityType.reviewSubmitted:
        return (icon: Icons.rate_review, color: Colors.orange);
      case ActivityType.push:
        return (icon: Icons.commit, color: Colors.blue);
      case ActivityType.release:
        return (icon: Icons.rocket_launch, color: Colors.teal);
      case ActivityType.ciFailed:
        return (icon: Icons.error_outline, color: Colors.red);
      default:
        return (icon: Icons.circle_notifications, color: Colors.grey);
    }
  }

  /// "Today" / "Yesterday" / "Mon, Jul 14".
  String _dayLabel(DateTime local) {
    final now = DateTime.now();
    // Compare via UTC-midnight anchors so calendar-day math stays exact across
    // DST transitions (local midnights can be 23/25h apart).
    final today = DateTime.utc(now.year, now.month, now.day);
    final that = DateTime.utc(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[local.weekday - 1];
    final month = months[local.month - 1];
    return '$weekday, $month ${local.day}';
  }

  String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.isNegative) return 'just now';
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showOpenError(url);
      return;
    }
    final canLaunch = await canLaunchUrl(uri);
    if (!mounted) return;
    if (!canLaunch) {
      _showOpenError(url);
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) _showOpenError(url);
  }

  void _showOpenError(String url) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

/// A row in the flattened feed: either a day header or an event.
class _FeedRow {
  const _FeedRow.header(this.header) : event = null;
  const _FeedRow.event(this.event) : header = null;

  final String? header;
  final ActivityEvent? event;
}
