import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ignore_store.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';

/// Lets the user pull the repositories a token can see and select which to
/// monitor. Pops with the number of repositories added.
class RepoDiscoveryPage extends StatefulWidget {
  const RepoDiscoveryPage({super.key, this.client});

  /// Injectable HTTP client (tests). Defaults to a shared client.
  final http.Client? client;

  @override
  State<RepoDiscoveryPage> createState() => _RepoDiscoveryPageState();
}

class _RepoDiscoveryPageState extends State<RepoDiscoveryPage> {
  String _provider = TokenStore.providerGithub;
  List<TokenInfo> _tokens = [];
  String? _tokenId;
  final TextEditingController _orgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _loadingTokens = true;
  bool _fetching = false;
  bool _adding = false;
  bool _truncated = false;
  bool _assignToken = true;
  String? _error;
  List<DiscoveredRepo> _repos = [];
  final Set<String> _selected = {};
  Set<String> _existingKeys = {};
  Set<String> _ignoredKeys = {};
  String _search = '';

  /// Guards against stale async results when the provider changes rapidly.
  int _loadGeneration = 0;

  bool get _isGithub => _provider == TokenStore.providerGithub;

  @override
  void initState() {
    super.initState();
    _loadTokens();
    _loadExistingKeys();
    _loadIgnored();
    _searchController.addListener(
      () => setState(() => _search = _searchController.text.trim()),
    );
  }

  @override
  void dispose() {
    _orgController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTokens() async {
    final generation = _loadGeneration;
    final tokens = await TokenStore.getTokensForProvider(_provider);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _tokens = tokens;
      _tokenId = tokens.isNotEmpty ? tokens.first.id : null;
      _loadingTokens = false;
      _prefillOrgFromToken(force: true);
    });
  }

  void _prefillOrgFromToken({bool force = false}) {
    final token = _tokens.where((t) => t.id == _tokenId).firstOrNull;
    if (token != null &&
        token.scope.isNotEmpty &&
        (force || _orgController.text.isEmpty)) {
      _orgController.text = token.scope;
    }
  }

  Future<void> _loadExistingKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String>{};
    for (final raw in prefs.getStringList('github_repos') ?? const []) {
      try {
        final map = Map<String, String>.from(jsonDecode(raw) as Map);
        keys.add(
          RepoDiscoveryService.githubKey(
            map['owner'] ?? '',
            map['repoName'] ?? '',
          ),
        );
      } catch (_) {}
    }
    for (final raw in prefs.getStringList('ado_repos') ?? const []) {
      try {
        final map = Map<String, String>.from(jsonDecode(raw) as Map);
        keys.add(
          RepoDiscoveryService.adoKey(
            map['organization'] ?? '',
            map['project'] ?? '',
            map['repoName'] ?? '',
          ),
        );
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _existingKeys = keys);
  }

  Future<void> _loadIgnored() async {
    final ignored = await IgnoreStore.get();
    if (!mounted) return;
    setState(() => _ignoredKeys = ignored);
  }

  Future<void> _ignore(DiscoveredRepo repo) async {
    await IgnoreStore.add(repo.key);
    if (!mounted) return;
    setState(() {
      _ignoredKeys.add(repo.key);
      _selected.remove(repo.key);
    });
  }

  Future<void> _unignore(DiscoveredRepo repo) async {
    await IgnoreStore.remove(repo.key);
    if (!mounted) return;
    setState(() => _ignoredKeys.remove(repo.key));
  }

  /// Clears fetched results so an import can never use a token/provider/org
  /// different from the one that produced the currently-shown list.
  void _clearResults() {
    _repos = [];
    _selected.clear();
    _truncated = false;
    _searchController.clear();
    _search = '';
  }

  Future<void> _onProviderChanged(String provider) async {
    setState(() {
      _provider = provider;
      _loadingTokens = true;
      _tokenId = null;
      _error = null;
      _orgController.clear();
      _loadGeneration++;
      _clearResults();
    });
    await _loadTokens();
  }

  Future<void> _fetch() async {
    final tokenId = _tokenId;
    if (tokenId == null) {
      setState(() => _error = 'Add a token first, then try again.');
      return;
    }
    final org = _orgController.text.trim();
    if (!_isGithub && org.isEmpty) {
      setState(() => _error = 'Enter an Azure DevOps organization.');
      return;
    }

    setState(() {
      _fetching = true;
      _error = null;
      _clearResults();
    });

    try {
      final secret = await TokenStore.getSecret(tokenId);
      if (secret == null || secret.isEmpty) {
        throw Exception('The selected token has no stored secret.');
      }
      final result = await RepoDiscoveryService.fetch(
        provider: _provider,
        secret: secret,
        org: org,
        client: widget.client,
      );
      if (!mounted) return;
      setState(() {
        _repos = result.repos..sort((a, b) => a.display.compareTo(b.display));
        _truncated = result.truncated;
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not fetch repositories: $e';
        _fetching = false;
      });
    }
  }

  Future<void> _addSelected() async {
    setState(() => _adding = true);
    final storageKey = _isGithub ? RepoStore.githubKey : RepoStore.adoKey;
    final selectedRepos = _repos
        .where((r) => _selected.contains(r.key))
        .toList();
    final tokenId = (_assignToken && _tokenId != null && _tokenId!.isNotEmpty)
        ? _tokenId
        : null;

    final added = await RepoStore.update(storageKey, (repos) {
      // Re-derive existing keys from current storage so a concurrent add
      // (e.g. an auto-add pass) can't cause duplicates.
      final existing = <String>{};
      for (final raw in repos) {
        try {
          final m = Map<String, String>.from(jsonDecode(raw) as Map);
          existing.add(
            _isGithub
                ? RepoDiscoveryService.githubKey(
                    m['owner'] ?? '',
                    m['repoName'] ?? '',
                  )
                : RepoDiscoveryService.adoKey(
                    m['organization'] ?? '',
                    m['project'] ?? '',
                    m['repoName'] ?? '',
                  ),
          );
        } catch (_) {}
      }
      var count = 0;
      for (final repo in selectedRepos) {
        if (existing.contains(repo.key)) continue;
        existing.add(repo.key);
        final map = Map<String, String>.from(repo.repo);
        if (tokenId != null) map['tokenId'] = tokenId;
        repos.add(jsonEncode(map));
        count++;
      }
      return count;
    });

    if (!mounted) return;
    Navigator.pop(context, added);
  }

  List<DiscoveredRepo> get _visibleRepos {
    if (_search.isEmpty) return _repos;
    final needle = _search.toLowerCase();
    return _repos
        .where((r) => r.display.toLowerCase().contains(needle))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Repositories')),
      body: Column(
        children: [
          _buildControls(),
          const Divider(height: 1),
          Expanded(child: _buildResults()),
          _buildAddBar(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: const InputDecoration(
              labelText: 'Provider',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: TokenStore.providerGithub,
                child: Text('GitHub'),
              ),
              DropdownMenuItem(
                value: TokenStore.providerAdo,
                child: Text('Azure DevOps'),
              ),
            ],
            onChanged: _fetching
                ? null
                : (value) =>
                      _onProviderChanged(value ?? TokenStore.providerGithub),
          ),
          const SizedBox(height: 12),
          if (_loadingTokens)
            const LinearProgressIndicator()
          else if (_tokens.isEmpty)
            const Text('No tokens for this provider. Add one first.')
          else
            DropdownButtonFormField<String>(
              initialValue: _tokenId,
              decoration: const InputDecoration(
                labelText: 'Token',
                border: OutlineInputBorder(),
              ),
              items: _tokens
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        t.isDefault
                            ? '${t.label} (default)'
                            : '${t.label} (${t.scope})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _tokenId = value;
                _clearResults();
                _error = null;
                _prefillOrgFromToken(force: true);
              }),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _orgController,
            decoration: InputDecoration(
              labelText: _isGithub
                  ? 'GitHub organization (optional)'
                  : 'Azure DevOps organization (required)',
              hintText: _isGithub
                  ? 'Blank = all repositories you can access'
                  : 'e.g., mycompany',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_fetching || _loadingTokens) ? null : _fetch,
              icon: _fetching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_fetching ? 'Fetching…' : 'Fetch repositories'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_truncated) ...[
            const SizedBox(height: 12),
            Text(
              'Some repositories were omitted (the account has too many to '
              'list, or its pagination could not be followed). Narrow the '
              'results by organization to see the rest.',
              style: TextStyle(color: Colors.orange[800], fontSize: 12),
            ),
          ],
          if (_repos.isNotEmpty) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _assignToken,
              onChanged: (value) =>
                  setState(() => _assignToken = value ?? true),
              title: const Text('Assign this token to imported repositories'),
              subtitle: const Text(
                'Off = use automatic org/owner matching instead.',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Filter',
                prefixIcon: Icon(Icons.filter_list),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_repos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Fetch repositories to choose which ones to monitor.'),
        ),
      );
    }
    final visible = _visibleRepos;
    if (visible.isEmpty) {
      return const Center(child: Text('No repositories match your filter.'));
    }
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final repo = visible[index];
        final ignored = _ignoredKeys.contains(repo.key);
        final alreadyAdded = _existingKeys.contains(repo.key);
        final disabled = ignored || alreadyAdded;
        final checked =
            !ignored && (alreadyAdded || _selected.contains(repo.key));

        final String? subtitle = ignored
            ? 'Ignored'
            : (alreadyAdded ? 'Already monitored' : null);

        // Trailing action: un-ignore an ignored repo, or ignore a selectable one.
        Widget? trailing;
        if (ignored) {
          trailing = IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Un-ignore',
            onPressed: () => _unignore(repo),
          );
        } else if (!alreadyAdded) {
          trailing = IconButton(
            icon: const Icon(Icons.block),
            tooltip: 'Ignore',
            onPressed: () => _ignore(repo),
          );
        }

        return CheckboxListTile(
          value: checked,
          title: Text(repo.display),
          subtitle: subtitle != null ? Text(subtitle) : null,
          secondary: trailing,
          onChanged: disabled
              ? null
              : (value) => setState(() {
                  if (value == true) {
                    _selected.add(repo.key);
                  } else {
                    _selected.remove(repo.key);
                  }
                }),
        );
      },
    );
  }

  Widget _buildAddBar() {
    final count = _selected.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (count == 0 || _adding) ? null : _addSelected,
            child: _adding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(count == 0 ? 'Add selected' : 'Add selected ($count)'),
          ),
        ),
      ),
    );
  }
}
