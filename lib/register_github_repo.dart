import 'package:flutter/material.dart';
import 'dart:convert';

import 'ignore_store.dart';
import 'repo_discovery_service.dart';
import 'repo_store.dart';
import 'token_store.dart';
import 'token_override_field.dart';

class RegisterGithubRepoPage extends StatefulWidget {
  const RegisterGithubRepoPage({
    super.key,
    this.editIndex,
    this.initialOwner,
    this.initialRepoName,
    this.initialTokenId,
  });

  /// Index of the repository being edited in the stored `github_repos` list.
  /// When null the page operates in "add" mode and appends a new entry.
  final int? editIndex;
  final String? initialOwner;
  final String? initialRepoName;
  final String? initialTokenId;

  @override
  State<RegisterGithubRepoPage> createState() => _RegisterGithubRepoPageState();
}

class _RegisterGithubRepoPageState extends State<RegisterGithubRepoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _repoNameController = TextEditingController();

  String? _tokenId;

  bool get _isEditing => widget.editIndex != null;

  @override
  void initState() {
    super.initState();
    _ownerController.text = widget.initialOwner ?? '';
    _repoNameController.text = widget.initialRepoName ?? '';
    _tokenId = widget.initialTokenId;
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoNameController.dispose();
    super.dispose();
  }

  Future<bool> _saveRepo(String owner, String repoName) async {
    final Map<String, String> repo = {'owner': owner, 'repoName': repoName};
    if (_tokenId != null && _tokenId!.isNotEmpty) {
      repo['tokenId'] = _tokenId!;
    }
    final encoded = jsonEncode(repo);
    final index = widget.editIndex;
    final newKey = RepoDiscoveryService.githubKey(owner, repoName);
    final added = await RepoStore.update(RepoStore.githubKey, (repos) {
      if (index != null && index >= 0 && index < repos.length) {
        repos[index] = encoded; // Replace the existing entry when editing.
        return true;
      }
      // Add mode: skip if the same repo is already tracked.
      for (final raw in repos) {
        try {
          final m = Map<String, String>.from(jsonDecode(raw) as Map);
          final key = RepoDiscoveryService.githubKey(
              m['owner'] ?? '', m['repoName'] ?? '');
          if (key == newKey) return false; // duplicate
        } catch (_) {}
      }
      repos.add(encoded);
      return true;
    });
    if (added) {
      // Explicitly (re-)adding a repo overrides any prior "ignore".
      await IgnoreStore.remove(newKey);
    }
    return added;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final owner = _ownerController.text.trim();
      final repoName = _repoNameController.text.trim();

      _saveRepo(owner, repoName).then((added) {
        if (!mounted) return; // Ensure the widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Repository updated successfully!'
                : added
                    ? 'Repository saved successfully!'
                    : 'That repository is already tracked.'),
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Edit GitHub Repository'
            : 'Register GitHub Repository'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _ownerController,
                decoration: const InputDecoration(
                  labelText: 'Repository Owner',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the repository owner';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _repoNameController,
                decoration: const InputDecoration(
                  labelText: 'Repository Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the repository name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TokenOverrideField(
                provider: TokenStore.providerGithub,
                initialTokenId: widget.initialTokenId,
                onChanged: (value) => _tokenId = value,
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: Text(_isEditing ? 'Save' : 'Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
