import 'package:flutter/material.dart';

import 'activity_event.dart';
import 'activity_event_list.dart';
import 'activity_feed_service.dart';
import 'app_http.dart';
import 'person.dart';

/// Drill-down for a single [Person]: their identities and PR/review summary,
/// plus their recent activity across all monitored repositories.
class PersonDetailPage extends StatefulWidget {
  const PersonDetailPage({super.key, required this.person});

  final Person person;

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  List<ActivityEvent> _events = const [];
  bool _loading = true;
  int _failedSources = 0;
  bool _truncated = false;
  String? _error;
  DateTime? _lastChecked;

  Person get _person => widget.person;

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
      final result = await ActivityFeedService.computeAll(
        client: AppHttp.client,
        actorGithubLogins: _person.githubLogins,
        actorAdoNames: _person.adoNames,
      );
      if (!mounted) return;
      setState(() {
        _events = result.events;
        _failedSources = result.failedSources;
        _truncated = result.truncated;
        _lastChecked = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      debugPrint('PersonDetail failed to load: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Something went wrong while loading this person. Pull to retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_person.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          if (!_loading)
            ?activitySourceNotice(
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

  Widget _buildHeader() {
    final identities = [..._person.githubLogins, ..._person.adoNames];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(_initials(_person.displayName))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _person.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (_person.isSelf) ...[
                          const SizedBox(width: 8),
                          const Chip(
                            label: Text('You'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${_person.authoredOpenPrs} open PR'
                      '${_person.authoredOpenPrs == 1 ? '' : 's'} · '
                      '${_person.reviewRequests} review request'
                      '${_person.reviewRequests == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (identities.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in identities)
                  Chip(
                    label: Text(id),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }
    if (_events.isEmpty) {
      final days = ActivityFeedService.defaultLookback.inDays;
      final message = _failedSources > 0
          ? 'Couldn\'t load activity right now. Pull down to retry.'
          : 'No recent activity found for ${_person.displayName} in the '
                'last $days days.';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Icon(Icons.timeline, size: 56, color: Colors.grey[400]),
          ),
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
    return ActivityEventList(events: _events);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }
}
