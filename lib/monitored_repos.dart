import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'activity_service.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';

/// Parses the persisted repo records into lightweight [RepoActivity] references
/// (for search / navigation), sorted by display name. Pure and testable.
List<RepoActivity> parseMonitoredRepos(
  List<String> githubRaws,
  List<String> adoRaws,
) {
  final result = <RepoActivity>[];
  for (final raw in githubRaws) {
    final map = _decode(raw);
    if (map == null) continue;
    final owner = map['owner'];
    final name = map['repoName'];
    if (owner is! String || name is! String) continue;
    result.add(
      RepoActivity.reference(
        repoKey: RepoDiscoveryService.githubKey(owner, name),
        provider: 'github',
        displayName: '$owner/$name',
        url: 'https://github.com/$owner/$name',
      ),
    );
  }
  for (final raw in adoRaws) {
    final map = _decode(raw);
    if (map == null) continue;
    final organization = map['organization'];
    final project = map['project'];
    final name = map['repoName'];
    if (organization is! String || project is! String || name is! String) {
      continue;
    }
    result.add(
      RepoActivity.reference(
        repoKey: RepoDiscoveryService.adoKey(organization, project, name),
        provider: 'ado',
        displayName: '$organization/$project/$name',
        url: 'https://dev.azure.com/$organization/$project/_git/$name',
      ),
    );
  }
  result.sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
  // De-duplicate by repoKey (duplicate persisted entries would otherwise show
  // twice and resolve to the same record).
  final seen = <String>{};
  return result.where((r) => seen.add(r.repoKey)).toList();
}

/// Lists the monitored repositories as navigation references (local, no
/// network).
Future<List<RepoActivity>> listMonitoredRepos() async {
  final prefs = await SharedPreferences.getInstance();
  return parseMonitoredRepos(
    prefs.getStringList(RepoStore.githubKey) ?? const <String>[],
    prefs.getStringList(RepoStore.adoKey) ?? const <String>[],
  );
}

Map<String, dynamic>? _decode(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } catch (_) {
    return null;
  }
}
