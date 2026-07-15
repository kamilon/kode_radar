import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'team.dart';
import 'team_store.dart';

class ManageTeamsPage extends StatefulWidget {
  const ManageTeamsPage({super.key});

  @override
  State<ManageTeamsPage> createState() => _ManageTeamsPageState();
}

class _ManageTeamsPageState extends State<ManageTeamsPage> {
  List<Team> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final teams = await TeamStore.list();
    if (!mounted) return;
    setState(() {
      _teams = teams;
      _isLoading = false;
    });
  }

  Future<void> _createTeam() async {
    final name = await _showNameDialog(title: 'Create team');
    if (name == null) return;

    final team = await TeamStore.add(name);
    await _loadTeams();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Created "${team.name}".')));
  }

  Future<void> _renameTeam(Team team) async {
    final name = await _showNameDialog(
      title: 'Rename team',
      initialValue: team.name,
    );
    if (name == null) return;

    await TeamStore.rename(team.id, name);
    await _loadTeams();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Renamed to "$name".')));
  }

  Future<void> _deleteTeam(Team team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete team?'),
          content: Text(
            'Delete "${team.name}"?\n\n'
            'This only removes the team grouping. Repositories remain tracked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await TeamStore.delete(team.id);
    await _loadTeams();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted "${team.name}".')));
  }

  Future<void> _assignRepos(Team team) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _AssignReposPage(team: team)),
    );
    await _loadTeams();
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Updated "${team.name}".')));
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Team name'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _popName(dialogContext, controller),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => _popName(dialogContext, controller),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      return result;
    } finally {
      controller.dispose();
    }
  }

  void _popName(BuildContext dialogContext, TextEditingController controller) {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(dialogContext).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Teams')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTeam,
        tooltip: 'Create team',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('No teams created yet.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createTeam,
              icon: const Icon(Icons.add),
              label: const Text('Create team'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _teams.map(_buildTeamTile).toList(),
    );
  }

  Widget _buildTeamTile(Team team) {
    return ListTile(
      leading: const Icon(Icons.groups_outlined),
      title: Text(team.name),
      subtitle: Text(_repoCountLabel(team.repoKeys.length)),
      onTap: () => _assignRepos(team),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            tooltip: 'Assign repositories',
            onPressed: () => _assignRepos(team),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: () => _renameTeam(team),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            color: Colors.red,
            onPressed: () => _deleteTeam(team),
          ),
        ],
      ),
    );
  }

  String _repoCountLabel(int count) =>
      '$count ${count == 1 ? 'repository' : 'repositories'}';
}

class _AssignReposPage extends StatefulWidget {
  const _AssignReposPage({required this.team});

  final Team team;

  @override
  State<_AssignReposPage> createState() => _AssignReposPageState();
}

class _AssignReposPageState extends State<_AssignReposPage> {
  List<_RepoOption> _repos = [];
  late Set<String> _selected;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.team.repoKeys.toSet();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    final repos = await _loadRepoOptions();
    if (!mounted) return;
    setState(() {
      _repos = repos;
      _selected = _selected.intersection(repos.map((repo) => repo.key).toSet());
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await TeamStore.setRepos(widget.team.id, _selected);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _toggle(String key, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Repositories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_repos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('No repositories are being tracked yet.'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _repos.map(_buildRepoTile).toList(),
    );
  }

  Widget _buildRepoTile(_RepoOption repo) {
    return CheckboxListTile(
      secondary: Icon(
        repo.provider == _RepoProvider.github ? Icons.code : Icons.account_tree,
      ),
      title: Text(repo.label),
      subtitle: Text(repo.providerLabel),
      value: _selected.contains(repo.key),
      onChanged: (checked) => _toggle(repo.key, checked ?? false),
    );
  }
}

enum _RepoProvider { github, ado }

class _RepoOption {
  const _RepoOption({
    required this.key,
    required this.label,
    required this.provider,
  });

  final String key;
  final String label;
  final _RepoProvider provider;

  String get providerLabel =>
      provider == _RepoProvider.github ? 'GitHub' : 'Azure DevOps';
}

Future<List<_RepoOption>> _loadRepoOptions() async {
  final prefs = await SharedPreferences.getInstance();
  final repos = <String, _RepoOption>{};

  for (final entry in prefs.getStringList(RepoStore.githubKey) ?? const []) {
    final repo = _parseRepoEntry(entry);
    final owner = _stringValue(repo?['owner']);
    final name = _stringValue(repo?['repoName']);
    if (owner == null || name == null) {
      debugPrint('Skipping malformed GitHub repo entry.');
      continue;
    }
    final key = RepoDiscoveryService.githubKey(owner, name);
    repos[key] = _RepoOption(
      key: key,
      label: '$owner/$name',
      provider: _RepoProvider.github,
    );
  }

  for (final entry in prefs.getStringList(RepoStore.adoKey) ?? const []) {
    final repo = _parseRepoEntry(entry);
    final organization = _stringValue(repo?['organization']);
    final project = _stringValue(repo?['project']);
    final name = _stringValue(repo?['repoName']);
    if (organization == null || project == null || name == null) {
      debugPrint('Skipping malformed Azure DevOps repo entry.');
      continue;
    }
    final key = RepoDiscoveryService.adoKey(organization, project, name);
    repos[key] = _RepoOption(
      key: key,
      label: '$organization/$project/$name',
      provider: _RepoProvider.ado,
    );
  }

  final sorted = repos.values.toList()
    ..sort((a, b) {
      final provider = a.provider.index.compareTo(b.provider.index);
      if (provider != 0) return provider;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  return sorted;
}

Map? _parseRepoEntry(String entry) {
  try {
    final decoded = jsonDecode(entry);
    return decoded is Map ? decoded : null;
  } catch (error) {
    debugPrint('Failed to parse repo entry: $error');
    return null;
  }
}

String? _stringValue(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
