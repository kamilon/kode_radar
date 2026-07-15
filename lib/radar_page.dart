import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_service.dart';
import 'app_http.dart';
import 'metric_store.dart';
import 'sparkline.dart';

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  List<RepoActivity> _activities = const [];
  Map<String, List<num>> _series = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final activities = await ActivityService.computeAll(
        client: AppHttp.client,
      );
      // Record a trend snapshot (deduped ~1/day), then load per-repo series.
      await MetricStore.capture(activities);
      final history = await MetricStore.all();
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _series = {
          for (final a in activities)
            a.repoKey: (history[a.repoKey] ?? const [])
                .map((s) => s.activityScore)
                .toList(),
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load radar: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadActivities,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActivities,
              child: _buildContent(),
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

    if (_activities.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No repositories yet. Add some from Manage Repositories.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        return Card(
          child: ListTile(
            title: Text(activity.displayName),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _metric(
                        Icons.merge_type,
                        '${activity.openPrCount} open PRs',
                      ),
                      _metric(
                        Icons.rate_review,
                        '${activity.needsReviewCount} review requested',
                      ),
                      _ciStatus(activity.ciStatus),
                      _metric(
                        Icons.update,
                        _relativeTime(activity.lastActivity),
                      ),
                      _metric(
                        Icons.people,
                        _contributorsText(activity.contributors),
                      ),
                    ],
                  ),
                  if ((_series[activity.repoKey] ?? const []).length >= 2) ...[
                    const SizedBox(height: 8),
                    Sparkline(values: _series[activity.repoKey]!, width: 120),
                  ],
                  if (activity.oldestOpenPrAgeDays != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Oldest open PR: ${activity.oldestOpenPrAgeDays}d',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (activity.error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      activity.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openRepo(activity),
          ),
        );
      },
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

  Widget _ciStatus(String status) {
    final color = _ciColor(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_ciIcon(status), size: 16, color: color),
        const SizedBox(width: 4),
        Text('CI ${_ciLabel(status)}'),
      ],
    );
  }

  IconData _ciIcon(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle;
      case 'failure':
        return Icons.cancel;
      case 'running':
        return Icons.hourglass_empty;
      default:
        return Icons.help_outline;
    }
  }

  Color _ciColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failure':
        return Colors.red;
      case 'running':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _ciLabel(String status) {
    switch (status) {
      case 'success':
        return 'success';
      case 'failure':
        return 'failure';
      case 'running':
        return 'running';
      default:
        return 'unknown';
    }
  }

  String _relativeTime(DateTime? value) {
    if (value == null) return 'No open PRs';
    final difference = DateTime.now().difference(value);
    if (difference.isNegative || difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';
    final months = difference.inDays ~/ 30;
    if (months < 12) return '${months}mo ago';
    return '${difference.inDays ~/ 365}y ago';
  }

  String _contributorsText(List<String> contributors) {
    if (contributors.isEmpty) return 'No open-PR authors';
    final shown = contributors.take(5).toList();
    final extra = contributors.length - shown.length;
    final text = shown.join(', ');
    if (extra <= 0) return text;
    return '$text, +$extra';
  }

  Future<void> _openRepo(RepoActivity activity) async {
    final uri = Uri.tryParse(activity.url);
    if (uri == null) return;

    final canLaunch = await canLaunchUrl(uri);
    if (!mounted) return;
    if (!canLaunch) {
      _showLaunchError(activity.displayName);
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) _showLaunchError(activity.displayName);
  }

  void _showLaunchError(String displayName) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $displayName')));
  }
}
