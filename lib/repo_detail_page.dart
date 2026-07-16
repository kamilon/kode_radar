import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_event.dart';
import 'activity_event_list.dart';
import 'activity_feed_service.dart';
import 'activity_service.dart';
import 'app_http.dart';
import 'repo_detail_service.dart';

/// Per-repository drill-down: open pull requests (with review state), CI
/// history, releases, and a recent-activity timeline, plus contributors.
class RepoDetailPage extends StatefulWidget {
  const RepoDetailPage({super.key, required this.repo});

  final RepoActivity repo;

  @override
  State<RepoDetailPage> createState() => _RepoDetailPageState();
}

class _RepoDetailPageState extends State<RepoDetailPage> {
  RepoDetailData _data = const RepoDetailData();
  List<ActivityEvent> _events = const [];
  int _feedFailed = 0;
  bool _feedTruncated = false;
  bool _loading = true;
  String? _error;

  RepoActivity get _repo => widget.repo;

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
      final detailFuture = RepoDetailService.load(
        repoKey: _repo.repoKey,
        provider: _repo.provider,
        client: AppHttp.client,
      );
      final feedFuture = ActivityFeedService.computeAll(
        client: AppHttp.client,
        onlyRepoKeys: {_repo.repoKey},
      );
      final results = await Future.wait([detailFuture, feedFuture]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as RepoDetailData;
        final feed = results[1] as ActivityFeedResult;
        _events = feed.events;
        _feedFailed = feed.failedSources;
        _feedTruncated = feed.truncated;
        _loading = false;
      });
    } catch (e) {
      debugPrint('RepoDetail failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Something went wrong while loading this repository. '
            'Pull to retry.';
        _loading = false;
      });
    }
  }

  int get _tabCount => _releasesSupported ? 4 : 3;

  /// Releases exist only for GitHub. Derive from the known provider (not the
  /// async-loaded data) so the tab set is correct immediately and TabBar and
  /// TabBarView never desync.
  bool get _releasesSupported => _repo.provider == 'github';

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Pull requests'),
      const Tab(text: 'CI'),
      if (_releasesSupported) const Tab(text: 'Releases'),
      const Tab(text: 'Activity'),
    ];
    return DefaultTabController(
      length: _tabCount,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_repo.displayName),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in browser',
              onPressed: () => _open(_repo.url),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
            ),
          ],
          bottom: TabBar(isScrollable: true, tabs: tabs),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(),
                  const Divider(height: 1),
                  if (_error == null)
                    activitySourceNotice(
                      failedSources: _data.failedSources + _feedFailed,
                      truncated: _feedTruncated,
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPullsTab(),
                        _buildCiTab(),
                        if (_releasesSupported) _buildReleasesTab(),
                        _buildActivityTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Icon(
            Icons.people,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _contributorsText(),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Contributors derived from the loaded open PRs (their authors), so the
  /// header is correct regardless of how this screen was reached (e.g. from
  /// search, where the passed reference carries no contributors). Falls back to
  /// the reference's contributors before the first load completes.
  String _contributorsText() {
    final fromPulls = <String>{
      for (final pr in _data.pulls)
        if (pr.author.isNotEmpty) pr.author,
    };
    final contributors = fromPulls.isNotEmpty
        ? fromPulls.toList()
        : _repo.contributors;
    if (contributors.isEmpty) return 'No recent contributors';
    return contributors.take(6).join(', ');
  }

  Widget _buildPullsTab() {
    if (_error != null) return _errorList();
    final pulls = _data.pulls;
    if (pulls.isEmpty) {
      return _centeredMessage(
        _data.pullsFailed
            ? 'Couldn\'t load pull requests. Pull to retry.'
            : 'No open pull requests.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: pulls.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _prTile(pulls[index]),
      ),
    );
  }

  Widget _prTile(RepoPr pr) {
    final review = _reviewVisual(pr.reviewState);
    return ListTile(
      leading: Icon(review.icon, color: review.color),
      title: Row(
        children: [
          Flexible(child: Text('${pr.label}: ${pr.title}')),
          if (pr.draft) ...[
            const SizedBox(width: 6),
            const _MiniChip(label: 'Draft'),
          ],
        ],
      ),
      subtitle: Text(
        'by ${pr.author} · ${_ageText(pr.ageDays)} · ${review.label}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: pr.url != null ? const Icon(Icons.open_in_new, size: 16) : null,
      onTap: pr.url == null ? null : () => _open(pr.url!),
    );
  }

  Widget _buildCiTab() {
    if (_error != null) return _errorList();
    final ci = _data.ci;
    if (ci.isEmpty) {
      return _centeredMessage(
        _data.ciFailed
            ? 'Couldn\'t load CI runs. Pull to retry.'
            : 'No recent CI runs.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: ci.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _ciTile(ci[index]),
      ),
    );
  }

  Widget _ciTile(RepoRun run) {
    final visual = _ciVisual(run);
    final branch = (run.branch == null || run.branch!.isEmpty)
        ? ''
        : ' · ${run.branch}';
    return ListTile(
      leading: Icon(visual.icon, color: visual.color),
      title: Text(run.name),
      subtitle: Text(
        '${visual.label}$branch · ${_finishedText(run.finishedAt)}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: run.url != null
          ? const Icon(Icons.open_in_new, size: 16)
          : null,
      onTap: run.url == null ? null : () => _open(run.url!),
    );
  }

  Widget _buildReleasesTab() {
    if (_error != null) return _errorList();
    final releases = _data.releases;
    if (releases.isEmpty) {
      return _centeredMessage(
        _data.releasesFailed
            ? 'Couldn\'t load releases. Pull to retry.'
            : 'No releases yet.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: releases.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _releaseTile(releases[index]),
      ),
    );
  }

  Widget _releaseTile(RepoRelease release) {
    final name = release.name == null || release.name!.isEmpty
        ? release.tag
        : '${release.tag} · ${release.name}';
    final by = release.author == null ? '' : 'by ${release.author} · ';
    return ListTile(
      leading: const Icon(Icons.rocket_launch, color: Colors.teal),
      title: Text(name),
      subtitle: Text(
        '$by${_finishedText(release.publishedAt)}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: release.url != null
          ? const Icon(Icons.open_in_new, size: 16)
          : null,
      onTap: release.url == null ? null : () => _open(release.url!),
    );
  }

  Widget _buildActivityTab() {
    if (_error != null) return _errorList();
    if (_events.isEmpty) {
      final days = ActivityFeedService.defaultLookback.inDays;
      return _centeredMessage(
        _feedFailed > 0
            ? 'Couldn\'t load activity. Pull to retry.'
            : 'No activity in this repository in the last $days days.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ActivityEventList(events: _events),
    );
  }

  ({IconData icon, Color color, String label}) _reviewVisual(String state) {
    switch (state) {
      case PrReviewState.approved:
        return (
          icon: Icons.check_circle,
          color: Colors.green,
          label: 'Approved',
        );
      case PrReviewState.changesRequested:
        return (
          icon: Icons.edit_note,
          color: Colors.red,
          label: 'Changes requested',
        );
      case PrReviewState.waiting:
        return (
          icon: Icons.rate_review,
          color: Colors.orange,
          label: 'Waiting on review',
        );
      default:
        return (
          icon: Icons.merge_type,
          color: Colors.blueGrey,
          label: 'No review requested',
        );
    }
  }

  ({IconData icon, Color color, String label}) _ciVisual(RepoRun run) {
    // GitHub uses 'completed'; ADO uses 'completed' too, but in-progress ADO
    // builds report status 'inProgress'/'notStarted'.
    final done = run.status == 'completed';
    if (!done) {
      return (
        icon: Icons.hourglass_empty,
        color: Colors.orange,
        label: 'In progress',
      );
    }
    switch (run.conclusion) {
      case 'success':
      case 'succeeded':
        return (icon: Icons.check_circle, color: Colors.green, label: 'Passed');
      case 'failure':
      case 'failed':
        return (icon: Icons.cancel, color: Colors.red, label: 'Failed');
      case 'cancelled':
      case 'canceled':
        return (icon: Icons.block, color: Colors.grey, label: 'Cancelled');
      default:
        return (
          icon: Icons.help_outline,
          color: Colors.grey,
          label: run.conclusion.isEmpty ? 'Completed' : run.conclusion,
        );
    }
  }

  String _ageText(int? ageDays) {
    if (ageDays == null) return 'opened recently';
    if (ageDays <= 0) return 'opened today';
    if (ageDays == 1) return 'opened 1 day ago';
    return 'opened $ageDays days ago';
  }

  String _finishedText(DateTime? value) {
    if (value == null) return 'unknown time';
    return activityRelativeTime(value.toLocal());
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}
