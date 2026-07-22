import 'package:flutter/material.dart';

import 'activity_service.dart';
import 'app_http.dart';
import 'ci_run_history_store.dart';
import 'digest_service.dart';
import 'metric_store.dart';
import 'team_store.dart';

class DigestPage extends StatefulWidget {
  const DigestPage({super.key});

  @override
  State<DigestPage> createState() => _DigestPageState();
}

class _DigestPageState extends State<DigestPage> {
  Digest? _digest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDigest();
  }

  Future<void> _loadDigest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final teams = await TeamStore.list();
      final activities = await ActivityService.computeAll(
        client: AppHttp.client,
      );
      // Record a trend snapshot from this load too (deduped ~1/day) before
      // reading history, so the digest reflects the latest observation.
      await MetricStore.capture(activities, restrictToMonitored: true);
      await CiRunHistoryStore.recordSafely(
        activities.expand((a) => a.recentRuns),
      );
      final history = await MetricStore.all();
      final digest = DigestService.buildDigest(
        teams: teams,
        activities: activities,
        history: history,
      );

      if (!mounted) return;
      setState(() {
        _digest = digest;
        _loading = false;
      });
    } catch (e) {
      debugPrint('DigestPage failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Something went wrong while loading your digest. Pull down to try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadDigest,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _loadDigest, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      );
    }

    final digest = _digest;
    if (digest == null) {
      return _buildEmptyState('No digest data yet. Pull down to refresh.');
    }

    if (digest.teamLines.isEmpty &&
        digest.totalOpenPrs == 0 &&
        digest.totalNeedsReview == 0) {
      return _buildEmptyState(
        'No team digest yet. Add teams and repositories to see trends.',
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _buildSummaryCard(digest),
        _sectionTitle('Top movers'),
        if (digest.movers.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('No activity movement in this window.'),
          )
        else
          ...digest.movers.map(_buildLineTile),
        _sectionTitle('Teams'),
        if (digest.teamLines.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('No teams available yet.'),
          )
        else
          ...digest.teamLines.map(_buildLineTile),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Center(
          child: Icon(
            Icons.summarize_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Digest digest) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Summary', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _metric(Icons.merge_type, '${digest.totalOpenPrs} open PRs'),
                _metric(
                  Icons.rate_review,
                  '${digest.totalNeedsReview} need review',
                ),
                _metric(Icons.groups, '${digest.teamLines.length} teams'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Window: ${_formatWindow(digest.window)} · Generated ${_relativeTime(digest.generatedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _buildLineTile(DigestLine line) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(line.label),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _metric(Icons.merge_type, '${line.openPrs} open PRs'),
              _metric(Icons.rate_review, '${line.needsReview} need review'),
              _metric(
                Icons.auto_graph,
                'Activity ${_formatNumber(line.activityScore)}',
              ),
            ],
          ),
        ),
        trailing: _deltaIndicator(line.activityDelta),
      ),
    );
  }

  Widget _metric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }

  Widget _deltaIndicator(num delta) {
    final theme = Theme.of(context);
    final Color color;
    final IconData icon;
    if (delta > 0) {
      color = Colors.green;
      icon = Icons.arrow_upward;
    } else if (delta < 0) {
      color = Colors.red;
      icon = Icons.arrow_downward;
    } else {
      color = theme.colorScheme.onSurfaceVariant;
      icon = Icons.remove;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          _formatDelta(delta),
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }

  String _formatDelta(num delta) {
    if (delta > 0) return '+${_formatNumber(delta)}';
    return _formatNumber(delta);
  }

  String _formatNumber(num value) {
    if (!value.isFinite) return '0';
    final doubleValue = value.toDouble();
    if (doubleValue == doubleValue.roundToDouble()) {
      return doubleValue.toInt().toString();
    }
    return doubleValue.toStringAsFixed(1);
  }

  String _formatWindow(Duration window) {
    if (window.inDays >= 1 && window.inHours % 24 == 0) {
      return _plural(window.inDays, 'day');
    }
    if (window.inHours >= 1 && window.inMinutes % 60 == 0) {
      return _plural(window.inHours, 'hour');
    }
    if (window.inMinutes >= 1 && window.inSeconds % 60 == 0) {
      return _plural(window.inMinutes, 'minute');
    }
    return _plural(window.inSeconds, 'second');
  }

  String _plural(int value, String unit) {
    return '$value $unit${value == 1 ? '' : 's'}';
  }

  String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.isNegative || diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
