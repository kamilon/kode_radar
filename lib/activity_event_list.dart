import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'activity_event.dart';

/// Relative "…ago" label shared by the feed and detail views.
String activityRelativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.isNegative || diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// A compact amber notice shown when some feed sources failed to load or the
/// page was truncated. Returns an empty widget when there is nothing to warn
/// about. Shared by the feed and detail views.
Widget activitySourceNotice({
  required int failedSources,
  bool truncated = false,
}) {
  if (failedSources <= 0 && !truncated) return const SizedBox.shrink();
  final parts = <String>[];
  if (failedSources > 0) {
    parts.add(
      '$failedSources source${failedSources == 1 ? '' : 's'} '
      'couldn\'t be loaded',
    );
  }
  if (truncated) parts.add('older items may be omitted');
  // Retrying only helps when a source actually failed.
  final suffix = failedSources > 0 ? ' Pull to retry.' : '';
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

/// A reverse-chronological, day-grouped list of [ActivityEvent]s with
/// tap-to-open behaviour. Shared by the Activity Feed and the Person/Team
/// detail views so event rendering stays consistent.
///
/// The caller supplies an already-filtered, already-sorted (newest-first) list
/// and typically wraps this in a `RefreshIndicator`.
class ActivityEventList extends StatelessWidget {
  const ActivityEventList({
    super.key,
    required this.events,
    this.padding = EdgeInsets.zero,
    this.newSince,
  });

  final List<ActivityEvent> events;
  final EdgeInsetsGeometry padding;

  /// When set, events occurring after this time get a "New" badge.
  final DateTime? newSince;

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows(events);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.header != null) return _dayHeader(row.header!);
        return _eventTile(context, row.event!);
      },
    );
  }

  List<_Row> _buildRows(List<ActivityEvent> events) {
    final rows = <_Row>[];
    String? currentDay;
    for (final event in events) {
      final day = _dayLabel(event.occurredAt.toLocal());
      if (day != currentDay) {
        currentDay = day;
        rows.add(_Row.header(day));
      }
      rows.add(_Row.event(event));
    }
    return rows;
  }

  Widget _dayHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Builder(
        builder: (context) => Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _eventTile(BuildContext context, ActivityEvent event) {
    final visual = _visualFor(event.type);
    final isNew = newSince != null && event.occurredAt.isAfter(newSince!);
    return ListTile(
      leading: Icon(visual.icon, color: visual.color),
      title: Row(
        children: [
          Flexible(child: Text(event.title)),
          if (isNew) ...[const SizedBox(width: 6), const NewBadge()],
        ],
      ),
      subtitle: Text(
        '${event.subtitle} · ${activityRelativeTime(event.occurredAt.toLocal())}',
      ),
      trailing: event.url != null
          ? const Icon(Icons.open_in_new, size: 16)
          : null,
      onTap: event.url == null ? null : () => _open(context, event.url!),
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

  /// "Today" / "Yesterday" / "Mon, Jul 14". Uses UTC-midnight anchors so
  /// calendar-day math stays exact across DST transitions.
  String _dayLabel(DateTime local) {
    final now = DateTime.now();
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

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showOpenError(context, url);
      return;
    }
    final canLaunch = await canLaunchUrl(uri);
    if (!context.mounted) return;
    if (!canLaunch) {
      _showOpenError(context, url);
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!launched) _showOpenError(context, url);
  }

  void _showOpenError(BuildContext context, String url) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

/// A small green "New" badge for items that arrived since you last looked.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'New',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A compact banner announcing how many items are new since the last visit.
/// Returns an empty widget when [count] is zero.
Widget sinceLastLookedBanner(int count, {String unit = 'new'}) {
  if (count <= 0) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    color: Colors.green.shade50,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Icon(Icons.fiber_new, size: 18, color: Colors.green.shade800),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$count $unit since you last looked',
            style: TextStyle(fontSize: 12, color: Colors.green.shade900),
          ),
        ),
      ],
    ),
  );
}

/// A row in the flattened list: either a day header or an event.
class _Row {
  const _Row.header(this.header) : event = null;
  const _Row.event(this.event) : header = null;

  final String? header;
  final ActivityEvent? event;
}
