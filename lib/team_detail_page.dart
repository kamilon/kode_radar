import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_event.dart';
import 'activity_event_list.dart';
import 'activity_feed_service.dart';
import 'activity_service.dart';
import 'app_http.dart';
import 'team.dart';
import 'team_service.dart';

/// Drill-down for a single [Team]: a rollup header plus two tabs — the team's
/// repositories (with per-repo activity) and a feed of recent activity across
/// those repositories.
class TeamDetailPage extends StatefulWidget {
  const TeamDetailPage({super.key, required this.team});

  final Team team;

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  List<RepoActivity> _repos = const [];
  List<ActivityEvent> _events = const [];
  TeamRollup? _rollup;
  bool _loading = true;
  int _failedSources = 0;
  bool _truncated = false;
  String? _error;

  Team get _team => widget.team;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch repo activity and the feed concurrently, both scoped to the
      // team's repositories. The awaited Future.wait sits inside the try/catch,
      // so a failure in either fetch is handled here.
      final results = await Future.wait([
        ActivityService.computeAll(
          client: AppHttp.client,
          onlyRepoKeys: _team.repoKeys,
        ),
        ActivityFeedService.computeAll(
          client: AppHttp.client,
          onlyRepoKeys: _team.repoKeys,
        ),
      ]);
      final activities = results[0] as List<RepoActivity>;
      final feed = results[1] as ActivityFeedResult;
      final repos =
          activities.where((a) => _team.repoKeys.contains(a.repoKey)).toList()
            ..sort((a, b) {
              final byScore = b.activityScore.compareTo(a.activityScore);
              return byScore != 0
                  ? byScore
                  : a.displayName.toLowerCase().compareTo(
                      b.displayName.toLowerCase(),
                    );
            });
      if (!mounted) return;
      setState(() {
        _repos = repos;
        _events = feed.events;
        _failedSources = feed.failedSources;
        _truncated = feed.truncated;
        _rollup = TeamService.rollup(_team, activities);
        _loading = false;
      });
    } catch (e) {
      debugPrint('TeamDetail failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading this team. Pull to retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_team.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Repositories'),
              Tab(text: 'Activity'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(),
                  const Divider(height: 1),
                  if (_error == null)
                    activitySourceNotice(
                      failedSources: _failedSources,
                      truncated: _truncated,
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [_buildReposTab(), _buildActivityTab()],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final rollup = _rollup;
    if (rollup == null || _team.repoKeys.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _metric(Icons.folder, '${rollup.repoCount} repos'),
          _metric(Icons.merge_type, '${rollup.openPrs} open PRs'),
          _metric(Icons.rate_review, '${rollup.needsReview} need review'),
          _metric(Icons.people, '${rollup.contributors.length} contributors'),
          _metric(Icons.update, _relativeTime(rollup.lastActivity)),
          if (rollup.oldestOpenPrAgeDays != null)
            _metric(Icons.schedule, 'oldest ${rollup.oldestOpenPrAgeDays}d'),
        ],
      ),
    );
  }

  Widget _buildReposTab() {
    if (_error != null) return _errorList();
    if (_team.repoKeys.isEmpty) {
      return _centeredMessage('No repositories assigned to this team.');
    }
    if (_repos.isEmpty) {
      return _centeredMessage(
        'No data yet — assigned repos are loading or failed to fetch.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _repos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _repoTile(_repos[index]),
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_error != null) return _errorList();
    if (_team.repoKeys.isEmpty) {
      return _centeredMessage('No repositories assigned to this team.');
    }
    if (_events.isEmpty) {
      final days = ActivityFeedService.defaultLookback.inDays;
      final message = _failedSources > 0
          ? 'Couldn\'t load activity right now. Pull down to retry.'
          : 'No activity in this team\'s repos in the last $days days.';
      return _centeredMessage(message);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ActivityEventList(events: _events),
    );
  }

  Widget _repoTile(RepoActivity repo) {
    final ci = _ciVisual(repo.ciStatus);
    final subtitle = repo.error != null
        ? repo.error!
        : '${repo.openPrCount} open · ${repo.needsReviewCount} need review · '
              'active ${_relativeTime(repo.lastActivity)}';
    return ListTile(
      leading: Icon(ci.icon, color: ci.color),
      title: Text(repo.displayName),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: repo.error != null ? Colors.red : Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: () => _open(repo.url),
    );
  }

  ({IconData icon, Color color}) _ciVisual(String status) {
    switch (status) {
      case 'success':
        return (icon: Icons.check_circle, color: Colors.green);
      case 'failure':
        return (icon: Icons.error, color: Colors.red);
      case 'running':
        return (icon: Icons.hourglass_empty, color: Colors.orange);
      default:
        return (icon: Icons.help_outline, color: Colors.grey);
    }
  }

  Widget _metric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _centeredMessage(String message) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime? value) {
    if (value == null) return 'no activity';
    return activityRelativeTime(value);
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
