import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_event.dart';
import 'activity_event_list.dart';
import 'activity_event_store.dart';
import 'activity_feed_service.dart';
import 'activity_service.dart';
import 'app_http.dart';
import 'repo_detail_service.dart';
import 'repo_detail_store.dart';
import 'sync_state_store.dart';

/// Per-repository drill-down: open pull requests (with review state), CI
/// history, releases, and a recent-activity timeline, plus contributors.
class RepoDetailPage extends StatefulWidget {
  const RepoDetailPage({super.key, required this.repo});

  final RepoActivity repo;

  @override
  State<RepoDetailPage> createState() => _RepoDetailPageState();
}

class _RepoDetailPageState extends State<RepoDetailPage> {
  /// The persisted detail composite, driven by the reactive
  /// [RepoDetailStore.watch] stream (instant cache on cold start; auto-updates
  /// when a refresh or repo-delete changes the cache). Its own failure flags are
  /// always false (last-known-good); the fresh flags are overlaid via [_data].
  RepoDetailData _streamDetail = const RepoDetailData();
  StreamSubscription<RepoDetailData>? _detailSub;

  /// This round's fresh per-source failure flags from the network refresh,
  /// overlaid on the streamed cache so each tab can still show "couldn't load".
  bool _pullsFailed = false;
  bool _ciFailed = false;
  bool _releasesFailed = false;

  List<ActivityEvent> _events = const [];
  int _feedFailed = 0;
  bool _feedTruncated = false;

  /// A load (cache render + network refresh) is in flight. Gates the manual
  /// Refresh action so overlapping fetches can't stack; cache-first renders
  /// still update the UI underneath.
  bool _refreshing = true;
  String? _error;

  /// When this repo last refreshed successfully from the network (persisted), so
  /// the header's "updated" label stays honest while showing stale cache.
  DateTime? _lastSynced;

  // Guards against a stale in-flight load applying after a newer one.
  int _loadSeq = 0;

  RepoActivity get _repo => widget.repo;

  /// The rendered detail: the streamed persisted composite plus this round's
  /// fresh per-source failure flags.
  RepoDetailData get _data => RepoDetailData(
    pulls: _streamDetail.pulls,
    ci: _streamDetail.ci,
    releases: _streamDetail.releases,
    releasesSupported: _releasesSupported,
    pullsFailed: _pullsFailed,
    ciFailed: _ciFailed,
    releasesFailed: _releasesFailed,
  );

  /// True once anything (detail or timeline) is on screen.
  bool get _hasContent =>
      _events.isNotEmpty ||
      _streamDetail.pulls.isNotEmpty ||
      _streamDetail.ci.isNotEmpty ||
      _streamDetail.releases.isNotEmpty;

  /// Full-screen spinner only while a load is in flight and nothing is cached
  /// to show yet.
  bool get _showSpinner => _refreshing && !_hasContent && _error == null;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _load();
  }

  @override
  void dispose() {
    _detailSub?.cancel();
    super.dispose();
  }

  /// Subscribes the reactive detail cache. The first emission renders the cache
  /// instantly; later emissions (a refresh persisting, or a repo-delete pruning)
  /// update the tabs automatically.
  void _subscribe() {
    _detailSub?.cancel();
    _detailSub =
        RepoDetailStore.watch(
          _repo.repoKey,
          releasesSupported: _releasesSupported,
        ).listen(
          (detail) {
            if (!mounted) return;
            setState(() {
              _streamDetail = detail;
              // A cache emission with content clears a stale error screen a
              // failed refresh set before the cache arrived.
              if (detail.pulls.isNotEmpty ||
                  detail.ci.isNotEmpty ||
                  detail.releases.isNotEmpty) {
                _error = null;
              }
            });
          },
          onError: (Object e, StackTrace st) =>
              debugPrint('RepoDetail watch stream error: $e\n$st'),
        );
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _refreshing = true;
      _error = null;
      // Clear the source-health indicators up front so a load that throws
      // before producing fresh results can't leave stale "couldn't load"
      // states (they're set fresh from this round's network result below).
      _pullsFailed = false;
      _ciFailed = false;
      _releasesFailed = false;
      _feedFailed = 0;
      _feedTruncated = false;
    });
    try {
      // Phase A: render this repo's cached timeline events + provenance
      // immediately so a cold start / offline open isn't a blank spinner. (The
      // detail composite renders via the reactive stream's first emission.)
      if (_events.isEmpty) {
        final cachedResults = await Future.wait([
          ActivityEventStore.cached(repoKey: _repo.repoKey),
          SyncStateStore.lastSuccess(SyncStateStore.repoScope(_repo.repoKey)),
        ]);
        if (!mounted || seq != _loadSeq) return;
        final repoEvents = cachedResults[0] as List<ActivityEvent>;
        final lastSynced = cachedResults[1] as DateTime?;
        // Set the provenance label even when there's no cached timeline (a scope
        // that synced successfully but had nothing to show), so its "updated"
        // time survives a restart/offline open.
        if (repoEvents.isNotEmpty || lastSynced != null) {
          setState(() {
            if (repoEvents.isNotEmpty) _events = repoEvents;
            _lastSynced = lastSynced;
          });
        }
      }

      // Phase B: refresh from the network and persist the detail snapshot. The
      // save triggers the watch stream, which updates the rendered composite.
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
      if (!mounted || seq != _loadSeq) return;
      final freshDetail = results[0] as RepoDetailData;
      final feed = results[1] as ActivityFeedResult;
      await RepoDetailStore.save(_repo.repoKey, freshDetail);
      if (!mounted || seq != _loadSeq) return;
      List<ActivityEvent> timeline = feed.events;
      // Fall back to the cached timeline only when the fresh fetch came back
      // empty BECAUSE a source failed (offline/partial) — not when the repo is
      // genuinely quiet, so a now-empty repo doesn't keep showing stale events.
      // Reuse the events already on screen (loaded in Phase A, or a prior
      // render) instead of re-querying the DB.
      if (timeline.isEmpty && feed.failedSources > 0) {
        timeline = _events;
      }
      // A successful sync = at least one *persisted* detail source (pulls / CI /
      // releases) refreshed without failing. The timeline isn't part of this
      // cache (it reuses the shared feed cache), so it doesn't gate provenance —
      // otherwise the "updated" time could advance while the persisted tabs show
      // stale data. Fully offline (every detail source failed) does not count.
      final syncedOk =
          !freshDetail.pullsFailed ||
          !freshDetail.ciFailed ||
          (_releasesSupported && !freshDetail.releasesFailed);
      if (syncedOk) {
        await SyncStateStore.markSuccess(
          SyncStateStore.repoScope(_repo.repoKey),
        );
        if (!mounted || seq != _loadSeq) return;
      }
      // Overlay the fresh per-source failure flags on the streamed composite
      // (which keeps last-known-good rows for any source that failed), and
      // update the timeline. The persisted pulls/ci/releases come from the
      // stream via the save above.
      setState(() {
        _pullsFailed = freshDetail.pullsFailed;
        _ciFailed = freshDetail.ciFailed;
        _releasesFailed = freshDetail.releasesFailed;
        _events = timeline;
        _feedFailed = feed.failedSources;
        _feedTruncated = feed.truncated;
        if (syncedOk) _lastSynced = DateTime.now();
        _refreshing = false;
      });
    } catch (e) {
      debugPrint('RepoDetail failed to load: $e');
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        // Keep any cached content (timeline from Phase A, detail from the
        // stream); only show the error screen when there's nothing to show.
        if (!_hasContent) {
          _error =
              'Something went wrong while loading this repository. '
              'Pull to retry.';
        }
        _refreshing = false;
      });
    }
  }

  /// Pull-to-refresh handler: ignore the pull if a load is already in flight so
  /// it can't start a second concurrent fetch.
  Future<void> _refresh() async {
    if (_refreshing) return;
    await _load();
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
              onPressed: _refreshing ? null : _load,
            ),
          ],
          bottom: TabBar(isScrollable: true, tabs: tabs),
        ),
        body: _showSpinner
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
          if (_lastSynced != null) ...[
            const SizedBox(width: 8),
            Text(
              'Updated ${activityRelativeTime(_lastSynced!.toLocal())}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
      onRefresh: _refresh,
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
      onRefresh: _refresh,
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
      onRefresh: _refresh,
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
      onRefresh: _refresh,
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
      onRefresh: _refresh,
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
      onRefresh: _refresh,
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
