import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_github_repo.dart';
import 'register_ado_repo.dart';
import 'activity_event_store.dart';
import 'repo_detail_store.dart';
import 'sync_state_store.dart';
import 'ignore_store.dart';
import 'manage_ignored_page.dart';
import 'metric_store.dart';
import 'monitored_repos.dart';
import 'mute_store.dart';
import 'repo_discovery_page.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'team_store.dart';
import 'token_store.dart';

enum _DeleteChoice { cancel, remove, removeAndIgnore }

/// Screen that lets the user view, edit, and delete the repositories that
/// Kode Radar is tracking. It operates directly on the persisted lists
/// (`github_repos` / `ado_repos`) so a repo can be managed even when it has no
/// live API data to surface it on the home page.
class ManageReposPage extends StatefulWidget {
  const ManageReposPage({super.key});

  @override
  State<ManageReposPage> createState() => _ManageReposPageState();
}

class _ManageReposPageState extends State<ManageReposPage> {
  static const String _githubKey = 'github_repos';
  static const String _adoKey = 'ado_repos';

  List<Map<String, String>> _githubRepos = [];
  List<Map<String, String>> _adoRepos = [];
  Map<String, String> _tokenLabels = {};
  Set<String> _mutedDisplays = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  /// Parses a stored list, keeping one entry per raw item so indexes stay
  /// aligned with what is persisted. Malformed entries are represented with an
  /// `_invalid` marker so the user can still delete them.
  List<Map<String, String>> _parse(List<String> raw) {
    return raw.map((entry) {
      try {
        return Map<String, String>.from(jsonDecode(entry) as Map);
      } catch (_) {
        return <String, String>{'_invalid': entry};
      }
    }).toList();
  }

  Future<void> _loadRepos() async {
    final prefs = await SharedPreferences.getInstance();
    final github = _parse(prefs.getStringList(_githubKey) ?? []);
    final ado = _parse(prefs.getStringList(_adoKey) ?? []);
    final tokens = await TokenStore.getTokens();
    final muted = await MuteStore.mutedDisplays();
    if (!mounted) return;
    setState(() {
      _githubRepos = github;
      _adoRepos = ado;
      _tokenLabels = {for (final t in tokens) t.id: t.label};
      _mutedDisplays = muted;
      _isLoading = false;
    });
  }

  Future<void> _toggleMute(String display) async {
    final nowMuted = !_mutedDisplays.contains(display);
    // Optimistically update so the icon flips immediately.
    setState(() {
      _mutedDisplays = {..._mutedDisplays};
      if (nowMuted) {
        _mutedDisplays.add(display);
      } else {
        _mutedDisplays.remove(display);
      }
    });
    try {
      await MuteStore.setMuted(display, nowMuted);
    } catch (_) {
      // Persistence failed: roll the optimistic flip back so the icon reflects
      // the stored state, and surface the failure instead of a false success.
      if (!mounted) return;
      setState(() {
        _mutedDisplays = {..._mutedDisplays};
        if (nowMuted) {
          _mutedDisplays.remove(display);
        } else {
          _mutedDisplays.add(display);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowMuted ? 'Could not mute $display' : 'Could not unmute $display',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowMuted ? 'Muted notifications for $display' : 'Unmuted $display',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteRepoAt(String storageKey, int index) async {
    await RepoStore.update(storageKey, (repos) {
      if (index >= 0 && index < repos.length) {
        repos.removeAt(index);
      }
    });
    await _loadRepos();
  }

  /// Atomically removes a repo AND adds its key to the ignore list under the
  /// shared lock, so an in-flight auto-add pass can't re-add it in between.
  Future<void> _removeAndIgnore(
    String storageKey,
    int index,
    String ignoreKey,
  ) async {
    await RepoStore.runLocked(() async {
      final prefs = await SharedPreferences.getInstance();
      final repos = List<String>.of(
        prefs.getStringList(storageKey) ?? const [],
      );
      if (index >= 0 && index < repos.length) {
        repos.removeAt(index);
      }
      await prefs.setStringList(storageKey, repos);
      final ignored = IgnoreStore.readFrom(prefs);
      ignored.add(ignoreKey);
      await IgnoreStore.writeTo(prefs, ignored);
    });
    await _loadRepos();
  }

  /// The canonical key for a repo, in the shared `github:owner/name` /
  /// `ado:org/project/name` form produced by [RepoDiscoveryService]. It matches
  /// the ignore-list key as well as the `RepoActivity` / `MetricStore` / team
  /// repo key, so it is reused both to ignore a repo and to prune its derived
  /// data on delete. Returns null for invalid/incomplete entries.
  String? _repoKeyFor(bool github, Map<String, String> repo) {
    if (repo.containsKey('_invalid')) return null;
    if (github) {
      final owner = repo['owner'];
      final name = repo['repoName'];
      if (owner == null || owner.isEmpty || name == null || name.isEmpty) {
        return null;
      }
      return RepoDiscoveryService.githubKey(owner, name);
    }

    final organization = repo['organization'];
    final project = repo['project'];
    final name = repo['repoName'];
    if (organization == null ||
        organization.isEmpty ||
        project == null ||
        project.isEmpty ||
        name == null ||
        name.isEmpty) {
      return null;
    }
    return RepoDiscoveryService.adoKey(organization, project, name);
  }

  Future<_DeleteChoice> _confirmDelete(
    String label, {
    required bool canIgnore,
  }) async {
    final result = await showDialog<_DeleteChoice>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove repository?'),
          content: Text(
            'Stop tracking "$label"?\n\n'
            'This only removes it from Kode Radar. Nothing is changed on the '
            'remote repository.'
            '${canIgnore ? '\n\nChoose "Remove & ignore" to also prevent it from being auto-added again.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DeleteChoice.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DeleteChoice.remove),
              child: const Text('Remove'),
            ),
            if (canIgnore)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_DeleteChoice.removeAndIgnore),
                child: const Text('Remove & ignore'),
              ),
          ],
        );
      },
    );
    return result ?? _DeleteChoice.cancel;
  }

  Future<void> _handleDelete(
    String storageKey,
    int index,
    String label, {
    required bool github,
    required Map<String, String> repo,
  }) async {
    final repoKey = _repoKeyFor(github, repo);
    final choice = await _confirmDelete(label, canIgnore: repoKey != null);
    if (choice == _DeleteChoice.cancel) return;
    if (choice == _DeleteChoice.removeAndIgnore && repoKey != null) {
      await _removeAndIgnore(storageKey, index, repoKey);
    } else {
      await _deleteRepoAt(storageKey, index);
    }
    // Prune data derived from this repo so a removed repo doesn't linger in
    // trend history or team assignments as a stale, otherwise-unbounded key.
    // Skip pruning when a duplicate entry still resolves to the same canonical
    // key, so shared data isn't removed out from under the surviving entry.
    final remaining = await listMonitoredRepos();
    if (repoKey != null) {
      final stillMonitored = remaining.any(
        (monitored) => monitored.repoKey == repoKey,
      );
      if (!stillMonitored) {
        await MetricStore.removeRepo(repoKey);
        await ActivityEventStore.removeRepo(repoKey);
        await RepoDetailStore.removeRepo(repoKey);
        await SyncStateStore.remove(SyncStateStore.repoScope(repoKey));
        await TeamStore.removeRepoFromAll(repoKey);
      }
    }
    // Mutes are keyed by display label, not repoKey, so prune independently:
    // drop the deleted label's mute only when no surviving entry still shows
    // that exact display (a same-key duplicate with different casing keeps its
    // own mute, and doesn't strand the deleted display's mute).
    if (!remaining.any((monitored) => monitored.displayName == label)) {
      await MuteStore.remove(label);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          choice == _DeleteChoice.removeAndIgnore
              ? 'Removed and ignored "$label".'
              : 'Removed "$label".',
        ),
      ),
    );
  }

  Future<void> _editGithub(int index, Map<String, String> repo) async {
    final oldDisplay = _githubLabel(repo);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterGithubRepoPage(
          editIndex: index,
          initialOwner: repo['owner'],
          initialRepoName: repo['repoName'],
          initialTokenId: repo['tokenId'],
        ),
      ),
    );
    await _loadRepos();
    if (!mounted) return;
    await _migrateMuteAfterEdit(
      oldDisplay,
      index < _githubRepos.length ? _githubLabel(_githubRepos[index]) : null,
    );
  }

  Future<void> _editAdo(int index, Map<String, String> repo) async {
    final oldDisplay = _adoLabel(repo);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterAdoRepoPage(
          editIndex: index,
          initialOrganization: repo['organization'],
          initialProject: repo['project'],
          initialRepoName: repo['repoName'],
          initialTokenId: repo['tokenId'],
        ),
      ),
    );
    await _loadRepos();
    if (!mounted) return;
    await _migrateMuteAfterEdit(
      oldDisplay,
      index < _adoRepos.length ? _adoLabel(_adoRepos[index]) : null,
    );
  }

  /// Moves any mute from a repo's old display to its new one after an edit that
  /// changed its identity, so the mute isn't silently lost / left orphaned.
  Future<void> _migrateMuteAfterEdit(
    String oldDisplay,
    String? newDisplay,
  ) async {
    if (newDisplay == null ||
        newDisplay == oldDisplay ||
        !_mutedDisplays.contains(oldDisplay)) {
      return;
    }
    await MuteStore.setMuted(oldDisplay, false);
    await MuteStore.setMuted(newDisplay, true);
    if (!mounted) return;
    setState(() {
      _mutedDisplays = {..._mutedDisplays}
        ..remove(oldDisplay)
        ..add(newDisplay);
    });
  }

  Future<void> _addRepo() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add GitHub Repository'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterGithubRepoPage(),
                    ),
                  );
                  await _loadRepos();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add ADO Repository'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterAdoRepoPage(),
                    ),
                  );
                  await _loadRepos();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _githubLabel(Map<String, String> repo) {
    if (repo.containsKey('_invalid')) return 'Invalid entry';
    return '${repo['owner'] ?? '?'}/${repo['repoName'] ?? '?'}';
  }

  String _adoLabel(Map<String, String> repo) {
    if (repo.containsKey('_invalid')) return 'Invalid entry';
    return '${repo['organization'] ?? '?'}/${repo['project'] ?? '?'}/'
        '${repo['repoName'] ?? '?'}';
  }

  Future<void> _manageIgnored() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageIgnoredPage()),
    );
    await _loadRepos();
  }

  Future<void> _importRepos() async {
    final added = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const RepoDiscoveryPage()),
    );
    await _loadRepos();
    if (!mounted) return;
    if (added != null && added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $added ${added == 1 ? 'repository' : 'repositories'}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Repositories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.block),
            tooltip: 'Ignored repositories',
            onPressed: _manageIgnored,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: 'Import from a token',
            onPressed: _importRepos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRepo,
        tooltip: 'Add repository',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_githubRepos.isEmpty && _adoRepos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('No repositories are being tracked yet.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addRepo,
              icon: const Icon(Icons.add),
              label: const Text('Add repository'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('GitHub', _githubRepos.length),
        if (_githubRepos.isEmpty)
          _buildEmptySection('No GitHub repositories added.')
        else
          ...List.generate(_githubRepos.length, (index) {
            final repo = _githubRepos[index];
            final label = _githubLabel(repo);
            final invalid = repo.containsKey('_invalid');
            return _buildRepoTile(
              icon: Icons.code,
              label: label,
              subtitle: _repoSubtitle('GitHub', repo),
              muted: _mutedDisplays.contains(label),
              onToggleMute: invalid ? null : () => _toggleMute(label),
              onEdit: invalid ? null : () => _editGithub(index, repo),
              onDelete: () => _handleDelete(
                _githubKey,
                index,
                label,
                github: true,
                repo: repo,
              ),
            );
          }),
        const Divider(height: 24),
        _buildSectionHeader('Azure DevOps', _adoRepos.length),
        if (_adoRepos.isEmpty)
          _buildEmptySection('No Azure DevOps repositories added.')
        else
          ...List.generate(_adoRepos.length, (index) {
            final repo = _adoRepos[index];
            final label = _adoLabel(repo);
            final invalid = repo.containsKey('_invalid');
            return _buildRepoTile(
              icon: Icons.account_tree,
              label: label,
              subtitle: _repoSubtitle('Azure DevOps', repo),
              muted: _mutedDisplays.contains(label),
              onToggleMute: invalid ? null : () => _toggleMute(label),
              onEdit: invalid ? null : () => _editAdo(index, repo),
              onDelete: () => _handleDelete(
                _adoKey,
                index,
                label,
                github: false,
                repo: repo,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        '$title ($count)',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(message, style: TextStyle(color: Colors.grey[600])),
    );
  }

  /// Builds the tile subtitle, noting the assigned token override (if any).
  String _repoSubtitle(String provider, Map<String, String> repo) {
    final tokenId = repo['tokenId'];
    if (tokenId == null || tokenId.isEmpty) {
      return '$provider · Auto token';
    }
    final label = _tokenLabels[tokenId];
    return label != null
        ? '$provider · Token: $label'
        : '$provider · Token: (missing — using Auto)';
  }

  Widget _buildRepoTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool muted,
    required VoidCallback? onToggleMute,
    required VoidCallback? onEdit,
    required VoidCallback onDelete,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggleMute != null)
            IconButton(
              icon: Icon(
                muted ? Icons.notifications_off : Icons.notifications_none,
              ),
              color: muted ? Colors.orange : null,
              tooltip: muted ? 'Unmute notifications' : 'Mute notifications',
              onPressed: onToggleMute,
            ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            color: Colors.red,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
