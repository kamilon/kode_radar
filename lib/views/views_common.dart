import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../activity_service.dart';
import '../metric_snapshot.dart';
import '../person.dart';
import '../team.dart';
import '../team_service.dart';

/// Pre-loaded data handed to every insights view so each view is a pure widget
/// (no fetching): the hub loads once and passes this down. Collections are
/// copied into unmodifiable views so a view can't mutate the shared snapshot.
class InsightsData {
  InsightsData({
    required List<RepoActivity> activities,
    required Map<String, List<MetricSnapshot>> history,
    required List<Team> teams,
    required Map<String, TeamRollup> rollups,
    required List<Person> people,
    required this.loadedAt,
  }) : activities = List.unmodifiable(activities),
       history = Map.unmodifiable(history),
       teams = List.unmodifiable(teams),
       rollups = Map.unmodifiable(rollups),
       people = List.unmodifiable(people);

  final List<RepoActivity> activities;
  final Map<String, List<MetricSnapshot>> history;
  final List<Team> teams;
  final Map<String, TeamRollup> rollups;
  final List<Person> people;
  final DateTime loadedAt;

  /// Repos whose fetch succeeded (errored repos would read as healthy zeros).
  List<RepoActivity> get healthy =>
      activities.where((a) => a.error == null).toList();

  bool get isEmpty => activities.isEmpty;
}

/// A tappable descriptor for the gallery grid on the hub.
class ViewInfo {
  const ViewInfo({
    required this.title,
    required this.blurb,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String blurb;
  final IconData icon;
  final Widget Function(InsightsData data) builder;
}

// ---- CI helpers -------------------------------------------------------------

Color ciColor(String status) => switch (status) {
  'success' => const Color(0xFF2E7D32),
  'failure' => const Color(0xFFC62828),
  'running' => const Color(0xFFEF6C00),
  _ => const Color(0xFF9E9E9E),
};

IconData ciIcon(String status) => switch (status) {
  'success' => Icons.check_circle,
  'failure' => Icons.cancel,
  'running' => Icons.hourglass_bottom,
  _ => Icons.help_outline,
};

String ciLabel(String status) => switch (status) {
  'success' => 'passing',
  'failure' => 'failing',
  'running' => 'running',
  _ => 'unknown',
};

/// Opens a repo URL in the external browser; silently no-ops on any failure
/// (bad URL, unsupported scheme, or a platform channel exception).
Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('openUrl failed for $url: $e');
  }
}

/// Shown on views that encode `activityScore`, which is not raw activity: it
/// also weights attention (failing CI and long-stuck PRs) so repos that need a
/// human bubble up. Disclosed so "bigger/hotter" isn't read as pure activity.
const String scoreNote =
    'Score blends activity + attention (failing CI / stale PRs raise it).';

// ---- Time helpers -----------------------------------------------------------

int? daysSince(DateTime? value, {DateTime? now}) {
  if (value == null) return null;
  final diff = (now ?? DateTime.now()).difference(value);
  return diff.isNegative ? 0 : diff.inDays;
}

String relativeTime(DateTime? value, {DateTime? now}) {
  if (value == null) return 'never';
  final diff = (now ?? DateTime.now()).difference(value);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  final months = diff.inDays ~/ 30;
  if (months < 12) return '${months}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}

// ---- Freshness / heat scale -------------------------------------------------

/// Maps a repo's last activity to a freshness color: green (fresh) → amber
/// (quieting) → grey (stale/quiet).
Color freshnessColor(DateTime? lastActivity, {DateTime? now}) {
  final days = daysSince(lastActivity, now: now);
  if (days == null) return const Color(0xFF9E9E9E);
  if (days <= 1) return const Color(0xFF2E7D32);
  if (days <= 3) return const Color(0xFF66BB6A);
  if (days <= 7) return const Color(0xFFF9A825);
  if (days <= 21) return const Color(0xFFEF6C00);
  return const Color(0xFF8D6E63);
}

/// Continuous cool→warm heat color for a normalized value [t] in [0,1].
/// 0 = calm (blue), 0.5 = active (green/amber), 1 = hot (red).
Color heatColor(double t) {
  final clamped = t.clamp(0.0, 1.0);
  const stops = <Color>[
    Color(0xFF1565C0), // blue
    Color(0xFF00897B), // teal
    Color(0xFF7CB342), // green
    Color(0xFFF9A825), // amber
    Color(0xFFC62828), // red
  ];
  final scaled = clamped * (stops.length - 1);
  final i = scaled.floor().clamp(0, stops.length - 2);
  final f = scaled - i;
  return Color.lerp(stops[i], stops[i + 1], f)!;
}

/// A readable on-color for a filled swatch.
Color onColorFor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black87;

// ---- PR age buckets ---------------------------------------------------------

class AgeBucket {
  const AgeBucket(this.label, this.minInclusive, this.maxExclusive, this.color);
  final String label;
  final int minInclusive;
  final int? maxExclusive; // null = unbounded
  final Color color;

  bool contains(int days) =>
      days >= minInclusive && (maxExclusive == null || days < maxExclusive!);
}

const List<AgeBucket> ageBuckets = [
  AgeBucket('<1d', 0, 1, Color(0xFF2E7D32)),
  AgeBucket('1–3d', 1, 3, Color(0xFF7CB342)),
  AgeBucket('3–7d', 3, 7, Color(0xFFF9A825)),
  AgeBucket('1–2w', 7, 14, Color(0xFFEF6C00)),
  AgeBucket('>2w', 14, null, Color(0xFFC62828)),
];

// ---- Small shared widgets ---------------------------------------------------

/// A compact "big number" stat tile used across dashboard-style views.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.sub,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return Card(
      elevation: 0,
      color: accent.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(
                sub!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps a view body in a standard Scaffold with a title and an optional
/// "loaded at" caption in the app bar.
class ViewScaffold extends StatelessWidget {
  const ViewScaffold({
    super.key,
    required this.title,
    required this.child,
    this.loadedAt,
  });

  final String title;
  final Widget child;
  final DateTime? loadedAt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: loadedAt == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(18),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Snapshot ${relativeTime(loadedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
      ),
      body: child,
    );
  }
}

/// Empty-state placeholder used when a view has nothing to render.
class ViewEmpty extends StatelessWidget {
  const ViewEmpty({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
