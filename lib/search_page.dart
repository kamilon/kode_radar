import 'package:flutter/material.dart';

import 'activity_service.dart';
import 'home_menu.dart';
import 'monitored_repos.dart';
import 'repo_detail_page.dart';
import 'team.dart';
import 'team_detail_page.dart';
import 'team_store.dart';

/// A local, instant search across monitored repositories and teams. Tapping a
/// result opens its detail screen.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<RepoActivity> _repos = const [];
  List<Team> _teams = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repos = await listMonitoredRepos();
    final teams = await TeamStore.list();
    if (!mounted) return;
    setState(() {
      _repos = repos;
      _teams = teams;
      _loading = false;
    });
  }

  List<RepoActivity> get _matchedRepos {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _repos;
    return _repos
        .where((r) => r.displayName.toLowerCase().contains(q))
        .toList();
  }

  List<Team> get _matchedTeams {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _teams;
    return _teams.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search repositories and teams',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
          const HomeMenuButton(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildResults(),
    );
  }

  Widget _buildResults() {
    final repos = _matchedRepos;
    final teams = _matchedTeams;
    if (repos.isEmpty && teams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _query.trim().isEmpty
                ? 'No monitored repositories or teams yet.'
                : 'No matches for "${_query.trim()}".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Flatten into rows so the list builds lazily even with many repos.
    final rows = <_Row>[
      if (teams.isNotEmpty) ...[
        _Row.header('Teams (${teams.length})'),
        for (final team in teams) _Row.team(team),
      ],
      if (repos.isNotEmpty) ...[
        _Row.header('Repositories (${repos.length})'),
        for (final repo in repos) _Row.repo(repo),
      ],
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.header != null) return _sectionHeader(row.header!);
        if (row.team != null) return _teamTile(row.team!);
        return _repoTile(row.repo!);
      },
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _teamTile(Team team) {
    return ListTile(
      leading: const Icon(Icons.groups),
      title: Text(team.name),
      subtitle: Text(
        '${team.repoKeys.length} repo${team.repoKeys.length == 1 ? '' : 's'}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TeamDetailPage(team: team)),
      ),
    );
  }

  Widget _repoTile(RepoActivity repo) {
    return ListTile(
      leading: Icon(
        repo.provider == 'github' ? Icons.code : Icons.account_tree,
      ),
      title: Text(repo.displayName),
      subtitle: Text(
        repo.provider == 'github' ? 'GitHub' : 'Azure DevOps',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RepoDetailPage(repo: repo)),
      ),
    );
  }
}

/// A flattened search-result row: a section header, a team, or a repo.
class _Row {
  const _Row.header(this.header) : team = null, repo = null;
  const _Row.team(this.team) : header = null, repo = null;
  const _Row.repo(this.repo) : header = null, team = null;

  final String? header;
  final Team? team;
  final RepoActivity? repo;
}
